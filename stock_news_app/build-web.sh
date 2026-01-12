#!/bin/bash
# Flutter Web 编译脚本 - 自动移除 Google Fonts

echo "开始编译 Flutter Web..."

# 清理旧的编译
flutter clean

# 获取依赖
flutter pub get

# 编译 Web 版本
flutter build web --release --tree-shake-icons

# 移除 Google Fonts 引用
echo "移除 Google Fonts 引用..."
cd build/web
sed -i.bak 's|https://fonts.gstatic.com/s/||g' main.dart.js
rm -f main.dart.js.bak

echo "✓ 编译完成！"
echo "✓ Google Fonts 已禁用"
echo ""
echo "运行方式："
echo "  flutter run -d chrome"
echo ""
echo "或直接打开："
echo "  open build/web/index.html"
