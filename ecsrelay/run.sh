#!/usr/bin/env bash
# HAOS 加载项入口：把 Supervisor 注入的 /data/options.json 翻译成 ecsrelay agent 的命令行。
set -euo pipefail

OPTIONS=/data/options.json
if [[ ! -f "$OPTIONS" ]]; then
  echo "缺少 $OPTIONS，无法读取加载项配置" >&2
  exit 1
fi

opt() { jq -r --arg k "$1" '.[$k] // ""' "$OPTIONS"; }

RELAY=$(opt relay)
PIN=$(opt pin)
RELAY_PUBLIC=$(opt relayPublic)
PIN_PUBLIC=$(opt pinPublic)
TOKEN=$(opt token)
ROOM=$(opt room)
TARGET=$(opt target)
PAIR_PIN=$(opt pairPin)

[[ -n "$ROOM"   ]] || ROOM=home
[[ -n "$TARGET" ]] || TARGET=homeassistant:80

fail() { echo "配置错误：$1" >&2; exit 1; }
[[ -n "$RELAY" ]] || fail "内网 relay 地址没填（形如 172.16.11.150:28443）"
[[ -n "$PIN"   ]] || fail "内网 relay 证书 pin 没填（ecsrelay pinof 得到，64 位 hex）"
[[ -n "$TOKEN" ]] || fail "房间共享令牌没填（与 relay 上该房间的 token 一致）"
if [[ -n "$RELAY_PUBLIC" && -z "$PIN_PUBLIC" ]]; then
  fail "填了公网 relay 地址但没填它的 pin"
fi

# 共享令牌落到 0600 的文件里，再用 -token-file 传入：
# 命令行参数会出现在容器内的 ps 输出里，没必要冒这个险。
umask 077
printf '%s' "$TOKEN" > /data/relay-token
umask 022

# 配对页口令：没填就每次启动随机生成一个，只打在日志里（只有管理员看得到）。
if [[ -z "$PAIR_PIN" ]]; then
  PAIR_PIN=$(tr -dc '0-9' </dev/urandom | head -c 6 || true)
  echo "本次启动随机生成配对口令：$PAIR_PIN"
fi

# 端点：内网 relay 走 -lan（优先级 0，在家直接走局域网）；
# 配了公网才加 -relay 并开 -connect-all，让两个 relay 同时都有 agent 在线
# （否则 agent 在家时占着内网 relay，人在外面时公网 relay 上没有 agent，反而连不上）。
PINS="$PIN"
ENDPOINTS=(-lan "$RELAY")
if [[ -n "$RELAY_PUBLIC" ]]; then
  PINS="$PIN,$PIN_PUBLIC"
  ENDPOINTS+=(-relay "$RELAY_PUBLIC" -connect-all)
fi

echo "端点：$RELAY${RELAY_PUBLIC:+ + $RELAY_PUBLIC}  目标：$TARGET  房间：$ROOM"
echo "配对页：打开 Web UI 后输入上面的口令；日志里不会出现设备令牌。"

exec /usr/bin/ecsrelay agent \
  "${ENDPOINTS[@]}" \
  -pin "$PINS" \
  -token-file /data/relay-token \
  -room "$ROOM" \
  -target "$TARGET" \
  -device-store /data/devices.json \
  -pair-addr 0.0.0.0:28445 \
  -pair-pin "$PAIR_PIN"