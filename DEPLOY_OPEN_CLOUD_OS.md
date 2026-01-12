# OpenCloudOS 9.4 部署笔记

本文档记录了在 OpenCloudOS 9.4 系统上部署的实际经验和注意事项。

## 系统信息

- 操作系统: OpenCloudOS 9.4
- Python: 3.11.6
- Node.js: v18.20.0
- Web服务器: OpenResty 1.21.4.4 (Nginx 兼容)

## 与标准部署文档的主要差异

### 1. Nginx 替换为 OpenResty

OpenCloudOS 9.4 默认的 nginx 包存在过滤问题，改用 OpenResty：

```bash
yum install -y openresty
```

OpenResty 配置目录: `/usr/local/openresty/nginx/conf/`

### 2. 创建配置目录

OpenResty 默认没有 `conf.d` 目录，需要手动创建：

```bash
mkdir -p /usr/local/openresty/nginx/conf/conf.d
```

### 3. 修改主配置文件

编辑 `/usr/local/openresty/nginx/conf/nginx.conf`，在 http 块中添加：

```nginx
http {
    ...
    # Include conf.d configurations
    include conf.d/*.conf;

    server {
        listen       8080;  # 默认端口改为 8080，避免冲突
        ...
    }
}
```

### 4. API 代理配置

创建 `/usr/local/openresty/nginx/conf/conf.d/stock-news-api.conf`：

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

注意：超时时间设置为 300 秒，因为新闻爬取操作可能需要 2-3 分钟。

### 5. 日志目录

确保创建日志目录，否则服务启动失败：

```bash
mkdir -p /root/stock_news/backend/logs
```

### 6. Playwright 依赖

OpenCloudOS 不是 Playwright 官方支持的系统，需要手动安装依赖：

```bash
yum install -y alsa-lib-devel gtk3-devel libgbm libXcomposite libXcursor \
    libXdamage libXext libXi libXrandr libXtst cups-libs libdrm \
    libxkbcommon mesa-libgbm nss at-spi2-atk pango
```

然后安装浏览器：

```bash
source venv/bin/activate
playwright install chromium
```

## 完整部署步骤

```bash
# 1. 安装系统依赖
yum install -y git python3 python3-pip python3-devel openresty

# 2. 克隆代码
cd /opt
git clone https://github.com/frankfan814-art/stock_news.git
cd stock_news/backend

# 3. 创建 Python 虚拟环境并安装依赖
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 4. 安装 Playwright 浏览器
playwright install chromium

# 5. 创建日志目录
mkdir -p logs

# 6. 创建 systemd 服务
cat > /etc/systemd/system/stock-news-api.service << 'EOF'
[Unit]
Description=Stock News FastAPI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/stock_news/backend
Environment="PATH=/opt/stock_news/backend/venv/bin:/usr/local/node/bin"
ExecStart=/opt/stock_news/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务
systemctl daemon-reload
systemctl enable stock-news-api
systemctl start stock-news-api

# 8. 配置 OpenResty
mkdir -p /usr/local/openresty/nginx/conf/conf.d
cat > /usr/local/openresty/nginx/conf/conf.d/stock-news-api.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

# 在 http 块中添加 include conf.d/*.conf
# 编辑 /usr/local/openresty/nginx/conf/nginx.conf

# 启动 OpenResty
/usr/local/openresty/nginx/sbin/nginx
/usr/local/openresty/nginx/sbin/nginx -s reload

# 9. 配置防火墙
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

# 10. 验证部署
curl http://localhost/health
curl http://localhost/news
```

## OpenResty 常用命令

```bash
# 测试配置
/usr/local/openresty/nginx/sbin/nginx -t

# 启动
/usr/local/openresty/nginx/sbin/nginx

# 重载配置
/usr/local/openresty/nginx/sbin/nginx -s reload

# 停止
/usr/local/openresty/nginx/sbin/nginx -s stop
```

## 故障排查

### 服务启动失败

检查日志目录是否存在：

```bash
ls -la /opt/stock_news/backend/logs
```

### Nginx 502/504 超时

- 确认后端服务运行: `systemctl status stock-news-api`
- 增加超时时间到 300 秒
- 查看后端日志: `journalctl -u stock-news-api -f`

### Playwright 浏览器无法启动

确保系统依赖已安装，运行：

```bash
source venv/bin/activate
playwright install-deps chromium
```

## 部署验证

```bash
# 健康检查
curl http://localhost/health

# 获取新闻（先触发爬取）
curl -X POST http://localhost/crawl

# 获取新闻列表
curl http://localhost/news

# 查看 API 文档
# 浏览器访问: http://服务器IP/docs
```
