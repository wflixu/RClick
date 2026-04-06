#!/bin/bash

# RClick 运行脚本 - 自动复制应用并启动

APP_NAME="RClick"
BUILD_DIR="${PWD}/DerivedData/RClick/Build/Products/Debug"
APP_PATH="/Applications/${APP_NAME}.app"

echo "Building ${APP_NAME}..."

# 构建项目
xcodebuild -project RClick.xcodeproj \
           -scheme RClick \
           -configuration Debug \
           -destination 'platform=macOS' \
           build

if [ $? -ne 0 ]; then
    echo "构建失败!"
    exit 1
fi

echo "Copying app to /Applications..."
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${APP_PATH}"

# 停止旧进程
killall "${APP_NAME}" 2>/dev/null || true

echo "Starting ${APP_NAME}..."
open "${APP_PATH}"

echo "Done! Check Console.app for logs."
