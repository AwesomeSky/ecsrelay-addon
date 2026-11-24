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

CMD [ "/run.sh" ]