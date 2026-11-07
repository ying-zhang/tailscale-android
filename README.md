# Tailscale Android 中文定制版

[English / 上游英文说明](README.en.md)

基于 [Tailscale 官方 Android 客户端源码](https://github.com/tailscale/tailscale-android) 的个人定制分支，增加开机自动连接和主要界面的简体中文翻译。使用独立签名，不是 Tailscale 官方发行的 APK。

## 功能

- **开机自动连接**：设置中的「开机自动连接」默认开启；手机重启并首次解锁后，自动启动 VPN 服务，无需点击连接。开启时，即使重启前手动断开，重启后也会连接。
- **主要操作汉化**：连接、断开、登录、设置、设备列表等常用操作及部分通知使用简体中文，其余内容回退英文。手机系统语言设为简体中文（中国大陆）时启用。
- **ARM64 构建**：当前默认仅打包 `arm64-v8a`，适用于 ARM64 Android 手机。
- **保留官方版本格式**：Android 版本名及后端版本由上游 `mkversion` 生成，避免自定义版本后缀影响管理后台的版本识别。

首次使用须打开应用，完成账号登录、设备审批和 Android VPN 授权。自签名版本可以登录 Tailscale 账号。

开机连接需要首次解锁后才能读取加密凭据。系统强行停止应用、厂商限制后台运行、VPN 权限被撤销或账号过期，都可能阻止连接。请在系统设置中允许自启动和后台运行。Android 的「始终开启 VPN」是独立的系统设置，不受本应用开机连接开关控制。

## 安装与升级

本分支构建产物为仓库根目录的 `tailscale-release.apk`，最低 Android 8.0（API 26）。

云端构建的 ARM64 APK 可在本仓库的 [Releases 页面](https://github.com/ying-zhang/tailscale-android/releases)下载。发布说明包含安装要求、源码提交和验证结果，附件包含 APK 及 `SHA256SUMS` 校验文件。当前基于上游开发分支，发布标记为 Pre-release。

```powershell
adb install -r ./tailscale-release.apk
```

包名仍为 `com.tailscale.ipn`。由于签名不同，从官方版切换到本分支时需先卸载官方版，卸载会清除本地登录状态。此后用同一私钥签名且版本码不降低的 APK 覆盖升级，可保留应用数据和登录状态；请妥善备份签名文件。

需要官方发行版时，请访问 [Tailscale 官方下载页](https://tailscale.com/download/android) 或 [官方 APK 软件包](https://pkgs.tailscale.com/stable/#android)。这些下载提供的是官方客户端。

## Windows 构建

已验证的工具组合：Go 1.27.3、JDK 21、Android SDK 37、Build Tools 37.0.0、NDK 30.0.16248370、Gradle 9.8.2（仓库 Wrapper）。SDK 组件需事先安装。

在 PowerShell 7 中运行：

```powershell
./scripts/build-release.ps1 `
  -SdkRoot 'C:\App\android-sdk' `
  -JavaRoot 'C:\App\jdk21\jdk-21.0.12.1+1' `
  -GoRoot 'C:\path\to\go'
```

默认 Go 路径为 `.tmp/toolchain/go`。脚本读取 Windows 系统中简单的 `主机:端口` 代理配置，限制编译并发以降低内存占用，并执行格式检查、单元测试、release 必需 lint 检查、构建和签名验证。仅修改 Kotlin / XML 时，可加 `-SkipNative` 复用已生成的 Go AAR。

构建前需自行生成签名密钥，并创建 `.signing/release.properties`。可使用 JDK 的 `keytool` 交互式设置密码：

```powershell
New-Item -ItemType Directory -Force .signing
keytool -genkeypair -keystore .signing/tailscale-release.p12 `
  -storetype PKCS12 -alias tailscale-local -keyalg RSA -keysize 4096 -validity 10000
```

配置文件示例（路径相对于 `android` 目录；将密码替换为自己的密码）：

```properties
storeFile=../.signing/tailscale-release.p12
storePassword=YOUR_PASSWORD
keyAlias=tailscale-local
keyPassword=YOUR_PASSWORD
```

`.signing` 已被 Git 忽略，私钥和密码不随仓库发布。详细说明见 [中文构建说明](BUILD-ZH.md)，验证结果及已知限制见 [修改审查记录](CODE-REVIEW-ZH.md)。其他平台的上游构建方式见 [英文说明](README.en.md)。

当前基于上游开发分支，后端依赖为 `1.105.0-pre`，并非稳定发行标签。原生部分使用标准 Go 工具链及上游支持的 `not_tailscale_go` 构建标签；官方构建使用其指定的 Tailscale Go 工具链，因此不保证二进制与官方 APK 逐字节一致。完整 `lintRelease` 仍有上游兼容性及部分翻译相关问题，具体见审查记录。

## GitHub Actions 构建和发布

进入 **Actions → ARM64 Release APK → Run workflow**，选择 `main` 分支。流程仅构建 ARM64，使用仓库 Secrets 中的密钥签名，完成检查后自动发布到 Releases，并附上中文说明。不会因 PR 或普通推送自动发布。

初次配置所需 Secrets、备份方法和命令见 [Actions 发布说明](ACTIONS-ZH.md)。本机已有密钥的用户应备份整个 `.signing` 目录，其中 `.p12` 为签名私钥，`release.properties` 保存密码及别名。保持同一签名才能继续覆盖升级已有安装。

## 反馈与许可证

本分支新增功能的问题请提交到本仓库的 Issues；官方客户端或服务的问题请使用 [Tailscale 官方问题跟踪器](https://github.com/tailscale/tailscale/issues)。贡献请在提交中添加 DCO `Signed-off-by`。

本项目遵循 [BSD-3-Clause 许可证](LICENSE)。Tailscale 为原项目开发者；WireGuard 是 Jason A. Donenfeld 的注册商标。
