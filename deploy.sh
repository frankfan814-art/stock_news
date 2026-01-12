#!/bin/bash

# =====================================================
# 财经新闻后端自动部署脚本
# 适用于: CentOS 7+/OpenCloudOS/Ubuntu 20.04+
# 安装内容: Python3, Node.js 18+, Nginx, FastAPI
# =====================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配置变量
PROJECT_DIR="/opt/stock_news"
BACKEND_DIR="$PROJECT_DIR/backend"
SERVICE_NAME="stock-news-api"
SERVER_PORT=8000
NGINX_PORT=80
REPO_URL="https://github.com/frankfan814-art/stock_news.git"

# =====================================================
# 1. 检测操作系统类型
# =====================================================
detect_os() {
    print_info "检测操作系统..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_info "操作系统: $OS $OS_VERSION"
    else
        print_error "无法检测操作系统类型"
        exit 1
    fi
}

# =====================================================
# 2. 安装基础依赖
# =====================================================
install_dependencies() {
    print_info "安装基础依赖..."

    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        # Ubuntu/Debian
        apt update -y
        apt install -y git python3 python3-pip python3-venv nginx curl
    else
        # CentOS/OpenCloudOS/RHEL
        yum install -y git python3 python3-pip python3-devel nginx curl

        # 确保 pip3 可用
        if ! command -v pip3 &> /dev/null; then
            print_info "pip3 不可用，尝试安装..."
            curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
            python3 get-pip.py
            rm get-pip.py
        fi
    fi

    print_info "Python 版本: $(python3 --version)"
}

# =====================================================
# 3. 安装 Node.js 18+
# =====================================================
install_nodejs() {
    print_info "安装 Node.js 18+..."

    # 检查是否已安装 Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            print_info "Node.js 已安装，版本: $(node -v)"
            return
        else
            print_warn "Node.js 版本过低 ($(node -v))，需要 18+，将重新安装"
        fi
    fi

    # 使用 NodeSource 官方脚本安装 Node.js 18.x
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    else
        # CentOS/OpenCloudOS/RHEL
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs
    fi

    print_info "Node.js 版本: $(node -v)"
    print_info "npm 版本: $(npm -v)"

    # 配置 npm 使用淘宝镜像（可选，国内更快）
    npm config set registry https://registry.npmmirror.com
    print_info "npm 镜像已设置为淘宝镜像"
}

# =====================================================
# 4. 克隆代码
# =====================================================
clone_code() {
    print_info "克隆代码仓库..."

    # 创建目录
    mkdir -p $PROJECT_DIR

    # 如果目录已存在且有 git 仓库，先更新
    if [ -d "$PROJECT_DIR/.git" ]; then
        print_info "代码已存在，拉取最新版本..."
        cd $PROJECT_DIR
        git pull
    else
        # 删除旧目录（如果存在但不是 git 仓库）
        if [ -d "$PROJECT_DIR" ] && [ ! -d "$PROJECT_DIR/.git" ]; then
            print_warn "删除旧目录..."
            rm -rf $PROJECT_DIR
            mkdir -p $PROJECT_DIR
        fi

        # 克隆代码
        git clone $REPO_URL $PROJECT_DIR
    fi
}

# =====================================================
# 4. 创建虚拟环境并安装依赖
# =====================================================
setup_python_env() {
    print_info "设置 Python 虚拟环境..."

    cd $BACKEND_DIR

    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi

    # 激活虚拟环境并安装依赖
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt

    print_info "Python 依赖安装完成"
}

# =====================================================
# 5. 配置 systemd 服务
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
WorkingDirectory=${BACKEND_DIR}
Environment="PATH=${BACKEND_DIR}/venv/bin"
ExecStart=${BACKEND_DIR}/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${SERVER_PORT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 重载并启动服务
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}
    systemctl restart ${SERVICE_NAME}

    # 等待服务启动
    sleep 3

    # 检查服务状态
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        print_info "后端服务启动成功"
    else
        print_error "后端服务启动失败，查看日志："
        journalctl -u ${SERVICE_NAME} -n 20 --no-pager
        exit 1
    fi
}

# =====================================================
# 6. 配置 Nginx
# =====================================================
setup_nginx() {
    print_info "配置 Nginx..."

    # 备份原配置
    if [ -f /etc/nginx/nginx.conf ]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    fi

    # 创建站点配置
    cat > /etc/nginx/conf.d/stock-news-api.conf << EOF
server {
    listen ${NGINX_PORT};
    server_name _;

    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:${SERVER_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 健康检查
    location /health {
        proxy_pass http://127.0.0.1:${SERVER_PORT}/health;
    }

    # 根路径
    location / {
        return 200 "Stock News API is running. Access /api/news for news data.";
        add_header Content-Type text/plain;
    }
}
EOF

    # 测试配置
    nginx -t

    # 启动 Nginx
    systemctl enable nginx
    systemctl restart nginx

    print_info "Nginx 配置完成"
}

# =====================================================
# 7. 配置防火墙
# =====================================================
setup_firewall() {
    print_info "配置防火墙..."

    # 检测防火墙类型
    if command -v firewall-cmd &> /dev/null; then
        # firewalld (CentOS/OpenCloudOS)
        systemctl start firewalld 2>/dev/null || true
        systemctl enable firewalld 2>/dev/null || true

        firewall-cmd --permanent --add-port=22/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=${NGINX_PORT}/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true

        print_info "防火墙规则 (firewalld): $(firewall-cmd --list-ports 2>/dev/null || echo 'N/A')"
    elif command -v ufw &> /dev/null; then
        # ufw (Ubuntu/Debian)
        ufw allow 22/tcp 2>/dev/null || true
        ufw allow ${NGINX_PORT}/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        ufw --force enable 2>/dev/null || true

        print_info "防火墙状态 (ufw): $(ufw status 2>/dev/null | head -5 || echo 'N/A')"
    else
        print_warn "未检测到防火墙或防火墙未运行"
    fi
}

# =====================================================
# 8. 测试服务
# =====================================================
test_services() {
    print_info "测试服务..."

    # 测试后端直连
    sleep 2
    if curl -s http://localhost:${SERVER_PORT}/health > /dev/null; then
        print_info "后端直连测试成功 (端口 ${SERVER_PORT})"
    else
        print_error "后端直连测试失败"
    fi

    # 测试 Nginx 代理
    if curl -s http://localhost/health > /dev/null; then
        print_info "Nginx 代理测试成功 (端口 ${NGINX_PORT})"
    else
        print_error "Nginx 代理测试失败"
    fi

    # 测试 API
    sleep 1
    print_info "测试 API 接口..."
    curl -s http://localhost/api/news | head -c 200
    echo ""
}

# =====================================================
# 10. 显示部署信息
# =====================================================
show_info() {
    echo ""
    echo "==================================================="
    print_info "部署完成！"
    echo "==================================================="
    echo ""
    echo "环境信息:"
    echo "  - Python: $(python3 --version)"
    echo "  - Node.js: $(node -v 2>/dev/null || echo '未安装')"
    echo "  - npm: $(npm -v 2>/dev/null || echo '未安装')"
    echo ""
    echo "服务信息:"
    echo "  - 后端地址: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP'):${SERVER_PORT}"
    echo "  - API 地址: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP')/api"
    echo "  - 健康检查: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的服务器IP')/health"
    echo ""
    echo "常用命令:"
    echo "  - 查看后端状态: systemctl status ${SERVICE_NAME}"
    echo "  - 查看后端日志: journalctl -u ${SERVICE_NAME} -f"
    echo "  - 重启后端: systemctl restart ${SERVICE_NAME}"
    echo "  - 查看 Nginx 日志: tail -f /var/log/nginx/access.log"
    echo ""
    print_warn "请确保在腾讯云控制台配置安全组，开放端口: 22, ${NGINX_PORT}"
    echo "==================================================="
    echo ""
}

# =====================================================
# 主函数
# =====================================================
main() {
    echo "==================================================="
    echo "       财经新闻后端自动部署脚本"
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

# 运行主函数
main
