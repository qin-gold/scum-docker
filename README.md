# scum-docker

本项目用于构建和运行 SCUM 游戏服务器的 Docker 镜像，支持 Wine 运行环境和 SteamCMD 自动更新。

## 目录结构
- `Dockerfile`：镜像构建文件
- `build-image.sh`：构建镜像脚本
- `entrypoint.sh`：容器启动入口脚本
- `healthcheck.sh`：健康检查脚本
- `steamcmd_linux.tar.gz`：SteamCMD 安装包（需手动下载）

## 构建镜像

1. 确保已下载 `steamcmd_linux.tar.gz` 到项目根目录。
2. 构建镜像：
   ```sh
   docker build -t scum-server .
   ```

## 运行容器

```sh
docker run -d \
  --name scum-server \
  -p 7777:7777/udp \
  -p 7777:7777/tcp \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  scum-server
```

## 镜像加速建议
如遇到拉取镜像缓慢或失败，建议配置 Docker 国内镜像加速器。

## 注意事项
- 需提前准备好 `steamcmd_linux.tar.gz`，否则构建会失败。
- 运行环境基于 Ubuntu 22.04，包含 Wine 及多种 32 位依赖。

## 许可证
本项目仅供学习和个人使用。 