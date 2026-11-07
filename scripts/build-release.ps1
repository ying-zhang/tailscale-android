param(
  [string]$SdkRoot = 'C:\App\android-sdk',
  [string]$JavaRoot = 'C:\App\jdk21\jdk-21.0.12.1+1',
  [string]$GoRoot = "$PSScriptRoot\..\.tmp\toolchain\go",
  [switch]$SkipNative
)
$ErrorActionPreference = 'Stop'
Set-Location "$PSScriptRoot\.."
$env:JAVA_HOME = $JavaRoot
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_NDK_HOME = "$SdkRoot\ndk\30.0.16248370"
$env:PATH = "$GoRoot\bin;$JavaRoot\bin;$PWD\android\build\go\bin;$env:PATH"
$env:GOTOOLCHAIN = 'local'
$env:GOMAXPROCS = '2'
$env:GOMEMLIMIT = '768MiB'
$env:GOFLAGS = '-p=1'
$env:GODEBUG = 'http2client=0'
$env:GOBIN = "$PWD\android\build\go\bin"
$proxySettings = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$gradleNetwork = @('-Djava.net.preferIPv4Stack=true')
if ($proxySettings.ProxyEnable -eq 1 -and $proxySettings.ProxyServer -match '^([^:;=]+):(\d+)$') {
  $env:HTTPS_PROXY = "http://$($proxySettings.ProxyServer)"
  $env:HTTP_PROXY = $env:HTTPS_PROXY
  $gradleNetwork += "-Dhttps.proxyHost=$($Matches[1])", "-Dhttps.proxyPort=$($Matches[2])", "-Dhttp.proxyHost=$($Matches[1])", "-Dhttp.proxyPort=$($Matches[2])"
}
function Check-Exit {
  if ($LASTEXITCODE -ne 0) { throw "Build command failed with exit code $LASTEXITCODE" }
}
if (!(Test-Path '.signing/release.properties')) { throw 'Missing .signing/release.properties' }
if (!$SkipNative) {
  & go.exe run tailscale.com/cmd/mkversion | Set-Content -Encoding utf8 tailscale.version
  Check-Exit
  & go.exe install golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind
  Check-Exit
  $version = @{}
  Get-Content tailscale.version | ForEach-Object {
    if ($_ -match '^(\w+)=(.*)$') { $version[$Matches[1]] = $Matches[2].Trim('"') }
  }
  # Control-plane feature checks parse these stamps. Keep mkversion's official format.
  $linkFlags = "-s -w -linkmode=external -extldflags=-Wl,-z,max-page-size=16384 -X tailscale.com/version.longStamp=$($version.VERSION_LONG) -X tailscale.com/version.shortStamp=$($version.VERSION_SHORT) -X tailscale.com/version.gitCommitStamp=$($version.VERSION_GIT_HASH) -X tailscale.com/version.extraGitCommitStamp=$($version.VERSION_EXTRA_HASH)"
  & go.exe run -ldflags "-X tailscale.com/version.longStamp=$($version.VERSION_LONG) -X tailscale.com/version.shortStamp=$($version.VERSION_SHORT)" ./scripts/check-version.go $version.VERSION_SHORT $version.VERSION_LONG
  Check-Exit
  New-Item -ItemType Directory -Force android/libs | Out-Null
  & gomobile.exe bind -target android/arm64 -androidapi 26 -tags 'not_tailscale_go,ts_omit_cachenetmap' -ldflags $linkFlags -o android/libs/libtailscale.aar ./libtailscale
  Check-Exit
}
Push-Location android
try {
  & .\gradlew.bat ktfmtCheck test lintVitalRelease assembleRelease --max-workers=1 --no-daemon --console=plain '-Dorg.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m -XX:ActiveProcessorCount=2' '-Pkotlin.compiler.execution.strategy=in-process' @gradleNetwork
  Check-Exit
} finally { Pop-Location }
Copy-Item android/build/outputs/apk/release/android-release.apk tailscale-release.apk
& "$SdkRoot\build-tools\37.0.0\apksigner.bat" verify --verbose --print-certs tailscale-release.apk
Check-Exit
