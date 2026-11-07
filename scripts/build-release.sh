#!/usr/bin/env bash
# Copyright (c) Tailscale Inc & AUTHORS
# SPDX-License-Identifier: BSD-3-Clause

# Signed ARM64 release build for Linux, including GitHub-hosted runners.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ANDROID_HOME:?Set ANDROID_HOME to an installed Android SDK}"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/30.0.16248370"
export GOBIN="$PWD/android/build/go/bin"
export PATH="$GOBIN:$PATH"
export GOTOOLCHAIN=local
export GOMAXPROCS=2
export GOMEMLIMIT=2GiB
export GOFLAGS=-p=2

test -f .signing/release.properties
test -f .signing/tailscale-release.p12
mkdir -p android/libs dist .tmp
go run tailscale.com/cmd/mkversion > tailscale.version
source tailscale.version
base_version_short="$VERSION_SHORT"
VERSION_PATCH=$((VERSION_PATCH + 1))
VERSION_SHORT="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}"
VERSION_LONG="${VERSION_SHORT}${VERSION_LONG#"$base_version_short"}"
VERSION_XCODE="${VERSION_XCODE%.*}.${VERSION_PATCH}"
VERSION_WINRES="${VERSION_MAJOR},${VERSION_MINOR},${VERSION_PATCH},0"
sed -i \
  -e "s/^VERSION_PATCH=.*/VERSION_PATCH=$VERSION_PATCH/" \
  -e "s/^VERSION_SHORT=.*/VERSION_SHORT=\"$VERSION_SHORT\"/" \
  -e "s/^VERSION_LONG=.*/VERSION_LONG=\"$VERSION_LONG\"/" \
  -e "s/^VERSION_XCODE=.*/VERSION_XCODE=\"$VERSION_XCODE\"/" \
  -e "s/^VERSION_WINRES=.*/VERSION_WINRES=\"$VERSION_WINRES\"/" \
  tailscale.version
go install golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind

go run -ldflags "-X tailscale.com/version.longStamp=$VERSION_LONG -X tailscale.com/version.shortStamp=$VERSION_SHORT" \
  ./scripts/check-version.go "$VERSION_SHORT" "$VERSION_LONG"
link_flags="-s -w -linkmode=external -extldflags=-Wl,-z,max-page-size=16384 $(bash ./version-ldflags.sh | tr '\n' ' ')"
gomobile bind -target android/arm64 -androidapi 26 \
  -tags not_tailscale_go,ts_omit_cachenetmap -ldflags "$link_flags" \
  -o android/libs/libtailscale.aar ./libtailscale

(
  cd android
  bash ./gradlew ktfmtCheck test lintVitalRelease assembleRelease \
    --max-workers=2 --no-daemon --console=plain \
    '-Dorg.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m -XX:ActiveProcessorCount=2' \
    '-Pkotlin.compiler.execution.strategy=in-process'
)

apk="dist/tailscale-${VERSION_LONG}-arm64-v8a.apk"
cp android/build/outputs/apk/release/android-release.apk "$apk"
tools="$ANDROID_HOME/build-tools/37.0.0"
"$tools/apksigner" verify --verbose --print-certs "$apk"
"$tools/zipalign" -c -P 16 4 "$apk"
"$tools/aapt2" dump badging "$apk" > .tmp/release-badging.txt

python3 - "$apk" "$VERSION_SHORT" "$VERSION_LONG" <<'PY'
import json
from pathlib import Path
import re
import struct
import sys
import zipfile

apk, short, long = sys.argv[1:]
with zipfile.ZipFile(apk) as archive:
    native = [name for name in archive.namelist() if name.startswith('lib/') and name.endswith('.so')]
    if not native or {name.split('/')[1] for name in native} != {'arm64-v8a'}:
        raise SystemExit(f'Unexpected APK native architectures: {native}')
    for name in native:
        elf = archive.read(name)
        if elf[:6] != b'\x7fELF\x02\x01':
            raise SystemExit(f'Not a little-endian ELF64 library: {name}')
        offset = struct.unpack_from('<Q', elf, 32)[0]
        entry_size, count = struct.unpack_from('<HH', elf, 54)
        for index in range(count):
            header = offset + index * entry_size
            if struct.unpack_from('<I', elf, header)[0] == 1:
                alignment = struct.unpack_from('<Q', elf, header + 48)[0]
                if alignment < 16384:
                    raise SystemExit(f'ELF segment alignment below 16 KB: {name}')

badging = Path('.tmp/release-badging.txt').read_text()
package = re.search(r"package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']+)'", badging)
if not package or package[1] != 'com.tailscale.ipn' or package[3] != long:
    raise SystemExit('Unexpected APK package name or version stamp')
Path('.tmp/release-info.json').write_text(json.dumps({
    'apk': apk, 'version_short': short, 'version_long': long,
    'version_code': int(package[2]), 'architectures': ['arm64-v8a'],
}, indent=2) + '\n')
print(f'ARM64 APK, official version stamps and 16 KB alignment verified: {apk}')
PY

(
  cd dist
  sha256sum ./*.apk > SHA256SUMS
)
