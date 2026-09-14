# passkey

macOS 命令行工具，将密码存入系统钥匙串，读取时强制 Touch ID 验证。

## 功能

- **store** — 将密码写入钥匙串（按 service / account 索引）
- **fetch** — 弹出 Touch ID 验证，通过后输出密码到 stdout
- **delete** — 从钥匙串删除指定条目

密码以 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 标记存储，绑定本机、不随 iCloud 备份迁移。

## 系统要求

- macOS 10.15+
- Swift 6.3+
- 支持 Touch ID 或设备密码的 Mac

## 安装

```sh
# 构建、签名（ad-hoc）并安装到 ~/bin/passkey
make install

# 安装到自定义目录
make install PREFIX=/usr/local/bin

# 使用 Developer ID 签名（可进一步公证）
make install IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

## 用法

```sh
# 存储密码
passkey store <service> <account> <password>

# 读取密码（触发 Touch ID）
passkey fetch <service> <account>

# 删除密码
passkey delete <service> <account>
```

### 示例

```sh
# 存储 GitHub token
passkey store github.com kayce ghp_xxxxxxxxxxxx

# 在脚本中读取（密码输出到 stdout，可直接捕获）
TOKEN=$(passkey fetch github.com kayce)

# 删除
passkey delete github.com kayce
```

## 安全说明

Touch ID 验证通过 `LAContext.evaluatePolicy` 在读取时强制执行，而非依赖 `SecAccessControlCreateWithFlags`。这样做的好处是在 macOS 15+ 上无需 Hardened Runtime 或 Developer ID 签名即可正常运行。

如需将生物识别门控下沉到 Security 框架层（使其他进程也无法绕过），可切换为以下方式：

1. 使用真实 Developer ID 签名，`codesign` 加 `--options runtime`
2. 将 `KeychainHelper.store` 中的 `kSecAttrAccessible` 替换为 `SecAccessControlCreateWithFlags(.biometryCurrentSet)`

## 构建

```sh
# 仅构建（不签名）
swift build -c release

# 构建 + 签名
make

# 清理
make clean
```

## 卸载

```sh
make uninstall
# 或
make uninstall PREFIX=/usr/local/bin
```
