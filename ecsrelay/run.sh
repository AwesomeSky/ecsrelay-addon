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

if [[ -z "$RELAY" && -z "$RELAY_PUBLIC" ]]; then
  fail "内网 relay 与公网 relay 至少填一个"
fi
if [[ -n "$RELAY" && -z "$PIN" ]]; then
  fail "填了内网 relay 地址但没填它的 pin（ecsrelay pinof 得到，64 位 hex）"
fi
if [[ -n "$RELAY_PUBLIC" && -z "$PIN_PUBLIC" ]]; then
  fail "填了公网 relay 地址但没填它的 pin"
fi
[[ -n "$TOKEN" ]] || fail "房间共享令牌没填（与 relay 上该房间的 token 一致）"

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

# 端点组合：
#   只填内网  → 单端点，在家用局域网
#   只填公网  → 单端点，任何地方都走 ECS（家里也是，延迟高一些但能通）
#   两个都填  → -connect-all，两个 relay 同时有 agent 在线
#               （否则 agent 在家时占着内网 relay，人在外面时公网 relay 上没有 agent，反而连不上）
# 每个端点只带**自己的** pin。
#
# 不要把两个 pin 合并成全局 -pin：那样内网 relay 的证书也能冒充公网入口
# （反之亦然），一个入口被攻破就等于两个都失守。
ENDPOINTS=()
if [[ -n "$RELAY" ]]; then
  ENDPOINTS+=(-lan "$RELAY" -lan-pin "$PIN")
fi
if [[ -n "$RELAY_PUBLIC" ]]; then
  ENDPOINTS+=(-relay "$RELAY_PUBLIC" -relay-pin "$PIN_PUBLIC")
  if [[ -n "$RELAY" ]]; then
    ENDPOINTS+=(-connect-all)
  fi
fi

echo "端点：${RELAY:-（无内网）}${RELAY_PUBLIC:+ + $RELAY_PUBLIC}  目标：$TARGET  房间：$ROOM"
echo "配对页：打开 Web UI 后输入上面的口令；日志里不会出现设备令牌。"

exec /usr/bin/ecsrelay agent \
  "${ENDPOINTS[@]}" \
  -token-file /data/relay-token \
  -room "$ROOM" \
  -target "$TARGET" \
  -device-store /data/devices.json \
  -pair-addr 0.0.0.0:28445 \
  -pair-pin "$PAIR_PIN"