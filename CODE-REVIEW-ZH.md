# 本次修改审查记录

审查范围：新增开机连接、设置开关、中文资源、版本与 ARM64 构建限制、签名配置，以及相关 VPN 服务启动链路。不是整个 Kotlin / Go 项目及全部依赖的安全审计。

## 结果

本次修改未发现阻止交付的问题。构建检查发现并修正了上游清单中 MDM 接收器的错误包路径：实际类位于 `com.tailscale.ipn.mdm`。

- 开机接收器 `exported=false`，只处理系统开机和本应用更新动作。
- 自动连接先检查用户开关、已有登录/设备授权状态和系统 VPN 授权；不在后台弹出授权界面。
- 复用现有 `startVPN()` → 前台 `IPNService` → `setWantRunning(true)` 路径；没有新增后台轮询或常驻任务。
- 开关默认开启，并持久保存；手动断开后，下次重启仍会连接。系统「始终开启 VPN」独立于此开关。
- 未改动登录、控制服务器、加密或流量路由实现。
- 中文资源的键名、格式化参数与基础资源对应；缺少翻译时回退英文。
- 私钥及密码位于被 Git 忽略的 `.signing` 目录，未写入源码或 APK。
- Gradle 和 Go 后端恢复官方 `mkversion` 版本格式，最终 APK 仅包含 ARM64 原生库。

## 验证与限制

- `ktfmtCheck`、92 项单元测试（含 6 项新增启动条件测试）、`lintVitalRelease`、`assembleRelease` 通过。
- APK 签名验证、16 KB ZIP 页对齐检查通过。
- 完整 `lintRelease` 未通过：除了按要求部分汉化带来的 MissingTranslation，还有上游 API 兼容性、依赖版本和其他提示；未使用整体忽略基线。
- 其中 `NetworkChangeCallback.kt` 中构造 `NetworkCapabilities` / `LinkProperties` 的调用被 lint 标记为需要 API 30 / 29，而项目 minSdk 为 26。此项尚未在 Android 8–10 真机上验证，应视为现有的低版本兼容性风险。
- `systemExempted` 前台服务的权限提示需结合 VPN 身份判断。Android 官方文档明确允许已配置的 VPN 使用此类型，因此未为消除此提示而添加无关的闹钟权限。
- 当前源代码属于开发分支；采用本机 NDK 30 与标准 Go 构建路径，不承诺与官方发布二进制完全一致。
- 已在 Pixel 3 / Android 12 真机完成账号登录、同签名覆盖升级和重启自动连接验证；权限撤销、关闭开关后的重启以及其他厂商后台限制尚未进行真机测试。单元测试覆盖启动决策，不能证明各厂商系统都会投递开机广播。

Android 官方依据：

- [后台启动前台服务的例外条件](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [systemExempted 前台服务类型及 VPN 条件](https://developer.android.com/develop/background-work/services/fgs/service-types#system-exempted)

在其他设备安装后，仍建议分别验证开启开关后重启自动连接、关闭开关后重启不连接；同时检查手机系统是否允许本应用自启动。

## 真机重启验证（2026-11-07）

在 Pixel 3 / Android 12 上进行了两次实际重启。系统「始终开启 VPN」未启用，开机连接由新增接收器触发。

第二次测试期间没有启动应用界面。系统日志显示 17:10:57.892 因 `BootReceiver` 创建应用进程，
17:10:58.049 允许启动 `IPNService` 前台服务，17:11:08.784 后端进入 `Running`。
从接收器进程启动到连接就绪约 11 秒；本次从发出重启命令到连接就绪约 88 秒，包含系统启动及广播排队时间。

VPN 网卡恢复原节点 IP，电脑到手机 ICMP 测试 3/3 成功，手机到电脑 2/2 成功，Tailscale TSMP 探测也成功。
登录状态保留，无需点击连接按钮。第一次测试中，后台同样在界面被打开前已进入 `Running`；
为排除手动打开界面的影响，再进行了上述第二次测试。

## 管理后台版本识别修复

初版构建将后端长、短版本都设为 `1.105.210z`，先前审查未覆盖协议版本的解析兼容性。
`tailscale.com/version.AtLeast` 拒绝该格式，即使与相同版本比较也返回 false；
`hostinfo.New()` 又将 `version.Long()` 作为 `IPNVersion` 上报。这与管理后台提示「Device is too old」吻合，
但后台具体实现不在此仓库中，最终需在覆盖安装、重新上报版本后验证网页操作。
现恢复官方长短版本和提交哈希格式，并在构建时调用真实版本解析器和 Hostinfo 代码检查，防止再次产生不可解析的协议版本。

修复验证：新版通过 92 项单元测试、release 必要检查和签名校验，已使用相同密钥通过 ADB 覆盖安装。
设备保留原节点身份，并收到 `machineAuthorized=true; authURL=false` 的注册响应，无需重新登录。
用户在管理网页重新操作后确认，已经可以修改设备 IP。
