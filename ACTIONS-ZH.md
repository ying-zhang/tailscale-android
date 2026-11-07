# GitHub Actions ARM64 发布说明

工作流：[ARM64 Release APK](.github/workflows/release-arm64.yml)。仅在手动触发且分支为 `main` 时执行，构建成功后发布 GitHub Pre-release。

## 使用

1. 在仓库 **Settings → Secrets and variables → Actions** 配置下文两个 Secrets。
2. 进入 **Actions → ARM64 Release APK → Run workflow**，选择 `main` 分支。
3. 等待构建成功，前往仓库 **Releases** 下载 `.apk` 和 `SHA256SUMS`。Actions 本次运行也保留构建附件 14 天，Release 附件不受此期限限制。

也可以用 GitHub CLI：

```powershell
gh workflow run release-arm64.yml --repo ying-zhang/tailscale-android --ref main
gh run list --repo ying-zhang/tailscale-android --workflow release-arm64.yml
```

## 签名配置

使用与手机现有安装相同的签名文件，不要为了配置 CI 重新生成密钥。首次从零使用本分支时，可按 README 自行生成密钥。

| Repository Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `.signing/tailscale-release.p12` 文件的 Base64 编码 |
| `ANDROID_SIGNING_PROPERTIES` | `.signing/release.properties` 的完整文本 |

`release.properties` 中的密钥路径需为 `storeFile=../.signing/tailscale-release.p12`，其他字段为 `storePassword`、`keyAlias`、`keyPassword`。密码须符合 Java Properties 文件的转义规则。

已安装并登录 `gh` 后，可在仓库根目录用 PowerShell 7 配置，无需将密钥内容打印出来：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PWD '.signing/tailscale-release.p12'))) |
  gh secret set ANDROID_KEYSTORE_BASE64 --repo ying-zhang/tailscale-android
Get-Content -Raw -LiteralPath .signing/release.properties |
  gh secret set ANDROID_SIGNING_PROPERTIES --repo ying-zhang/tailscale-android
```

Secrets 由 GitHub 加密保存，仅构建时恢复到临时 runner 的 `.signing` 目录，结束后清除。该目录不会作为源码、构建附件或 Release 附件上传。工作流需要 `contents: write` 以创建 Release；无需另设 GitHub 访问令牌。

## 本机需要备份什么

请将整个 `.signing` 目录离线备份到安全位置：

- **`tailscale-release.p12`**：包含应用签名私钥；丢失后无法用原签名发布升级包。
- **`release.properties`**：保存密钥库密码、私钥密码、别名和路径；只有密钥文件却没有正确密码也无法签名。

APK、Go/Gradle 缓存和 SDK 都可以重新构建或下载，不能替代签名私钥。GitHub Secrets 不提供原文回读功能，因此不能替代自己的备份。不要将这两个文件公开提交到 GitHub 或放进 Release。

## 构建和验证

Linux 脚本为 `scripts/build-release.sh`，固定使用 Go 模块要求的 Go 版本、JDK 21、SDK 37、Build Tools 37.0.0 和 NDK 30.0.16248370。Go 使用标准工具链及上游支持的 `not_tailscale_go` 标签。原生构建目标为 `android/arm64`，Gradle 也限制 `arm64-v8a`。

发布前执行：版本解析及 Hostinfo 上报检查、`ktfmtCheck`、单元测试、`lintVitalRelease`、release 构建、APK 签名验证、仅 ARM64 校验、ZIP / ELF 16 KB 页对齐检查。完整 lint 的现有问题见 [修改审查记录](CODE-REVIEW-ZH.md)；云端不执行真机登录或重启测试。

APK 内部版本继续使用上游 `mkversion` 格式。Release 标签额外包含 Actions 运行编号及重试编号，避免与官方版本标签混淆；该标签不作为协议版本上报。Android 版本码沿用上游按构建时间递增的机制。

当前依赖是上游开发版本，因此标记为 Pre-release。使用同一密钥且版本码不降低的 APK 可覆盖升级本分支现有安装并保留登录；官方版签名不同，不能直接覆盖安装。
