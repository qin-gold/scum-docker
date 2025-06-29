#!/bin/bash

# 检查服务端口是否在监听
if netstat -tuln | grep -q ":${QUERY_PORT} "; then
    exit 0
else
    echo "Health check failed: Query port ${QUERY_PORT} not listening"
    exit 1
fi