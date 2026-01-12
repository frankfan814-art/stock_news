#!/bin/bash

# =====================================================
# 后端部署脚本（OpenCloudOS/CentOS 手动版）
# =====================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

PROJECT_DIR="/opt/stock_news"
SERVICE_NAME="stock-news-api"

# 1. 安装依赖
print_info "安装系统依赖..."
yum install -y git python3 python3-pip python3-devel epel-release nginx curl

# 2. 克隆代码
print_info "克隆代码..."
mkdir -p $PROJECT_DIR
if [ -d "$PROJECT_DIR/.git" ]; then
    cd $PROJECT_DIR && git pull
else
    rm -rf $PROJECT_DIR
    git clone https://github.com/frankfan814-art/stock_news.git $PROJECT_DIR
fi

# 3. Python 环境
print_info "配置 Python 环境..."
cd $PROJECT_DIR/backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 4. systemd 服务
print_info "配置 systemd 服务..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Stock News FastAPI Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}/backend
Environment="PATH=${PROJECT_DIR}/backend/venv/bin:/usr/local/node/bin"
ExecStart=${PROJECT_DIR}/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}

# 5. Nginx
print_info "配置 Nginx..."
cat > /etc/nginx/conf.d/stock-news-api.conf << 'EOF'
server {
    listen 80;
    server_name _;

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

    location /health {
        proxy_pass http://127.0.0.1:8000/health;
    }

    location / {
        return 200 "Stock News API is running. Access /api/news for news data.";
        add_header Content-Type text/plain;
    }
}
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

# 6. 防火墙
print_info "配置防火墙..."
systemctl start firewalld 2>/dev/null || true
systemctl enable firewalld 2>/dev/null || true
firewall-cmd --permanent --add-port=22/tcp 2>/dev/null || true
firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

# 7. 测试
sleep 3
print_info "测试服务..."
if curl -s http://localhost/health > /dev/null; then
    print_info "服务运行正常！"
else
    print_warn "健康检查失败，请查看日志: journalctl -u ${SERVICE_NAME} -f"
fi

# 8. 显示信息
echo ""
echo "==================================================="
print_info "部署完成！"
echo "==================================================="
echo ""
echo "服务地址:"
echo "  - API: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP')/api"
echo "  - 健康检查: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP')/health"
echo ""
echo "常用命令:"
echo "  systemctl status ${SERVICE_NAME}"
echo "  journalctl -u ${SERVICE_NAME} -f"
echo "  systemctl restart ${SERVICE_NAME}"
echo ""
print_warn "记得在腾讯云控制台配置安全组，开放端口: 22, 80"
echo "==================================================="
