# 中文定制版构建说明

本分支基于 https://github.com/tailscale/tailscale-android 官方 Android 客户端源码仓库。
本次基于提交 `24fbeb48d`，依赖的 Tailscale 后端为 `1.105.0-pre`，属于开发版本，并非稳定版发布标签。
自签名构建可以登录 Tailscale 账号，但签名与官方版不同，不能直接覆盖官方版。

## 修改

- 新增开机广播接收器，开机并首次解锁后自动连接；应用更新后也尝试连接。
- 设置中新增默认开启的「开机自动连接」。开启后，即使重启前手动断开，重启后也会连接。
- 必须先打开应用完成登录、设备审批和 VPN 授权。关闭开机连接开关可禁用此行为。
- 使用系统「始终开启 VPN」时，启动行为仍由系统控制，不受此开关限制。
- 未实现首次解锁前启动；后端凭据使用加密存储，需要解锁才能访问。
- 系统强行停止应用、厂商限制自启动或后台运行、账号过期时，无法保证自动连接。
  可在手机系统设置中允许自启动和后台运行，或使用系统「始终开启 VPN」。
- 新增简体中文资源，系统语言为中国大陆简体中文时自动使用。主要操作、设置和通知已翻译；其余回退英文。

## Windows 工具

Go 1.27.3、JDK 21、SDK 37、Build Tools 37.0.0、NDK 30.0.16248370、Gradle 9.8.2。
SDK、JDK、Gradle 复用 C:\App；Go 1.27.3 解压至 `.tmp/toolchain/go`。
NDK 30 和 Build Tools 37 按本机已有最新版本选用。
Go 后端使用标准 Go 工具链及 `not_tailscale_go` 标签，这是上游为标准工具链提供的构建路径；
官方构建默认使用其 `go.toolchain.rev` 指定的 Tailscale Go 工具链，本构建不声称与官方二进制逐字节一致。

在 PowerShell 7 中运行（外部启动 pwsh 时使用 `-WindowStyle Hidden`）：

```powershell
./scripts/build-release.ps1
# 仅修改 Kotlin / XML 时复用已经生成的 Go AAR：
./scripts/build-release.ps1 -SkipNative
```

脚本从 Windows 系统代理设置读取简单的主机和端口代理，限制编译并发，
仅构建 ARM64（arm64-v8a），执行格式检查、单元测试、release 必需 lint 检查、release 打包和签名校验。
输出 `tailscale-release.apk`。
版本恢复官方 `mkversion` 机制：APK 版本名和后端完整版本使用 `VERSION_LONG`，
后端短版本使用 `VERSION_SHORT`。当前分别为 `1.105.210-t46f938791-g24fbeb48d` 和 `1.105.210`。
不再使用数字后直接追加 `z` 的格式，因为该格式无法通过 Tailscale 的版本比较器，可能导致管理后台拒绝需要最低版本的操作。
脚本在原生构建前执行 `scripts/check-version.go`，验证版本可解析以及控制服务器 Hostinfo 上报的版本。

完整 `lintRelease` 另有上游已有的 API 兼容性、代码风格和依赖升级等问题，以及本次按需部分翻译导致的缺少翻译提示；
本构建执行 Android release 打包要求的 `lintVitalRelease`，没有整体关闭 lint 或加入忽略全部问题的基线。
同时修正上游清单中 MDM 广播接收器包路径错误。

## 签名

密钥：`.signing/tailscale-release.p12`，RSA 4096 位，PKCS12。
别名：`tailscale-local`。随机密码保存在 `.signing/release.properties`，Gradle 自动读取。
这两个文件均被 Git 忽略。请将整个 `.signing` 目录备份到安全位置，后续升级须使用同一密钥。
不要将密码文件、密钥或 `.signing` 目录提交或公开。

当前包名仍是 `com.tailscale.ipn`。安装自签名 APK 前需卸载签名不同的官方版，
卸载会清除应用本地状态，需要重新登录并批准 VPN 权限。
