# 第一阶段：构建环境
FROM ubuntu:22.04 AS builder

# 安装构建工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        make \
        gcc \
        g++ \
        bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载并编译 jemalloc
RUN wget https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2 && \
    tar -xjf jemalloc-5.3.0.tar.bz2 && \
    cd jemalloc-5.3.0 && \
    ./configure --prefix=/opt/jemalloc && \
    make && \
    make install && \
    cd .. && \
    rm -rf jemalloc-5.3.0*

# 第二阶段：运行时环境
FROM ubuntu:22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    WINEDEBUG=-all \
    WINEARCH=win64 \
    WINEPREFIX=/opt/wine64 \
    SCUM_HOME=/opt/scumserver \
    SERVER_PORT=7777 \
    QUERY_PORT=27015 \
    MEMORY_LIMIT=16g \
    MAX_PLAYERS=64

# 安装依赖项
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wine wine64 wine32 \
        winbind \
        xvfb \
        curl \
        jq \
        net-tools \
        psmisc \
        procps \
        htop \
        libsdl2-2.0-0:i386 \
        libopenal1:i386 \
        libpng16-16:i386 \
        libfreetype6:i386 \
        libjson-c5:i386 \
        libvulkan1 \
        cgroup-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 SteamCMD
COPY steamcmd_linux.tar.gz /opt/steamcmd/
RUN cd /opt/steamcmd && tar zxvf steamcmd_linux.tar.gz && rm steamcmd_linux.tar.gz

# 从构建阶段复制 jemalloc
COPY --from=builder /opt/jemalloc /opt/jemalloc

# 设置工作目录
WORKDIR /opt

# 复制所有脚本和配置文件
COPY entrypoint.sh /opt/entrypoint.sh
COPY healthcheck.sh /opt/healthcheck.sh
COPY memory-monitor.sh /opt/memory-monitor.sh

# 设置权限
RUN chmod +x /opt/*.sh && \
    mkdir -p /opt/scumserver /opt/scumserver/logs && \
    useradd -m scumuser && \
    chown -R scumuser:scumuser /opt/scumserver

# 配置Wine注册表以优化内存使用
RUN echo '[HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]' > /tmp/wine_memory.reg && \
    echo '"*d3d11"="native,builtin"' >> /tmp/wine_memory.reg && \
    echo '"*dxgi"="native,builtin"' >> /tmp/wine_memory.reg && \
    echo '[HKEY_CURRENT_USER\\Software\\Wine\\Direct3D]' >> /tmp/wine_memory.reg && \
    echo '"VideoMemorySize"="4096"' >> /tmp/wine_memory.reg && \
    echo '"MaxVersionGL"=dword:00040006' >> /tmp/wine_memory.reg

# 暴露端口
EXPOSE ${SERVER_PORT}/udp ${SERVER_PORT}/tcp
EXPOSE ${QUERY_PORT}/udp ${QUERY_PORT}/tcp

# 健康检查
HEALTHCHECK --interval=2m --timeout=30s --retries=3 --start-period=10m \
    CMD /opt/healthcheck.sh

# 设置用户和入口点
USER scumuser
ENTRYPOINT ["/opt/entrypoint.sh"]