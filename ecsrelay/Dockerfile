ARG BUILD_FROM
FROM ${BUILD_FROM}

# bash: run.sh 用；jq: 读 Supervisor 注入的 /data/options.json
RUN apk add --no-cache bash jq ca-certificates

# 预编译好的 linux 二进制（由 scripts/build-addon.sh 产出）。
# 不在这里编译：HAOS 里现场 go build 要拉整套工具链和模块，既慢又依赖外网。
ARG BUILD_ARCH
COPY bin/ecsrelay-${BUILD_ARCH} /usr/bin/ecsrelay
RUN chmod +x /usr/bin/ecsrelay

COPY run.sh /run.sh
RUN chmod +x /run.sh

# 把版本写进镜像标签。
#
# HA 构建镜像时会传 --build-arg BUILD_VERSION=<加载项版本>，但这里原来没有
# ARG 接收，于是构建日志里出现 "[Warning] One or more build-args
# [BUILD_VERSION] were not consumed"，镜像本身也没有任何版本痕迹——
# `docker inspect` 看不出版本，只能进容器跑 `ecsrelay version`。
ARG BUILD_VERSION=dev
LABEL \
  io.hass.version="${BUILD_VERSION}" \
  io.hass.type="addon" \
  io.hass.name="ECSRelay Tunnel" \
  io.hass.description="反向隧道 agent —— 让 Home Assistant 在没有端口映射的情况下也能从外网访问"

CMD [ "/run.sh" ]