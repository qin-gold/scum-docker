#!/bin/bash

# 内存监控和OOM预防脚本
MEMORY_LOG="$SCUM_HOME/logs/memory.log"
OOM_THRESHOLD=90  # 内存使用率阈值（百分比）
CHECK_INTERVAL=30 # 检查间隔（秒）
RESTART_THRESHOLD=95 # 重启阈值（百分比）

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MEMORY_LOG"
}

get_memory_usage() {
    # 获取系统内存使用率
    local mem_info=$(free | grep '^Mem:')
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    local usage_percent=$((used * 100 / total))
    echo $usage_percent
}

get_process_memory() {
    # 获取SCUM进程内存使用情况
    local scum_pid=$(pgrep -f "SCUMServer.exe" | head -1)
    if [ -n "$scum_pid" ]; then
        local mem_kb=$(ps -o rss= -p $scum_pid 2>/dev/null)
        if [ -n "$mem_kb" ]; then
            echo $((mem_kb / 1024))  # 转换为MB
        else
            echo 0
        fi
    else
        echo 0
    fi
}

cleanup_memory() {
    log_message "内存清理：执行垃圾回收..."
    
    # 清理系统缓存
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    # 强制Wine垃圾回收
    wineserver -k 2>/dev/null || true
    sleep 2
    wineserver -p 2>/dev/null || true
}

emergency_restart() {
    log_message "紧急重启：内存使用率过高，执行服务器重启..."
    
    # 发送SIGTERM信号给父进程
    kill -TERM $PPID
    
    # 等待清理
    sleep 10
    
    # 如果还没有退出，强制终止
    kill -KILL $PPID 2>/dev/null || true
}

monitor_memory() {
    log_message "内存监控启动 - 阈值: ${OOM_THRESHOLD}%, 重启阈值: ${RESTART_THRESHOLD}%"
    
    local consecutive_high=0
    local max_consecutive=3
    
    while true; do
        local mem_usage=$(get_memory_usage)
        local scum_mem=$(get_process_memory)
        
        # 记录内存状态
        log_message "内存状态 - 系统使用率: ${mem_usage}%, SCUM进程: ${scum_mem}MB"
        
        if [ $mem_usage -ge $RESTART_THRESHOLD ]; then
            consecutive_high=$((consecutive_high + 1))
            log_message "警告：内存使用率达到 ${mem_usage}% (连续 ${consecutive_high} 次)"
            
            if [ $consecutive_high -ge $max_consecutive ]; then
                emergency_restart
                exit 1
            fi
        elif [ $mem_usage -ge $OOM_THRESHOLD ]; then
            log_message "警告：内存使用率 ${mem_usage}% 超过阈值，执行清理..."
            cleanup_memory
            consecutive_high=0
        else
            consecutive_high=0
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# 启动监控
monitor_memory &