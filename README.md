# MyFrpc

生产级 frp 客户端（frpc）配置参考仓库。内网服务经 frpc 内网穿透到服务器后，由服务器上的 frps 统一接收隧道连接、按 `allowPorts` 放行映射端口，再交给 nginx（或直接对外）提供服务。

本仓库按分支组织；本分支（`MyFrpc`）只包含 frpc 配置。

仓库的交付物是**配置与文档**：没有应用代码、没有包管理器、没有构建步骤。每条指令前的中文注释都是交付内容的一部分——它写清了作用域、默认值，以及取这个值的理由。

## 它解决什么问题

- **内网服务不需要公网入口**：客户端机器不开放任何入站端口；内网服务由 frpc 主动外连，服务器上只多出一个映射端口。
- **隧道加密与鉴权统一**：`transport.tls.enable = true` 与服务端的 `transport.tls.force = true` 配对（服务端自动随机生成证书，无需自备），`auth.token` 配合 `auth.additionalScopes` 让客户端逐连接校验。
- **映射集中在客户端一处**：每条 `[[proxies]]` 一条映射，`name` 必须全局唯一，`user` 会让代理名带上 `{user}.` 前缀，便于服务端按客户端归类。
- **一处配置管全局**：连接、加密、鉴权、Admin UI、日志、传输层都在 `frpc.toml`；容器网络、挂载与日志轮转在 `docker-compose.yml`。
- **可观测**：本地 Admin UI（默认只监听回环）能看到本客户端已注册的代理；文件日志与容器 stdout 两路并行。

## 流量路径

```text
访客 ──HTTPS──> nginx（服务器 80/443）──> 127.0.0.1:<frp 映射端口> ──> frps ──TLS 隧道──> frpc ──> 内网服务
```

本分支只提供隧道的客户端这一端：客户端只需能出站访问 **7000**（`serverPort`）；映射出来的端口是否对 nginx 可见，由服务端的 `proxyBindAddr` 决定。

## 快速开始

### 1. 客户端准备

- Docker 与 Docker Compose
- 能出站访问服务器的 7000 端口（`serverPort`）：容器使用 `network_mode: host`，frpc 直接使用宿主机网络栈，代理里的 `localIP = "127.0.0.1"` 指的就是这台机器
- 客户端本身不需要放行任何入站端口（只有改用 KCP / QUIC 时才涉及对应 UDP 端口）

### 2. 获取配置

```bash
git clone -b MyFrpc https://github.com/VaillerTeeter/MyServerConfig.git
cd MyServerConfig
```

本分支没有子模块，不需要 `git submodule update`。

### 3. 替换占位值

`frpc.toml` 里的每个值都是示例值，至少改这几处：

| 位置 | 示例值 | 改成 |
| --- | --- | --- |
| `serverAddr` | `"xxx.xxx.xxx.xxx"` | 服务器的域名或 IP |
| `auth.token` | `"12345678"` | 一段随机字符串，例如 `openssl rand -hex 32`，且必须与服务端完全一致 |
| `webServer.user` / `webServer.password` | `"admin"` / `"admin"` | 强口令（Admin UI 能管理本客户端的全部代理） |
| `user` | `"your_name"` | 自己的客户端标识，会成为代理名前缀 |
| `[[proxies]]` 的 `localPort` / `remotePort` | `7400` / `7400` | 本地服务端口 / 服务端放行的端口（必须落在服务端 `allowPorts` 内） |

> 改完记得遵守格式约定：缩进 2 个空格，多行数组的尾元素要带逗号 —— `toml-lint` 会逐字节比对，细节见 [ci-checks.md](.github/docs/ci/ci-checks.md) 的「TOML 配置检查」一节。

### 4. 启动与验证

```bash
docker compose up -d
docker compose logs -f frpc                                   # 看启动过程
docker compose exec frpc frpc verify -c /etc/frp/frpc.toml    # 校验配置能否解析
```

Admin UI 在 `http://127.0.0.1:7400`（只监听回环，可经 SSH 隧道访问）：能看到本客户端已注册的代理；本仓示例代理把它映射到服务端的 7400。

## 与服务端的配套

frpc 只是一半，另一半在 `MyFrps` 分支的 `frps.toml`。两边必须一致的项：

| frps.toml | 与 `frpc.toml` 的关系 |
| --- | --- |
| `bindPort` | 客户端的 `serverPort` 必须与它一致 |
| `auth.token` | 必须与客户端的 `auth.token` 完全相同，否则鉴权失败 |
| `transport.tls.force` | 取 `true`；客户端的 `transport.tls.enable` 从 v0.50.0 起默认就是 `true`，保持开启即可 |
| `kcpBindPort` / `quicBindPort` | 服务端没打开时，客户端只能用默认的 `transport.protocol = "tcp"` |
| `allowPorts` | 各代理的 `remotePort` 必须落在它放行的范围内，否则服务端会拒绝注册 |
| `transport.tls.certFile` / `keyFile` | 想让 frpc 校验服务端身份时才需要，配合客户端的 `transport.tls.trustedCaFile` 使用 |

## 新增一个映射

1. 在 `[[proxies]]` 下新增一条（TCP 类型，写 `localIP` / `localPort` / `remotePort`），`name` 必须全局唯一；
2. `remotePort` 必须落在服务端 `allowPorts` 之内，否则注册失败；
3. 若该端口要给服务端 nginx 反代，确认服务端的 `proxyBindAddr` 让它可见（默认 `0.0.0.0` 已足够）；
4. 让 frpc 重新加载；**服务端侧通常无需改** —— 除非要放行新端口，那就先改服务端的 `allowPorts` 再重启它。

> frpc 支持热加载（frps 没有）：改完 `frpc.toml` 用 `docker compose exec frpc frpc reload -c /etc/frp/frpc.toml`（或 `up -d`）生效。

## 想改某项行为时去哪里

| 想改什么 | 去哪里改 |
| --- | --- |
| 服务端地址与端口、隧道加密（`transport.tls`）、鉴权、Admin UI、日志 | `frpc.toml`（分段见文件内注释） |
| 本地服务到服务端端口的映射（`localIP` / `localPort` / `remotePort`） | `frpc.toml` 的 `[[proxies]]` |
| 容器网络、挂载、日志轮转、停机宽限、文件描述符上限、时区 | `docker-compose.yml` |
| 服务端侧的对应项（`bindPort`、`allowPorts`、`transport.tls.force`） | `MyFrps` 分支的 `frps.toml` |
| CI 检查规则与各类排除策略 | [ci-checks.md](.github/docs/ci/ci-checks.md) |

## 必须知道的几条约定

- **占位符都是假的**：`serverAddr = "xxx.xxx.xxx.xxx"`、`user = "your_name"`、`auth.token = "12345678"`、`webServer.user` / `webServer.password = "admin"`、端口用 `7000` / `7400` —— 都是示例值，部署前必须替换。仓库里不放任何真实域名、IP、端口或凭据。
- **容器内路径是刻意的**：`/etc/frp/frpc.toml` 与 `/etc/frp/log/frpc.log` 对应镜像内的布局与 `docker-compose.yml` 的挂载，不要改成宿主机路径。
- **注释即交付物**：每条指令都写清作用域、默认值与取值理由，不要删减或翻译这些注释。
- **TLS 只保护隧道**：`transport.tls` 加密的是 frpc ↔ frps 这一段，与 nginx 的**站点证书互不相干**；不配证书时服务端会自己随机生成一张（每次启动都不同，客户端默认也不校验它）。
- **Admin UI 默认只监听回环**：`webServer.addr = "127.0.0.1"`，需要时用 SSH 隧道访问；本仓示例代理把它映射到服务端，想开放就先换掉弱口令，并考虑再加一层 HTTPS。
- **改完即生效**：frpc 支持热加载，`docker compose exec frpc frpc reload -c /etc/frp/frpc.toml` 即可，不必重启容器；frps 则没有热加载。
- **日志分两路**：容器 stdout 的日志由 Compose 轮转（`max-size`、`max-file`）；`./logs/frpc.log` 是宿主机上的真实文件，需要自己在宿主机上配置 logrotate。
- **格式受 CI 约束**：`frpc.toml` 必须符合 taplo 规则（2 空格缩进），`toml-lint` 会逐字节比对；命名与空白另由 `ls-lint` 与 `editorconfig-checker` 把关。
