# 财经新闻应用部署文档

## 项目架构

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │      │                 │
│  Flutter Web    │─────▶│   OpenResty     │─────▶│   FastAPI       │
│   前端应用      │      │    Nginx        │      │    后端 API     │
│                 │      │  (Port 80)      │      │  (Port 8000)    │
└─────────────────┘      └─────────────────┘      └─────────────────┘
                                                        │
                                                        ▼
                                                 新闻爬虫模块
```

## 目录结构

```
/opt/stock_news/              # 项目根目录
├── backend/                  # Python 后端
│   ├── app/                  # FastAPI 应用
│   ├── scraper/              # 爬虫模块
│   └── venv/                 # Python 虚拟环境
├── stock_news_app/           # Flutter 前端
│   ├── lib/                  # Dart 源码
│   ├── web/                  # Web 入口
│   └── build/                # 构建输出
└── .github/workflows/        # CI/CD 配置
    └── deploy.yml
```

## 服务器信息

- **服务器**: 124.222.203.221 (腾讯云)
- **操作系统**: OpenCloudOS 9 / CentOS 7+
- **OpenResty**: `/usr/local/openresty/nginx/`
- **项目目录**: `/opt/stock_news/`
- **Web 目录**: `/var/www/stock_news/`

## 本地开发

### 后端开发

```bash
cd /opt/stock_news/backend

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 启动开发服务器
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 前端开发

```bash
cd /opt/stock_news/stock_news_app

# 获取依赖
flutter pub get

# 运行 Web 版本（开发模式）
flutter run -d chrome

# 或使用本地构建预览
flutter build web --base-href "/"
```

## 部署流程

### 自动部署 (推荐)

推送代码到 `main` 分支会自动触发部署：

1. **后端更新**:
   ```bash
   git add .
   git commit -m "feat: xxx"
   git push origin main
   ```

2. **前端更新**:
   ```bash
   cd stock_news_app
   # 修改代码后
   git add .
   git commit -m "feat: xxx"
   git push origin main
   ```

GitHub Actions 会自动：
- 构建 Flutter Web 应用
- 部署到服务器
- 重启后端服务
- 重载 Nginx

### 手动部署

#### 部署后端

```bash
cd /opt/stock_news
git pull origin main
systemctl restart stock-news-api
```

#### 部署前端 (本地构建)

```bash
# 1. 在本地构建
cd stock_news_app
flutter build web --release --base-href "/"

# 2. 上传到服务器
scp -r build/web/* root@124.222.203.221:/var/www/stock_news/

# 3. 重载 Nginx (在服务器上)
ssh root@124.222.203.221 "nginx -s reload"
```

## 服务管理

### 后端服务

```bash
# 启动服务
systemctl start stock-news-api

# 停止服务
systemctl stop stock-news-api

# 重启服务
systemctl restart stock-news-api

# 查看状态
systemctl status stock-news-api

# 查看日志
journalctl -u stock-news-api -f
```

### Nginx 管理

```bash
# 测试配置
/usr/local/openresty/nginx/sbin/nginx -t

# 重载配置
/usr/local/openresty/nginx/sbin/nginx -s reload

# 查看错误日志
tail -f /usr/local/openresty/nginx/logs/error.log
```

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/crawl` | POST | 触发新闻抓取 |
| `/news` | GET | 获取新闻列表 |
| `/last-update` | GET | 获取最后更新时间 |

### 请求示例

```bash
# 健康检查
curl http://124.222.203.221/health

# 抓取新闻
curl -X POST http://124.222.203.221/crawl \
  -H "Content-Type: application/json" \
  -d '{"keywords": ["股票"]}'

# 获取新闻
curl http://124.222.203.221/news?keywords=股票

# 获取最后更新时间
curl http://124.222.203.221/last-update
```

## 环境变量

### GitHub Secrets (必需)

在 GitHub 仓库设置中配置以下 Secrets：

- `SERVER_HOST`: 124.222.203.221
- `SERVER_USER`: root
- `SSH_PASSWORD`: 服务器 SSH 密码
- `SSH_PORT`: 22

### 后端环境

- Python 3.10+
- 虚拟环境: `/opt/stock_news/backend/venv/`

### 前端环境

- Flutter 3.24.5+
- Dart 3.5+

## 故障排查

### 后端无法启动

```bash
# 检查日志
journalctl -u stock-news-api -n 50

# 手动启动查看错误
cd /opt/stock_news/backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 前端 403 错误

```bash
# 检查文件权限
ls -la /var/www/stock_news/

# 修复权限
chown -R nobody:nobody /var/www/stock_news
chmod -R 755 /var/www/stock_news

# 检查 Nginx 错误日志
tail -f /usr/local/openresty/nginx/logs/error.log
```

### CI/CD 失败

检查 GitHub Actions 日志：
1. 进入仓库的 "Actions" 标签
2. 点击失败的工作流
3. 查看具体错误信息

常见问题：
- SSH 密码错误：检查 `SSH_PASSWORD` Secret
- Flutter 构建失败：检查 Dart SDK 版本兼容性
- 文件上传失败：检查服务器磁盘空间

## 监控

### 系统监控

```bash
# CPU 和内存使用
top

# 磁盘使用
df -h

# 网络连接
netstat -tulpn | grep :8000
```

### 服务监控

```bash
# 后端健康检查
watch -n 5 'curl -s http://localhost/health | jq'

# Nginx 访问日志
tail -f /usr/local/openresty/nginx/logs/access.log
```

## 更新日志

- 2025-01-12: 添加 Flutter Web 自动部署
- 2025-01-12: 配置 OpenResty Nginx
- 2025-01-12: 初始化后端 API 服务
