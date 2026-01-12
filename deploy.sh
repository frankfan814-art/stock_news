#!/bin/bash

# =====================================================
# 财经新闻后端自动部署脚本
# 适用于: OpenCloudOS/CentOS 7+/Ubuntu 20.04+
# =====================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_DIR="/opt/stock_news"
SERVICE_NAME="stock-news-api"
NODE_VERSION="18.20.0"

# =====================================================
# 检测系统
# =====================================================
detect_os() {
    print_info "检测操作系统..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        print_info "操作系统: $OS $VERSION_ID"
    else
        print_error "无法检测操作系统"
        exit 1
    fi
}

# =====================================================
# 安装 Node.js 18（二进制方式）
# =====================================================
install_nodejs() {
    print_info "检查 Node.js..."

    if command -v node &> /dev/null; then
        V=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$V" -ge 18 ]; then
            print_info "Node.js 已安装: $(node -v)"
            return
        fi
    fi

    print_info "安装 Node.js ${NODE_VERSION}..."

    # 下载
    cd /tmp
    wget -q --show-progress https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz 2>/dev/null || \
    curl -L -o node-v${NODE_VERSION}-linux-x64.tar.xz https://npmmirror.com/mirrors/node/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz

    # 解压
    tar -xf node-v${NODE_VERSION}-linux-x64.tar.xz -C /usr/local
    mv /usr/local/node-v${NODE_VERSION}-linux-x64 /usr/local/node
    rm -f node-v${NODE_VERSION}-linux-x64.tar.xz

    # 软链接
    ln -sf /usr/local/node/bin/node /usr/bin/node
    ln -sf /usr/local/node/bin/npm /usr/bin/npm
    ln -sf /usr/local/node/bin/npx /usr/bin/npx

    /usr/local/node/bin/npm config set registry https://registry.npmmirror.com

    print_info "Node.js: $(node -v), npm: $(npm -v)"
}

# =====================================================
# 安装系统依赖
# =====================================================
install_dependencies() {
    print_info "安装系统依赖..."

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        apt update -y
        apt install -y git python3 python3-pip python3-venv nginx curl
    else
        yum install -y git python3 python3-pip python3-devel curl

        # OpenCloudOS/CentOS 需要 EPEL
        if [ "$OS" = "opencloudos" ] || [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
            yum install -y epel-release
        fi

        yum install -y nginx

        # pip
        if ! command -v pip3 &> /dev/null; then
            curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            python3 get-pip.py
            rm get-pip.py
        fi
    fi

    print_info "Python: $(python3 --version)"
}

# =====================================================
# 克隆代码
# =====================================================
clone_code() {
    print_info "克隆代码..."
    mkdir -p $PROJECT_DIR

    if [ -d "$PROJECT_DIR/.git" ]; then
        cd $PROJECT_DIR && git pull
    else
        rm -rf $PROJECT_DIR
        git clone https://github.com/frankfan814-art/stock_news.git $PROJECT_DIR
    fi
}

# =====================================================
# Python 环境
# =====================================================
setup_python_env() {
    print_info "配置 Python 环境..."
    cd $PROJECT_DIR/backend

    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
}

# =====================================================
# systemd 服务
# =====================================================
setup_systemd_service() {
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

    sleep 3
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        print_info "后端服务启动成功"
    else
        print_error "服务启动失败"
        journalctl -u ${SERVICE_NAME} -n 20 --no-pager
        exit 1
    fi
}

# =====================================================
# Nginx 配置
# =====================================================
setup_nginx() {
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
}

# =====================================================
# 防火墙
# =====================================================
setup_firewall() {
    print_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        systemctl start firewalld 2>/dev/null || true
        systemctl enable firewalld 2>/dev/null || true
        firewall-cmd --permanent --add-port=22/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        print_info "防火墙规则: $(firewall-cmd --list-ports 2>/dev/null || echo 'N/A')"
    elif command -v ufw &> /dev/null; then
        ufw allow 22/tcp 2>/dev/null || true
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        ufw --force enable 2>/dev/null || true
    fi
}

# =====================================================
# 测试
# =====================================================
test_services() {
    print_info "测试服务..."
    sleep 2

    curl -s http://localhost/health > /dev/null && \
        print_info "服务测试成功" || \
        print_warn "健康检查失败"

    echo ""
    curl -s http://localhost/api/news | head -c 200
    echo ""
}

# =====================================================
# 显示信息
# =====================================================
show_info() {
    IP=$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP')
    echo ""
    echo "==================================================="
    print_info "部署完成！"
    echo "==================================================="
    echo ""
    echo "环境:"
    echo "  - Python: $(python3 --version)"
    echo "  - Node.js: $(node -v 2>/dev/null || echo '未安装')"
    echo ""
    echo "服务地址:"
    echo "  - API: http://${IP}/api"
    echo "  - 健康检查: http://${IP}/health"
    echo ""
    echo "运维命令:"
    echo "  systemctl status ${SERVICE_NAME}"
    echo "  journalctl -u ${SERVICE_NAME} -f"
    echo "  systemctl restart ${SERVICE_NAME}"
    echo ""
    print_warn "腾讯云控制台安全组开放端口: 22, 80"
    echo "==================================================="
    echo ""
}

# =====================================================
# 主函数
# =====================================================
main() {
    echo "==================================================="
    echo "       财经新闻后端自动部署"
    echo "==================================================="
    echo ""

    detect_os
    install_dependencies
    install_nodejs
    clone_code
    setup_python_env
    setup_systemd_service
    setup_nginx
    setup_firewall
    test_services
    show_info
}

main
