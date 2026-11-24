# ECSRelay 加载项仓库（公网镜像）

这个仓库只做一件事：让 Home Assistant 的 Supervisor 能匿名拉到一个**可安装的加载项定义**。

主仓库 `AwesomeSky/ECSRelay` 是私有的，Supervisor 不会带凭据去 clone，所以这里放一份
`ecsrelay/` 的镜像（配置 + Dockerfile + 预编译二进制）。

- 本地加载项走 **Web UI 按钮**进入配对页，**不加侧边栏面板**（`webui` + 端口映射，没有 `ingress`）。
- 二进制是交叉编译好的 linux/amd64 与 linux/aarch64，Supervisor 构建时不需要 Go 工具链。

## 安装

1. 设置 → 加载项 → 加载项商店 → 右上 ⋮ →「仓库」
2. 填入 `https://github.com/AwesomeSky/ecsrelay-addon`
3. 回到商店 → **ECSRelay Tunnel** → 安装

## 配置

| 选项 | 说明 |
| --- | --- |
| `relay` | 公网 relay 地址，形如 `1.2.3.4:28443` |
| `pin` | relay 证书 pin（64 位 hex，`ecsrelay pinof` 得到） |
| `token` | 共享令牌，与 relay 房间的 `token` 一致 |
| `room` | 房间名，默认 `home` |
| `target` | HA 的实际监听地址，默认 `homeassistant:80` |
| `pairPin` | 配对页口令；留空则每次启动随机生成并打在日志里 |

启动日志里有两行值得看：

```
agent: 设备库 /data/devices.json（已配对 0 台，待首连 0 台）
agent: 目标自检 homeassistant:80 → HTTP 200
```

「目标自检」失败会直接提示改 `homeassistant:8123` 或 `172.16.11.196:80`。

## 配对手机

1. 加载项页面点 **OPEN WEB UI**（没有侧边栏入口）
2. 输入日志里的 6 位配对口令
3. 填设备名 → 生成二维码
4. 手机 HA App → 添加服务器 → 手动输入 → 设置中继隧道 → 扫码

## 同步来源

内容来自主仓库的 `addon/` 目录。改了那边之后：

```bash
bash scripts/build-addon.sh          # 重新交叉编译到 addon/bin/
# 然后把这几个文件同步到本仓库的 ecsrelay/
```

版本号在 `ecsrelay/config.yaml` 的 `version` 里，改了就重新提交。