#!/bin/bash
set -e

echo "✅ Starting optimized SCUM server v2.0"

# 设置内存优化环境变量
if [ -f "/opt/jemalloc/lib/libjemalloc.so.2" ]; then
    export LD_PRELOAD="/opt/jemalloc/lib/libjemalloc.so.2"
    export MALLOC_CONF="background_thread:true,metadata_thp:auto,dirty_decay_ms:10000,muzzy_decay_ms:10000"
    echo "✅ jemalloc内存分配器已启用"
else
    echo "⚠️ jemalloc未找到，使用系统默认内存分配器"
fi

# Wine 内存优化配置
export WINE_LARGE_ADDRESS_AWARE=1
export WINEDEBUG=-all,+heap

# 日志目录设置
LOGS_DIR="$SCUM_HOME/logs"
mkdir -p "$LOGS_DIR"

# 日志记录函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/server.log"
}

# 初始化 Wine
if [ ! -d "$WINEPREFIX" ]; then
    log_message "⏳ 初始化Wine环境..."
    wineboot --init
    
    # 应用Wine内存优化注册表设置
    if [ -f /tmp/wine_memory.reg ]; then
        log_message "🔧 应用Wine内存优化设置..."
        wine regedit /tmp/wine_memory.reg
    fi
    
    # 等待Wine完全初始化
    sleep 10
fi

# 更新/安装 SCUM 服务端
log_message "📥 检查/更新SCUM专用服务器..."
/opt/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows \
    +login anonymous \
    +force_install_dir "$SCUM_HOME" \
    +app_update 3792580 validate \
    +quit

# 检查服务器文件是否存在
if [ ! -f "$SCUM_HOME/SCUM/Binaries/Win64/SCUMServer.exe" ]; then
    log_message "❌ SCUM服务器文件未找到，退出..."
    exit 1
fi

# 优雅关闭处理
cleanup() {
    log_message "🛑 收到终止信号，正在停止SCUM服务器..."
    
    # 终止所有子进程
    pkill -P $$ 2>/dev/null || true
    
    # 等待PhysX和Wine清理资源
    sleep 20
    
    # 强制清理Wine进程
    wineserver -k 2>/dev/null || true
    
    log_message "✅ 服务器已安全关闭"
    exit 0
}
trap cleanup SIGTERM SIGINT

# 启动内存监控
log_message "🔍 启动内存监控系统..."
source /opt/memory-monitor.sh

# 系统资源检查
check_system_resources() {
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_available=$(free -m | awk 'NR==2{print $7}')
    
    log_message "系统资源检查 - 总内存: ${mem_total}MB, 可用内存: ${mem_available}MB"
    
    if [ $mem_available -lt 4096 ]; then
        log_message "⚠️ 警告：可用内存不足4GB，可能影响服务器性能"
    fi
}

check_system_resources

# 设置服务器配置参数
get_server_params() {
    local params=(
        "-log"
        "-port=$SERVER_PORT"
        "-QueryPort=$QUERY_PORT"
        "-MaxPlayers=$MAX_PLAYERS"
    )
    
    # 内存和性能优化参数
    params+=(
        "-malloc=system"           # 使用系统内存分配器
        "-lowmemory"              # 低内存模式
        "-nomansky"               # 禁用天空盒渲染
        "-nohmd"                  # 禁用VR支持
        "-d3d10"                  # 使用D3D10而不是D3D11
        "-sm4"                    # 使用Shader Model 4
        "-novsync"                # 禁用垂直同步
        "-notexturestreaming"     # 禁用纹理流
        "-nomemoryrestriction"    # 移除内存限制
    )
    
    # 如果内存较少，添加额外的优化参数
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    if [ $mem_total -lt 16384 ]; then
        params+=(
            "-NOTEXTURESTREAMING"
            "-reducedmemory"
            "-noai"
        )
        log_message "🔧 检测到内存较少，启用额外优化参数"
    fi
    
    echo "${params[@]}"
}

# 启动服务端
log_message "🚀 启动优化的SCUM专用服务器..."
log_message "内存分配器: jemalloc"
log_message "最大玩家数: $MAX_PLAYERS"
log_message "服务器端口: $SERVER_PORT"
log_message "查询端口: $QUERY_PORT"

cd "$SCUM_HOME"

# 设置Wine环境
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
XVFB_PID=$!

# 等待X服务器启动
sleep 3

# 启动服务器
exec wine64 "$SCUM_HOME/SCUM/Binaries/Win64/SCUMServer.exe" $(get_server_params)