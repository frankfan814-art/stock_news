#!/bin/bash
# 服务器自动部署脚本

set -e

echo "=========================================="
echo "  Stock News Auto Deploy"
echo "=========================================="

# 项目目录
PROJECT_DIR="/opt/stock_news"
SERVICE_NAME="stock-news-api"

# 进入项目目录
cd "$PROJECT_DIR" || exit 1

echo ""
echo "[1/5] Pulling latest code..."
git pull origin main

echo ""
echo "[2/5] Checking Python virtual environment..."
if [ ! -d "venv" ]; then
    echo "Virtual environment not found, creating..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r backend/requirements.txt
else
    echo "Virtual environment exists"
fi

echo ""
echo "[3/5] Installing dependencies..."
source venv/bin/activate
pip install -r backend/requirements.txt --quiet

echo ""
echo "[4/5] Restarting service..."
systemctl restart "$SERVICE_NAME"

echo ""
echo "[5/5] Waiting for service to be ready..."
sleep 5

# 检查服务状态
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✓ Service is running"
else
    echo "✗ Service failed to start"
    systemctl status "$SERVICE_NAME"
    exit 1
fi

# 测试 API
echo ""
echo "Testing API..."
HEALTH_CHECK=$(curl -s http://localhost/health)
if echo "$HEALTH_CHECK" | grep -q "ok"; then
    echo "✓ API is healthy"
else
    echo "✗ API health check failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "  Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Service: $SERVICE_NAME"
echo "Status: $(systemctl is-active $SERVICE_NAME)"
echo "Time: $(date)"
