#!/bin/bash

# =====================================================
# 卸载财经新闻后端脚本
# =====================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_DIR="/opt/stock_news"
SERVICE_NAME="stock-news-api"

echo "==================================================="
print_warn "警告：此操作将删除所有服务配置和代码！"
echo "==================================================="
read -p "确认卸载？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "取消卸载"
    exit 0
fi

# 停止并禁用服务
echo "停止服务..."
systemctl stop ${SERVICE_NAME} 2>/dev/null || true
systemctl disable ${SERVICE_NAME} 2>/dev/null || true

# 删除服务文件
echo "删除服务配置..."
rm -f /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload

# 删除 Nginx 配置
echo "删除 Nginx 配置..."
rm -f /etc/nginx/conf.d/stock-news-api.conf
systemctl reload nginx 2>/dev/null || true

# 删除代码目录
echo "删除代码目录..."
rm -rf $PROJECT_DIR

echo "==================================================="
echo "卸载完成！"
echo "==================================================="
