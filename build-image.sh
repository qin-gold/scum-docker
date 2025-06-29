#!/bin/bash

# 设置镜像名称和标签
IMAGE_NAME="scum-server-image"
TAG="test"
FULL_NAME="${IMAGE_NAME}:${TAG}"

# 构建镜像
echo "🔨 Building Docker image: ${FULL_NAME}"
docker build -t "${FULL_NAME}" .

# 检查构建结果
if [ $? -eq 0 ]; then
    echo "✅ Successfully built ${FULL_NAME}"
    echo "You can now run the server with:"
    echo "docker run -d --name scum-server \\"
    echo "  -p 7777:7777/udp -p 7777:7777/tcp \\"
    echo "  -p 27015:27015/udp -p 27015:27015/tcp \\"
    echo "  --memory=24g --memory-swap=32g \\"
    echo "  ${FULL_NAME}"
else
    echo "❌ Docker build failed"
    exit 1
fi