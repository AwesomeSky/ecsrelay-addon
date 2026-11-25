# ECSRelay 加载项仓库

把本仓库当作 Home Assistant 的**加载项仓库**添加，即可安装 `ECSRelay Tunnel`。

## 添加到 Home Assistant

> 本仓库是**公开**的，直接添加即可，不需要任何 token 或凭据。

要填入的仓库地址：

```
https://github.com/AwesomeSky/ecsrelay-addon
```

> 更新方式：HA 会在加载项页面提示可更新版本；
> 安装后显示的版本号就是本仓库 `ecsrelay/config.yaml` 里的 `version`。

### 标准步骤

1. 设置 → 加载项 → 右下角「加载项商店」
2. 右上角 ⋮ →「仓库」→ 填入上面**实际可用**的地址
3. 回到商店，找到 **ECSRelay Tunnel** → 安装

> 本机调试时也可以把 `addon/` 目录复制到 HAOS 的 `/addons/ecsrelay/`，
> 然后在「加载项商店 → 本地加载项」里刷新即可（需要先跑一次 `scripts/build-addon.sh` 生成二进制）。
>
> ⚠ 这台 HA 的 **22 / 445 都不通**（没 SSH、没 Samba），所以从外部拷贝这条路走不通：
> 实际可行的只有上面「添加仓库 URL」，或者在 HA 里装一个 SSH/Terminal 加载项再往里拷。

## 配置项

| 选项 | 说明 | 示例 |
| --- | --- | --- |
| `relay` | 内网 relay 地址（在家走局域网） | `relay.lan:28443` |
| `pin` | 上面这个 relay 的证书 pin | `a1b2…`（64 位 hex） |
| `relayPublic` | 公网 relay 地址（可选，外出时用） | `1.2.3.4:28443` |
| `pinPublic` | 公网 relay 的证书 pin | `c3d4…` |
| `token` | 共享令牌，与 relay 房间的 `token` 一致 | `s3cr3t` |
| `room` | 房间名，需与 relay 配置一致 | `home` |
| `target` | **HA 的实际监听地址** | `homeassistant:80` |
| `pairPin` | 配对页口令；留空则每次启动随机生成并打在日志里 | `246810` |

**两个 pin 必须分别填**（`pin` / `pinPublic`）。这不是可选的讲究：
内网 relay 与公网 relay 是两张独立证书，若只填一个全局 pin，任一证书都能
冒充另一个入口——内网那台更容易被物理接近或从内网攻破，一旦失守公网入口
也会跟着失守。加载项会把它们分别传给 `-lan-pin` / `-relay-pin`。

`target` 是另一项容易填错的：

- 加载项网络内访问 Core 用服务名 → `homeassistant:80`（你这台 HA 的 `internal_url` 没有端口，就是 80）；
- 如果加载项里解析不通，改成宿主地址 `172.16.11.196:80`；
- 启动日志里有一行「目标自检」，会直接告诉你通没通。

## 配对一台手机

1. 打开「设置 → 加载项 → ECSRelay Tunnel」→ 点 **打开 Web UI**
   （页面通过 **ingress** 开在 HA 自己的界面里，没有侧边栏面板，也不用另开端口）；
2. 首次进入输入配对口令（加载项日志里那 6 位数字，或配置项里的 `pairPin`）；
3. 填设备名 →「生成配对二维码」；
4. 手机 HA App → 添加服务器 → 手动输入 → 设置中继隧道 → **用手机摄像头扫屏幕上的码**。

> 备选入口：ingress 走不通时可直接访问 `http://<HA地址>:28445/`（端口映射保留着）。
> 两个入口是同一套页面，路径用后缀匹配，所以 `/api/hassio_ingress/<token>/...` 也能正常路由。

二维码里带的是这台设备的长期令牌，**只在生成时出现一次**；签发后 5 分钟内没有第一次连接会自动作废。
删除设备用页面上的「吊销」（对应 `ecsrelay devices revoke`）。

## 安全边界

- 配对页**只**提供令牌签发，不含任何 HA 数据；`pairPin` 为空时服务端会拒绝启动（fail-closed）；
- **配对口令有错误次数限制**：同一来源 10 分钟内错 5 次即锁定 15 分钟，
  锁定期内即使口令正确也拒绝（口令只有 6 位数字，不限速可被枚举）；
- 设备库在 `/data/devices.json`，只存令牌的 SHA-256，0600；
- 共享令牌写在 `/data/relay-token`（0600），用 `-token-file` 传入，不出现在 `ps` 里；
- 加载项只做出站连接，不监听除配对页以外的任何端口。

## 已知限制

- 先在 `amd64` 上验证过；`aarch64` 的二进制同源产出但未实测。
- 配对页通过端口映射暴露在局域网上，请确保 `pairPin` 已设置（留空时是随机的）。

## 发布新版本（维护者）

改了 Go 代码后必须重新生成二进制，否则加载项里跑的还是旧版本：

```bash
# 1. 改 addon/config.yaml 的 version（Supervisor 按它判断升级）
# 2. 重新交叉编译（版本号自动取自上一步的 config.yaml）
bash scripts/build-addon.sh
# 3. 校验二进制确实包含当前源码的行为
bash scripts/check-addon-bin.sh
```

`check-addon-bin.sh` 已接入 `scripts/check.sh`，所以二进制过期会让质量门禁变红——
这正是为了避免「源码修了、加载项还在跑旧二进制」这类静默失效。
