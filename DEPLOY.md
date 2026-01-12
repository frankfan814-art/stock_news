# 腾讯云服务器部署文档

## 环境要求

- 服务器：腾讯云 CVM（2核4GB 起步）
- 操作系统：OpenCloudOS 9.4 / CentOS 7+ / Ubuntu 20.04+

---

## 一、手动部署步骤

### 1.1 安装 Node.js 18+

OpenCloudOS 使用直接下载二进制方式：

```bash
# 下载 Node.js 18 二进制包
cd /usr/local
wget https://npmmirror.com/mirrors/node/v18.20.0/node-v18.20.0-linux-x64.tar.xz

# 如果 wget 不可用，用 curl：
# curl -L https://npmmirror.com/mirrors/node/v18.20.0/node-v18.20.0-linux-x64.tar.xz -o node.tar.xz

# 解压
tar -xf node-v18.20.0-linux-x64.tar.xz
mv node-v18.20.0-linux-x64 node
rm node-v18.20.0-linux-x64.tar.xz

# 创建软链接
ln -sf /usr/local/node/bin/node /usr/bin/node
ln -sf /usr/local/node/bin/npm /usr/bin/npm
ln -sf /usr/local/node/bin/npx /usr/bin/npx

# 验证
node -v
npm -v

# 设置淘宝镜像
npm config set registry https://registry.npmmirror.com
```

### 1.2 安装基础依赖

```bash
# 更新系统
yum update -y

# 安装基础工具
yum install -y git python3 python3-pip python3-devel curl

# 安装 EPEL 仓库（OpenCloudOS 需要）
yum install -y epel-release

# 安装 Nginx
yum install -y nginx
```

### 1.3 克隆代码

```bash
# 创建项目目录
mkdir -p /opt/stock_news
cd /opt/stock_news

# 克隆代码
git clone https://github.com/frankfan814-art/stock_news.git .
```

### 1.4 安装 Python 依赖

```bash
cd backend

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt
```

### 1.5 配置 systemd 服务

```bash
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

# 启动服务
systemctl daemon-reload
systemctl enable stock-news-api
systemctl start stock-news-api

# 查看状态
systemctl status stock-news-api
```

### 1.6 配置 Nginx

```bash
cat > /etc/nginx/conf.d/stock-news-api.conf << 'EOF'
server {
    listen 80;
    server_name _;

    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
    }

    # 根路径
    location / {
        return 200 "Stock News API is running. Access /api/news for news data.";
        add_header Content-Type text/plain;
    }
}
EOF

# 测试并启动 Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx
```

### 1.7 配置防火墙

```bash
# 启动防火墙
systemctl start firewalld
systemctl enable firewalld

# 开放端口
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# 查看规则
firewall-cmd --list-ports
```

### 1.8 腾讯云安全组配置

登录 https://console.cloud.tencent.com/cvm

1. 找到你的服务器 → 点击「安全组」
2. 入站规则添加：
   - 端口：22，来源：0.0.0.0/0
   - 端口：80，来源：0.0.0.0/0
   - 端口：443，来源：0.0.0.0/0（可选）

---

## 二、快速部署脚本

由于网络问题，推荐手动执行上述步骤，或分步执行：

### 2.1 一键安装 Node.js

```bash
curl -o- https://raw.githubusercontent.com/frankfan814-art/stock_news/main/scripts/install-node.sh | bash
```

### 2.2 一键部署后端

```bash
curl -o- https://raw.githubusercontent.com/frankfan814-art/stock_news/main/scripts/deploy-backend.sh | bash
```

---

## 三、验证部署

```bash
# 检查后端服务
systemctl status stock-news-api

# 检查 Nginx
systemctl status nginx

# 测试 API
curl http://localhost/health
curl http://localhost/api/news

# 从外部测试（在本地电脑）
curl http://你的服务器IP/health
curl http://你的服务器IP/api/news
```

---

## 四、常用运维命令

```bash
# 查看后端状态
systemctl status stock-news-api

# 查看实时日志
journalctl -u stock-news-api -f

# 重启后端
systemctl restart stock-news-api

# 更新代码
cd /opt/stock_news
git pull
systemctl restart stock-news-api

# 查看 Nginx 日志
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

---

## 五、前端连接配置

### 5.1 本地 macOS 应用连接云端后端

修改 `stock_news_app/lib/api_service.dart`:

```dart
// 将 baseURL 改为服务器地址
static const String baseURL = 'http://你的服务器IP/api';
```

### 5.2 Web 版本部署（可选）

在本地 Mac 编译 Web 版本：

```bash
cd stock_news_app
flutter build web
```

将 `build/web` 目录上传到服务器：

```bash
scp -r build/web root@你的服务器IP:/var/www/stock-news-web
```

Nginx 配置：

```nginx
server {
    listen 80;
    server_name 你的域名.com;
    root /var/www/stock-news-web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000;
    }
}
```

---

## 六、故障排查

### 6.1 Node.js 不可用

```bash
# 检查软链接
ls -la /usr/bin/node
ls -la /usr/local/node/bin/node

# 重新创建软链接
ln -sf /usr/local/node/bin/node /usr/bin/node
ln -sf /usr/local/node/bin/npm /usr/bin/npm
```

### 6.2 后端启动失败

```bash
# 查看详细日志
journalctl -u stock-news-api -n 50 --no-pager

# 手动测试
cd /opt/stock_news/backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 6.3 Nginx 502 错误

```bash
# 检查后端是否运行
systemctl status stock-news-api

# 检查端口
netstat -tlnp | grep 8000
```

---

## 七、服务地址

部署完成后，可访问以下地址：

| 服务 | 地址 |
|------|------|
| 健康检查 | `http://你的服务器IP/health` |
| 新闻列表 | `http://你的服务器IP/api/news` |
| 抓取新闻 | `http://你的服务器IP/api/crawl` (POST) |

---

## 八、项目仓库

https://github.com/frankfan814-art/stock_news
