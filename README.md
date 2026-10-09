# MyFrps

生产级 frp 服务端（frps）配置参考仓库。内网服务经 frpc 内网穿透到服务器后，由服务器上的 frps 统一接收隧道连接、按 `allowPorts` 放行映射端口，再交给 nginx（或直接对外）提供服务。

本仓库按分支组织；本分支（`MyFrps`）只包含 frps 配置。

仓库的交付物是**配置与文档**：没有应用代码、没有包管理器、没有构建步骤。每条指令前的中文注释都是交付内容的一部分——它写清了作用域、默认值，以及取这个值的理由。

## 它解决什么问题

- **公网入口收敛**：只有服务器暴露公网；内网服务由 frpc 主动外连，服务器上只多出一个回环端口。
- **隧道加密与鉴权统一**：`transport.tls.force = true` 拒绝明文隧道（frps 自动随机生成证书，无需自备），`auth.token` 配合 `additionalScopes` 让服务端逐连接校验。
- **端口准入收敛**：`allowPorts` 限定可被映射的端口，`maxPortsPerClient` 限制单客户端的代理数，避免客户端失控占满服务器端口。
- **一处配置管全局**：监听、加密、鉴权、Dashboard、日志、端口准入都在 `frps.toml`；容器网络、挂载与日志轮转在 `docker-compose.yml`。
- **可观测**：Dashboard（默认只监听回环）能看到所有隧道与客户端；文件日志与容器 stdout 两路并行。

## 流量路径

```text
访客 ──HTTPS──> nginx（服务器 80/443）──> 127.0.0.1:<frp 映射端口> ──> frps ──TLS 隧道──> frpc ──> 内网服务
```

公网只需放行 **7000**（`bindPort`，frpc 接入）与站点实际使用的端口（80/443 由 nginx 持有）；映射出来的端口默认绑在 `0.0.0.0`（`proxyBindAddr`），供 nginx 在回环上反代。

## 快速开始

### 1. 服务器准备

- Docker 与 Docker Compose
- `bindPort`（默认 7000）与 `allowPorts` 放行的端口可用：容器使用 `network_mode: host`，frps 直接使用宿主机网络栈
- 防火墙 / 安全组放行 TCP 7000 与映射端口（只有用到 KCP / QUIC 时才需放行对应 UDP 端口）

### 2. 获取配置

```bash
git clone -b MyFrps https://github.com/VaillerTeeter/MyServerConfig.git
cd MyServerConfig
```

本分支没有子模块，不需要 `git submodule update`。

### 3. 替换占位值

`frps.toml` 里的每个值都是示例值，至少改这几处：

| 位置 | 示例值 | 改成 |
| --- | --- | --- |
| `auth.token` | `"12345678"` | 一段随机字符串，例如 `openssl rand -hex 32` |
| `webServer.user` / `webServer.password` | `"admin"` / `"admin"` | 强口令（Dashboard 能管理所有隧道） |
| `allowPorts` | `{ single = 7501 }` | 自己的映射端口或区间，例如 `{ start = 7501, end = 7510 }` |
| `bindPort` | `7000` | 需要变更时，同步改 frpc 的 `serverPort` 与防火墙 |
| `vhostHTTPPort` / `vhostHTTPSPort` / `kcpBindPort` / `quicBindPort` | 注释（即禁用） | 按需解除注释；启用 vhost 时**务必避开 nginx 占用的 80/443** |

> 改完记得遵守格式约定：缩进 2 个空格、数组尾元素带逗号（`{ single = 7501 },`）—— `toml-lint` 会逐字节比对，细节见 [ci-checks.md](.github/docs/ci/ci-checks.md) 的「TOML 配置检查」一节。

### 4. 启动与验证

```bash
docker compose up -d
docker compose logs -f frps                                   # 看启动过程
docker compose exec frps frps verify -c /etc/frp/frps.toml    # 校验配置能否解析
```

Dashboard 在 `http://127.0.0.1:7500`（只监听回环，可经 SSH 隧道访问）：能看到在线客户端与已建立的代理。

## 与 frpc 的配套

frps 只是一半，另一半在 `MyFrpc` 分支的 `frpc.toml`。两边必须一致的项：

| frpc.toml | 与 `frps.toml` 的关系 |
| --- | --- |
| `serverAddr` / `serverPort` | 指向服务器地址与 `bindPort` |
| `auth.token` | 必须与 `auth.token` 完全相同，否则鉴权失败 |
| `transport.tls.enable` | 从 v0.50.0 起默认 `true`；本仓 `transport.tls.force = true` 要求它开着 |
| `transport.protocol` | 默认 `tcp`；只有 frps 打开了 `kcpBindPort` / `quicBindPort` 才改成 `kcp` / `quic` |
| 各代理的 `remote_port` | 必须落在 `allowPorts` 放行的范围内，否则 frps 会拒绝注册 |
| `transport.tls.trustedCaFile` | 想让 frpc 校验 frps 身份时才需要，配合 frps 的 `certFile` / `keyFile` 使用 |

## 新增一个映射

1. 在 frpc 侧新增一个代理（TCP 类型，写 `local_ip` / `local_port` / `remote_port`）；
2. `remote_port` 必须落在 frps 的 `allowPorts` 之内，否则注册失败；
3. 若该端口要给 nginx 反代，确认 `proxyBindAddr` 让它可见（默认 `0.0.0.0` 已足够）；
4. 让 frpc 重新加载；**frps 侧通常无需改** —— 除非要放行新端口，那就先改 `allowPorts` 再重启容器。

> frps 没有热加载：改完 `frps.toml` 用 `docker compose restart frps`（或 `up -d`）生效。

## 想改某项行为时去哪里

| 想改什么 | 去哪里改 |
| --- | --- |
| 监听地址与端口、隧道加密（`transport.tls`）、鉴权、Dashboard、日志 | `frps.toml`（分段见文件内注释） |
| 允许被映射的端口范围、单客户端代理数上限 | `frps.toml` 的 `allowPorts` 与 `maxPortsPerClient` |
| 容器网络、挂载、日志轮转、停机宽限、文件描述符上限、时区 | `docker-compose.yml` |
| 客户端侧的对应项（token、TLS、代理定义） | `MyFrpc` 分支的 `frpc.toml` |
| CI 检查规则与各类排除策略 | [ci-checks.md](.github/docs/ci/ci-checks.md) |

## 必须知道的几条约定

- **占位符都是假的**：`auth.token = "12345678"`、`webServer.user` / `webServer.password = "admin"`、端口用 `7000` / `7500` / `7501` —— 都是示例值，部署前必须替换。仓库里不放任何真实域名、IP、端口或凭据。
- **容器内路径是刻意的**：`/etc/frp/frps.toml` 与 `/etc/frp/log/frps.log` 对应镜像内的布局与 `docker-compose.yml` 的挂载，不要改成宿主机路径。
- **注释即交付物**：每条指令都写清作用域、默认值与取值理由，不要删减或翻译这些注释。
- **TLS 只保护隧道**：`transport.tls` 加密的是 frpc ↔ frps 这一段，与 nginx 的**站点证书互不相干**；不配证书时 frps 会自己随机生成一张（每次启动都不同，客户端默认也不校验它）。
- **Dashboard 默认只监听回环**：`webServer.addr = "127.0.0.1"`，需要时用 SSH 隧道访问；想开放到公网，先换掉弱口令，并考虑再加一层 HTTPS。
- **改完要重启**：frps 没有热加载，`docker compose restart frps` 后才生效。
- **日志分两路**：容器 stdout 的日志由 Compose 轮转（`max-size`、`max-file`）；`./logs/frps.log` 是宿主机上的真实文件，需要自己在宿主机上配置 logrotate。
- **格式受 CI 约束**：`frps.toml` 必须符合 taplo 规则（2 空格缩进、数组尾元素带逗号），`toml-lint` 会逐字节比对；命名与空白另由 `ls-lint` 与 `editorconfig-checker` 把关。
