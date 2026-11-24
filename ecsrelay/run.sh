#!/usr/bin/env bash
# HAOS 加载项入口：把 Supervisor 注入的 /data/options.json 翻译成 ecsrelay agent 的命令行。
set -euo pipefail

OPTIONS=/data/options.json
if [[ ! -f "$OPTIONS" ]]; then
  echo "缺少 $OPTIONS，无法读取加载项配置" >&2
  exit 1
fi

RELAY=$(jq -r '.relay // ""' "$OPTIONS")
PIN=$(jq -r '.pin // ""' "$OPTIONS")
TOKEN=$(jq -r '.token // ""' "$OPTIONS")
ROOM=$(jq -r '.room // "home"' "$OPTIONS")
TARGET=$(jq -r '.target // "homeassistant:80"' "$OPTIONS")
PAIR_PIN=$(jq -r '.pairPin // ""' "$OPTIONS")

fail() { echo "配置错误：$1" >&2; exit 1; }
[[ -n "$RELAY" ]] || fail "relay 地址没填（形如 1.2.3.4:28443）"
[[ -n "$PIN"   ]] || fail "证书 pin 没填（用 ecsrelay pinof 算，64 位 hex）"
[[ -n "$TOKEN" ]] || fail "共享令牌没填（与 relay 的房间令牌一致）"

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
echo "配对页：打开 Web UI 后输入上面的口令；日志里不会出现设备令牌。"

exec /usr/bin/ecsrelay agent \
  -relay "$RELAY" \
  -pin "$PIN" \
  -token-file /data/relay-token \
  -room "$ROOM" \
  -target "$TARGET" \
  -device-store /data/devices.json \
  -pair-addr 0.0.0.0:28445 \
  -pair-pin "$PAIR_PIN"