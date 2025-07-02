#!/bin/bash

# 改进的健康检查脚本
HEALTH_LOG="/opt/scumserver/logs/health.log"

log_health() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HEALTH_LOG" 2>/dev/null || true
}

# 检查端口监听状态
check_ports() {
    if netstat -tuln 2>/dev/null | grep -q ":${QUERY_PORT} "; then
        return 0
    else
        log_health "端口检查失败: 查询端口 ${QUERY_PORT} 未监听"
        return 1
    fi
}

# 检查SCUM进程状态
check_process() {
    if pgrep -f "SCUMServer.exe" >/dev/null 2>&1; then
        return 0
    else
        log_health "进程检查失败: SCUMServer.exe 进程不存在"
        return 1
    fi
}

# 检查内存使用率
check_memory() {
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$mem_usage" -gt 98 ]; then
        log_health "内存检查失败: 内存使用率 ${mem_usage}% 过高"
        return 1
    else
        return 0
    fi
}

# 综合健康检查
if check_ports && check_process && check_memory; then
    exit 0
else
    log_health "健康检查失败"
    exit 1
fi