#!/bin/bash

# =====================================================
# Node.js 18 安装脚本（适用于 OpenCloudOS/CentOS）
# =====================================================

set -e

GREEN='\033[0;32m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

print_info "开始安装 Node.js 18..."

# 检查是否已安装
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -ge 18 ]; then
        print_info "Node.js 已安装，版本: $(node -v)"
        exit 0
    fi
fi

# 下载 Node.js 18 二进制包
cd /tmp
NODE_VERSION="18.20.0"
NODE_FILE="node-v${NODE_VERSION}-linux-x64.tar.xz"

print_info "下载 Node.js ${NODE_VERSION}..."
wget -q --show-progress https://npmmirror.com/mirrors/node/v${NODE_VERSION}/${NODE_FILE}

# 如果 wget 失败，尝试 curl
if [ ! -f "$NODE_FILE" ]; then
    print_info "wget 失败，尝试 curl..."
    curl -L -o "$NODE_FILE" https://npmmirror.com/mirrors/node/v${NODE_VERSION}/${NODE_FILE}
fi

# 解压到 /usr/local
print_info "解压并安装..."
tar -xf "$NODE_FILE" -C /usr/local
mv /usr/local/node-v${NODE_VERSION}-linux-x64 /usr/local/node
rm -f "$NODE_FILE"

# 创建软链接
ln -sf /usr/local/node/bin/node /usr/bin/node
ln -sf /usr/local/node/bin/npm /usr/bin/npm
ln -sf /usr/local/node/bin/npx /usr/bin/npx

# 设置淘宝镜像
/usr/local/node/bin/npm config set registry https://registry.npmmirror.com

print_info "Node.js 版本: $(node -v)"
print_info "npm 版本: $(npm -v)"
print_info "安装完成！"
