#!/bin/bash

# 设置镜像名称和标签
IMAGE_NAME="scum-server-image"
TAG="v2.0-optimized"
FULL_NAME="${IMAGE_NAME}:${TAG}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统内存
check_system_memory() {
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    print_status "检测到系统内存: ${mem_total}MB"
    
    if [ $mem_total -lt 8192 ]; then
        print_warning "系统内存少于8GB，建议至少16GB内存用于运行SCUM服务器"
        RECOMMENDED_MEMORY="6g"
        RECOMMENDED_SWAP="8g"
    elif [ $mem_total -lt 16384 ]; then
        print_status "系统内存适中，推荐配置适用于小型服务器"
        RECOMMENDED_MEMORY="12g"
        RECOMMENDED_SWAP="16g"
    else
        print_status "系统内存充足，推荐配置适用于大型服务器"
        RECOMMENDED_MEMORY="20g"
        RECOMMENDED_SWAP="24g"
    fi
}

# 构建镜像
build_image() {
    print_status "构建Docker镜像: ${FULL_NAME}"
    
    if sudo docker build -t "${FULL_NAME}" .; then
        print_status "镜像构建成功！"
        return 0
    else
        print_error "Docker构建失败"
        return 1
    fi
}

# 显示运行命令
show_run_commands() {
    print_status "推荐的Docker运行命令:"
    
    echo ""
    echo "=== 基础运行命令 ==="
    cat << EOF
docker run -d \\
  --name scum-server \\
  --restart unless-stopped \\
  -p 7777:7777/udp -p 7777:7777/tcp \\
  -p 27015:27015/udp -p 27015:27015/tcp \\
  --memory=${RECOMMENDED_MEMORY} \\
  --memory-swap=${RECOMMENDED_SWAP} \\
  --oom-kill-disable=false \\
  --memory-swappiness=10 \\
  -e MAX_PLAYERS=64 \\
  -v scum-data:/opt/scumserver \\
  ${FULL_NAME}
EOF

    echo ""
    echo "=== 高级运行命令（带性能监控）==="
    cat << EOF
docker run -d \\
  --name scum-server \\
  --restart unless-stopped \\
  -p 7777:7777/udp -p 7777:7777/tcp \\
  -p 27015:27015/udp -p 27015:27015/tcp \\
  --memory=${RECOMMENDED_MEMORY} \\
  --memory-swap=${RECOMMENDED_SWAP} \\
  --oom-kill-disable=false \\
  --memory-swappiness=10 \\
  --cpus="4.0" \\
  --ulimit nofile=65536:65536 \\
  -e MAX_PLAYERS=64 \\
  -e MEMORY_LIMIT=${RECOMMENDED_MEMORY} \\
  -v scum-data:/opt/scumserver \\
  -v scum-logs:/opt/scumserver/logs \\
  ${FULL_NAME}
EOF

    echo ""
    echo "=== 容器管理命令 ==="
    echo "查看日志: docker logs -f scum-server"
    echo "查看内存使用: docker exec scum-server cat /opt/scumserver/logs/memory.log"
    echo "进入容器: docker exec -it scum-server bash"
    echo "重启服务器: docker restart scum-server"
    echo "停止服务器: docker stop scum-server"
}

# 测试功能
test_container() {
    print_status "启动测试容器..."
    
    local test_name="scum-server-test"
    
    # 清理可能存在的测试容器
    docker rm -f $test_name 2>/dev/null || true
    
    # 启动测试容器
    docker run -d \
        --name $test_name \
        --memory=8g \
        --memory-swap=10g \
        -p 17777:7777/udp \
        -p 17777:7777/tcp \
        -p 17015:27015/udp \
        -p 17015:27015/tcp \
        -e MAX_PLAYERS=16 \
        $FULL_NAME
    
    if [ $? -eq 0 ]; then
        print_status "测试容器已启动，等待初始化..."
        sleep 30
        
        # 检查容器状态
        if docker ps | grep -q $test_name; then
            print_status "✅ 测试成功！容器运行正常"
            print_status "测试端口: 17777 (游戏), 17015 (查询)"
            
            # 显示内存使用情况
            sleep 10
            local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" $test_name)
            print_status "当前内存使用: $mem_usage"
        else
            print_error "❌ 测试失败：容器无法正常启动"
            docker logs $test_name
        fi
        
        # 清理测试容器
        print_status "清理测试容器..."
        docker rm -f $test_name
    else
        print_error "测试容器启动失败"
        return 1
    fi
}

# 主流程
main() {
    print_status "SCUM Docker服务器构建脚本 v2.0"
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装"
        exit 1
    fi
    
    # 检查Docker守护进程
    if ! sudo docker info >/dev/null 2>&1; then
        print_error "Docker守护进程未启动"
        exit 1
    fi
    
    # 检查必要文件
    if [ ! -f "steamcmd_linux.tar.gz" ]; then
        print_error "steamcmd_linux.tar.gz 文件未找到"
        print_status "请从 https://steamcdn-a.akamaihd.net/client/steamcmd_linux.tar.gz 下载"
        exit 1
    fi
    
    # 检查系统内存
    check_system_memory
    
    # 构建镜像
    if build_image; then
        print_status "构建完成！"
        
        # 显示运行命令
        show_run_commands
        
        # 询问是否运行测试
        echo ""
        read -p "是否运行容器测试？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            test_container
        fi
    else
        exit 1
    fi
}

# 运行主函数
main "$@"