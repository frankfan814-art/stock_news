#!/bin/bash

# =====================================================
# 更新财经新闻后端脚本
# =====================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

PROJECT_DIR="/opt/stock_news"
SERVICE_NAME="stock-news-api"

print_info "开始更新..."

# 拉取最新代码
cd $PROJECT_DIR
git pull

# 更新依赖
cd backend
source venv/bin/activate
pip install -r requirements.txt

# 重启服务
systemctl restart ${SERVICE_NAME}

# 等待服务启动
sleep 3

# 检查状态
systemctl status ${SERVICE_NAME} --no-pager

print_info "更新完成！"
print_info "查看日志: journalctl -u ${SERVICE_NAME} -f"
