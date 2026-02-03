# 多阶段构建 - 支持 AMD64 和 ARM64
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

WORKDIR /app

# 安装构建依赖
RUN apk add --no-cache git ca-certificates tzdata

# 克隆源代码（使用官方仓库）
RUN git clone --depth 1 https://github.com/luler/model_auto_switch.git .

# 下载依赖
RUN go mod download

# 构建参数
ARG TARGETOS
ARG TARGETARCH
ARG BUILD_DATE
ARG VCS_REF

# 构建二进制文件（静态链接，无 CGO）
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -ldflags="-s -w \
    -X main.buildDate=${BUILD_DATE} \
    -X main.gitCommit=${VCS_REF}" \
    -o model_auto_switch .

# 运行阶段 - 使用最小化基础镜像
FROM --platform=$TARGETPLATFORM alpine:3.19

WORKDIR /app

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata curl && \
    adduser -D -s /bin/sh appuser

# 从构建阶段复制二进制文件
COPY --from=builder /app/model_auto_switch .

# 创建必要的目录并设置权限
RUN mkdir -p /app/app/appconfig /app/runtime && \
    chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/v1/models || exit 1

# 设置环境变量
ENV TZ=Asia/Shanghai \
    PORT=3000 \
    GIN_MODE=release

# 启动命令
ENTRYPOINT ["./model_auto_switch"]
