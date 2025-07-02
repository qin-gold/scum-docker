# SCUM Docker Server (优化版 v2.0)

本项目提供了一个经过内存优化的SCUM游戏服务器Docker解决方案，专门解决了OOM（内存不足）问题。

## 🎯 主要改进

### OOM问题修复
- ✅ **内存监控系统**: 实时监控内存使用率，自动清理和重启
- ✅ **jemalloc内存分配器**: 更高效的内存管理
- ✅ **Wine内存优化**: 针对Wine环境的内存配置优化
- ✅ **服务器参数优化**: 低内存模式和性能优化参数
- ✅ **智能资源管理**: 根据系统内存自动调整配置

### 系统要求
- **最低内存**: 8GB RAM
- **推荐内存**: 16GB+ RAM
- **磁盘空间**: 至少20GB可用空间
- **操作系统**: Linux (测试环境: Ubuntu 22.04)

## 📁 项目结构
```
├── Dockerfile              # 优化后的镜像构建文件
├── build-image.sh          # 智能构建脚本
├── entrypoint.sh           # 优化的启动脚本
├── memory-monitor.sh       # 内存监控和OOM预防
├── healthcheck.sh          # 增强的健康检查
├── steamcmd_linux.tar.gz   # SteamCMD安装包（需手动下载）
└── README.md               # 本文档
```

## 🚀 快速开始

### 1. 准备环境
```bash
# 下载SteamCMD（如果没有）
wget https://steamcdn-a.akamaihd.net/client/steamcmd_linux.tar.gz
```

### 2. 构建镜像
```bash
# 使用智能构建脚本
chmod +x build-image.sh
./build-image.sh
```

构建脚本会自动：
- 检测系统内存配置
- 提供推荐的运行参数
- 可选择运行测试容器

### 3. 运行服务器

#### 基础运行（推荐）
```bash
docker run -d \
  --name scum-server \
  --restart unless-stopped \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 27015:27015/udp -p 27015:27015/tcp \
  --memory=16g \
  --memory-swap=20g \
  --oom-kill-disable=false \
  --memory-swappiness=10 \
  -e MAX_PLAYERS=64 \
  -v scum-data:/opt/scumserver \
  scum-server-image:v2.0-optimized
```

#### 高性能配置
```bash
docker run -d \
  --name scum-server \
  --restart unless-stopped \
  -p 7777:7777/udp -p 7777:7777/tcp \
  -p 27015:27015/udp -p 27015:27015/tcp \
  --memory=20g \
  --memory-swap=24g \
  --oom-kill-disable=false \
  --memory-swappiness=10 \
  --cpus="4.0" \
  --ulimit nofile=65536:65536 \
  -e MAX_PLAYERS=64 \
  -e MEMORY_LIMIT=20g \
  -v scum-data:/opt/scumserver \
  -v scum-logs:/opt/scumserver/logs \
  scum-server-image:v2.0-optimized
```

## 🔧 配置参数

### 环境变量
- `MAX_PLAYERS`: 最大玩家数（默认：64）
- `SERVER_PORT`: 游戏端口（默认：7777）
- `QUERY_PORT`: 查询端口（默认：27015）
- `MEMORY_LIMIT`: 内存限制（默认：16g）

### Docker参数说明
- `--memory`: 容器内存限制
- `--memory-swap`: 总内存限制（包括swap）
- `--memory-swappiness`: swap使用倾向（0-100）
- `--oom-kill-disable=false`: 允许OOM killer（推荐）
- `--cpus`: CPU核心限制

## 📊 监控和维护

### 查看日志
```bash
# 服务器日志
docker logs -f scum-server

# 内存监控日志
docker exec scum-server cat /opt/scumserver/logs/memory.log

# 健康检查日志
docker exec scum-server cat /opt/scumserver/logs/health.log
```

### 内存监控
系统会自动监控内存使用情况：
- **90%**: 警告阈值，执行内存清理
- **95%**: 危险阈值，自动重启服务器
- 每30秒记录一次内存状态

### 容器管理
```bash
# 重启服务器
docker restart scum-server

# 进入容器调试
docker exec -it scum-server bash

# 查看容器资源使用
docker stats scum-server

# 停止服务器
docker stop scum-server
```

## 🛠️ 故障排除

### 常见OOM问题
1. **内存不足**: 确保系统有足够的可用内存
2. **swap配置**: 建议配置适当的swap空间
3. **容器限制**: 检查Docker内存限制设置

### 优化建议
1. **系统级优化**:
   ```bash
   # 增加swap空间
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   
   # 优化内核参数
   echo 'vm.swappiness=10' >> /etc/sysctl.conf
   echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
   sysctl -p
   ```

2. **Docker优化**:
   ```bash
   # 清理Docker缓存
   docker system prune -a
   
   # 优化Docker守护进程
   echo '{"storage-driver": "overlay2", "log-opts": {"max-size": "10m", "max-file": "3"}}' > /etc/docker/daemon.json
   ```

## 🔒 安全注意事项
- 默认配置仅适用于内网环境
- 生产环境请配置防火墙规则
- 定期备份游戏数据
- 监控容器资源使用情况

## 📈 性能基准
| 内存配置 | 推荐玩家数 | 平均内存使用 | 启动时间 |
|----------|------------|--------------|----------|
| 8GB      | 32         | ~6GB         | 3-5分钟  |
| 16GB     | 64         | ~12GB        | 2-3分钟  |
| 32GB     | 100+       | ~20GB        | 1-2分钟  |

## 📝 更新日志

### v2.0-optimized
- 🔧 修复OOM问题
- 📊 添加内存监控系统
- ⚡ 性能优化和参数调优
- 🛡️ 增强健康检查
- 📱 智能构建脚本

### v1.0
- 基础Docker化SCUM服务器

## 📄 许可证
本项目仅供学习和个人使用。SCUM游戏版权归原开发商所有。 