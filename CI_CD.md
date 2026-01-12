# GitHub Actions CI/CD 自动部署配置

本文档说明如何配置 GitHub Actions 实现代码提交后自动部署到服务器。

## 工作原理

```
代码 Push 到 main 分支
    ↓
GitHub Actions 触发
    ↓
SSH 连接到服务器
    ↓
拉取最新代码
    ↓
重启后端服务
    ↓
部署完成
```

## 配置步骤

### 1. 生成 SSH 密钥对

在本地电脑上执行：

```bash
# 生成 SSH 密钥（如果没有）
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions_key

# 查看公钥
cat ~/.ssh/github_actions_key.pub
```

### 2. 服务器配置

登录服务器并添加公钥：

```bash
# 登录服务器
ssh root@124.222.203.221

# 添加 GitHub Actions 公钥到服务器
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 将公钥添加到 authorized_keys（复制本地生成的公钥内容）
echo "ssh-ed25519 AAAA... github-actions" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 测试 SSH 连接（在本地执行）
ssh -i ~/.ssh/github_actions_key root@124.222.203.221
```

### 3. 配置 GitHub Secrets

进入 GitHub 仓库设置：

1. 打开 https://github.com/frankfan814-art/stock_news/settings/secrets/actions
2. 点击 "New repository secret"
3. 添加以下 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SERVER_HOST` | `124.222.203.221` | 服务器 IP |
| `SERVER_USER` | `root` | SSH 用户名 |
| `SSH_PRIVATE_KEY` | 私钥内容 | 本地 `~/.ssh/github_actions_key` 的内容 |
| `SSH_PORT` | `22` | SSH 端口（默认22） |

#### 获取私钥内容：

```bash
# 在本地执行
cat ~/.ssh/github_actions_key
```

复制全部内容（包括 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----`）粘贴到 Secret 值中。

### 4. 验证配置

推送代码到 main 分支：

```bash
git add .
git commit -m "test: trigger auto deploy"
git push origin main
```

然后在 GitHub 查看 Actions 运行状态：
https://github.com/frankfan814-art/stock_news/actions

## 手动部署脚本

如果自动部署失败，可以在服务器上手动执行：

```bash
# 方式1：使用脚本
cd /opt/stock_news/scripts
chmod +x auto-deploy.sh
./auto-deploy.sh

# 方式2：手动命令
cd /opt/stock_news
git pull origin main
systemctl restart stock-news-api
systemctl status stock-news-api
```

## 故障排查

### GitHub Actions 失败

1. **SSH 连接失败**
   - 检查 Secret 值是否正确
   - 确认服务器防火墙允许 SSH
   - 测试：`ssh -i ~/.ssh/github_actions_key root@124.222.203.221`

2. **权限不足**
   - 确保 `/opt/stock_news` 目录权限正确
   - 检查 `.git` 目录权限

3. **服务启动失败**
   - 查看服务日志：`journalctl -u stock-news-api -n 50`
   - 检查 Python 依赖是否安装

### 查看部署日志

```bash
# GitHub Actions 日志
# 访问：https://github.com/frankfan814-art/stock_news/actions

# 服务器日志
ssh root@124.222.203.221
journalctl -u stock-news-api -f
tail -f /opt/stock_news/backend/logs/app.log
```

## Workflow 文件说明

`.github/workflows/deploy.yml` 文件说明：

```yaml
on:
  push:
    branches:
      - main    # 当推送到 main 分支时触发
```

部署步骤：
1. 使用 SSH 连接到服务器
2. 进入项目目录
3. 拉取最新代码
4. 重启服务
5. 检查服务状态
6. 测试 API 健康检查

## 安全建议

1. **使用最小权限**：创建专门的部署用户，而非 root
2. **限制 IP**：在服务器防火墙中限制 GitHub Actions IP 范围
3. **定期轮换密钥**：定期更换 SSH 密钥
4. **监控日志**：定期检查部署日志和服务器日志

## 参考资料

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [SSH Action](https://github.com/appleboy/ssh-action)
