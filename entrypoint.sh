#!/bin/bash
set -e

echo "✅ Starting custom SCUM server v1.0"

# 初始化 Wine
if [ ! -d "$WINEPREFIX" ]; then
    echo "⏳ Initializing Wine for the first time..."
    wineboot --init && sleep 5
fi

# 更新/安装 SCUM 服务端
echo "📥 Installing/updating SCUM Dedicated Server..."
/opt/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows \
    +login anonymous \
    +force_install_dir "$SCUM_HOME" \
    +app_update 3792580 validate \
    +quit

# 设置内存优化
export LD_PRELOAD="/opt/jemalloc/lib/libjemalloc.so.2"
export MALLOC_CONF="background_thread:true,metadata_thp:auto"

# 优雅关闭处理
cleanup() {
    echo "🛑 Received termination signal, stopping SCUM Server..."
    pkill -P $$  # 终止所有子进程
    sleep 15      # 给PhysX时间释放资源
    exit 0
}
trap cleanup SIGTERM SIGINT

# 内存监控
monitor_memory() {
    while true; do
        # 每30秒记录一次内存使用
        free -m | grep Mem | awk -v date="$(date '+%Y-%m-%d %H:%M:%S')" \
            '{print date, "MEMSTAT: Total:"$2"MB Used:"$3"MB Free:"$4"MB Available:"$7"MB"}' \
            >> "$SCUM_HOME/logs/memory.log"
        sleep 30
    done
}
monitor_memory &

# 启动服务端
echo "🚀 Starting optimized SCUM Dedicated Server..."
cd "$SCUM_HOME"
exec xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
    wine64 "$SCUM_HOME/SCUM/Binaries/Win64/SCUMServer.exe" \
        -log \
        -port="$SERVER_PORT" \
        -QueryPort="$QUERY_PORT" \
        -malloc=system \
        -lowmemory \
        -nomansky \
        -nohmd \
        -d3d10 \
        -sm4