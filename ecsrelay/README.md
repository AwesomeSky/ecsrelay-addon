# ECSRelay 加载项仓库

把本仓库当作 Home Assistant 的**加载项仓库**添加，即可安装 `ECSRelay Tunnel`。

## 添加到 Home Assistant

1. 设置 → 加载项 → 右下角「加载项商店」
2. 右上角 ⋮ →「仓库」→ 填入本仓库地址（例如 `https://github.com/AwesomeSky/ECSRelay`）
3. 回到商店，找到 **ECSRelay Tunnel** → 安装

> 本机调试时也可以把 `addon/` 目录复制到 HAOS 的 `/addons/ecsrelay/`，
> 然后在「加载项商店 → 本地加载项」里刷新即可（需要先跑一次 `scripts/build-addon.sh` 生成二进制）。
>
> ⚠ 这台 HA 的 **22 / 445 都不通**（没 SSH、没 Samba），所以从外部拷贝这条路走不通：
> 实际可行的只有上面「添加仓库 URL」，或者在 HA 里装一个 SSH/Terminal 加载项再往里拷。

## 配置项

| 选项 | 说明 | 示例 |
| --- | --- | --- |
| `relay` | 公网 relay 地址 | `1.2.3.4:28443` |
| `pin` | relay 证书 pin（`ecsrelay pinof` 得到） | `a1b2…`（64 位 hex） |
| `token` | 共享令牌，与 relay 房间的 `token` 一致 | `s3cr3t` |
| `room` | 房间名，需与 relay 配置一致 | `home` |
| `target` | **HA 的实际监听地址** | `homeassistant:80` |
| `pairPin` | 配对页口令；留空则每次启动随机生成并打在日志里 | `246810` |

`target` 是唯一容易填错的一项：

- 加载项网络内访问 Core 用服务名 → `homeassistant:80`（你这台 HA 的 `internal_url` 没有端口，就是 80）；
- 如果加载项里解析不通，改成宿主地址 `172.16.11.196:80`；
- 启动日志里有一行「目标自检」，会直接告诉你通没通。

## 配对一台手机

1. 打开「设置 → 加载项 → ECSRelay Tunnel」→ 点 **OPEN WEB UI**（没有侧边栏面板）；
2. 首次进入输入配对口令（加载项日志里那 6 位数字）；
3. 填设备名 →「生成配对二维码」；
4. 手机 HA App → 添加服务器 → 手动输入 → 设置中继隧道 → 扫码。

二维码里带的是这台设备的长期令牌，**只在生成时出现一次**；签发后 5 分钟内没有第一次连接会自动作废。
删除设备用页面上的「吊销」（对应 `ecsrelay devices revoke`）。

## 安全边界

- 配对页**只**提供令牌签发，不含任何 HA 数据；`pairPin` 为空时服务端会拒绝启动（fail-closed）；
- 设备库在 `/data/devices.json`，只存令牌的 SHA-256，0600；
- 共享令牌写在 `/data/relay-token`（0600），用 `-token-file` 传入，不出现在 `ps` 里；
- 加载项只做出站连接，不监听除配对页以外的任何端口。

## 已知限制

- 先在 `amd64` 上验证过；`aarch64` 的二进制同源产出但未实测。
- 配对页通过端口映射暴露在局域网上，请确保 `pairPin` 已设置（留空时是随机的）。