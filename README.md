# MyNginx

生产级 Nginx 配置参考仓库。本地服务（媒体库、网盘、博客等）经 frp 内网穿透到服务器后，由服务器的 nginx 统一终结 TLS、反向代理并对外提供 HTTPS 访问。

本仓库按分支组织；本分支（`MyNginx`）只包含 Nginx 配置。

仓库的交付物是**配置与文档**：没有应用代码、没有包管理器、没有构建步骤。每条指令前的中文注释都是交付内容的一部分——它写清了作用域、默认值，以及取这个值的理由。

## 它解决什么问题

- **公共入口只有一个**：只有 nginx 监听公网；本地服务经 frp 后只在服务器的回环地址上监听，公网无法直连。
- **HTTPS 与跳转统一**：80 端口一律 301 到 HTTPS；未被任何站点认领的域名直接断开连接（HTTP 444），HTTPS 则在 TLS 阶段拒握手。
- **公共能力集中一处**：压缩、安全头、超时、代理默认值、限流阈值、TLS 参数、统一错误页都写在全局配置里，站点只写自己的差异。
- **日志与排障统一**：全站一条访问日志，含上游耗时、缓存命中、限流结果、真实客户端 IP 等字段。

## 流量路径

```text
客户端 ──HTTPS──> nginx（服务器 80/443）──> 127.0.0.1:<frp 映射端口> ──> frpc ──> 本地服务
```

每个站点在服务器上只需要一个回环端口，公网只开放 80 与 443。

## 快速开始

### 1. 服务器准备

- Docker 与 Docker Compose
- 80、443 端口可用：容器使用 `network_mode: host`，nginx 直接使用宿主机网络栈
- 域名已解析到该服务器

### 2. 获取配置

```bash
git clone -b MyNginx https://github.com/VaillerTeeter/MyServerConfig.git
cd MyServerConfig
git submodule update --init --recursive
```

错误页素材放在 `conf.d/error` 子模块里，不拉取子模块时错误页会 404。

### 3. 放置证书

证书目录的约定是「一个域名一个目录」：

```text
conf.d/cert/<域名>/<域名>_bundle.crt   # 叶证书 + 中间证书
conf.d/cert/<域名>/<域名>.key          # 私钥
```

`ssl_certificate` 必须指向**完整链**（叶证书在前、中间证书在后）；只给叶证书时部分客户端会报不受信任。仓库里只提交了 `conf.d/cert/example/` 这份自签示例，真实证书目录不会进版本库。

### 4. 配置站点

第一步替换站点文件里的示例值。以 `conf.d/sites/stream.conf` 为例，需要改三处：

| 位置 | 示例值 | 改成 |
| --- | --- | --- |
| `server_name`（80 段与 443 段各一处） | `stream.example.example.example` | 真实域名 |
| `server` 与 `proxy_redirect` | `127.0.0.1:9005` | frp 映射到服务器的端口 |
| `ssl_certificate`、`ssl_certificate_key` | `conf.d/cert/example/…` | 上一步放好的证书 |

第二步决定哪些站点生效——`conf.d/sites.conf` 是启用清单，注释掉一行即禁用：

```nginx
include /etc/nginx/conf.d/sites/default-server.conf;   # 兜底：未知域名 444 / 拒握手
include /etc/nginx/conf.d/sites/stream.conf;           # 视频站（Emby）
```

### 5. 启动与验证

```bash
docker compose up -d
docker compose exec nginx nginx -t          # 语法检查
docker compose exec nginx nginx -s reload   # 改完配置后热加载
```

`nginx -t` 是唯一的验证手段；reload 失败时会保留旧配置，不会中断服务。

## 新增一个站点

`conf.d/sites/default-server.conf` 末尾有一段**整段注释的「通用站点基底」**——它是所有站点的基座，只包含每个站点都必需的部分（上游连接池、80 段跳转、443 段反代、安全头、错误页引用）。

1. 把基底整段复制到 `conf.d/sites/<站点名>.conf`（文件名全小写 kebab-case）；
2. 替换全部 `<占位值>`：域名、端口、证书路径；
3. 按该站点的需要在 `location /` 里增删指令：流媒体站要关响应缓冲，网盘站要放开上传上限，带 WebSocket 的站点要放大读超时；
4. 取消注释；
5. 在 `conf.d/sites.conf` 里放开对应的一行，`nginx -t` 通过后 reload。

站点文件里**不要**声明 `access_log`（会让该站点脱离全局集中日志），也**不要**重复定义 WebSocket 升级用的 `map`。

## 错误页怎么配

全站共用一套错误页素材（来自 error-pages 项目：11 个主题 × 20 个状态码），配置由三部分拼成，改哪一层都很清楚：

| 部分 | 位置 | 作用 |
| --- | --- | --- |
| 素材 | `conf.d/error/<主题>/<状态码>.html` | 静态页面，随 `./conf.d` 一起挂进容器；需要先拉子模块 |
| 映射表 | `nginx.conf` 的 3.15 段（http 层） | 声明「哪个状态码显示哪个页面」，一次声明对所有站点生效 |
| 落盘 location | `conf.d/snippets/error-pages.conf`（由站点 include） | 把 URI 变成真实文件，并限制这些页面只能由内部跳转访问 |

映射表长这样——`$status` 就是出错时的状态码，所以 18 个状态码只需要一行：

```nginx
proxy_intercept_errors on;        # 让上游返回的 4xx/5xx 也走错误页
error_page 400 403 404 405 408 409 410 411 412 413 416 418 429
        500 502 503 504 505 /error/hacker-terminal/$status.html;
```

落盘 location 只有三行，`internal` 保证外部无法把错误页当静态资源刷：

```nginx
location /error/ {
    internal;
    root /etc/nginx/conf.d;
}
```

常用操作：

- **换主题**：只改 `nginx.conf` 3.15 段里的主题名（`hacker-terminal` 之外还有 10 个主题），站点文件不用动。
- **增删状态码**：直接改映射表那一行；只写主题目录里确实存在的码，否则访客会看到 nginx 自带的 404。
- **新站点**：只要 include 落盘片段即可（通用站点基底里已经带了 `include /etc/nginx/conf.d/snippets/error-pages.conf;`）。
- **站点里不要自己写 `error_page`**：写任意一条，http 段的映射表在该站点整体失效（是取代，不是叠加）。
- **不要修改 `conf.d/error` 里的文件**：那是第三方子模块，升级用 `git submodule update --remote conf.d/error`。
- **验证**：访问一个不存在的路径应返回主题页且状态码仍是 404（映射没有写 `=200`）；临时停掉上游应看到 502 主题页。

刻意不映射的状态码：`401`（带 `WWW-Authenticate` 挑战头，换页会破坏浏览器密码弹窗）、`407`（代理认证，本拓扑用不到）；`444` 与 `495`/`496`/`497` 没有 HTTP 响应可换页。

## 想改某项全局行为时去哪里

| 想改什么 | 去哪里改 |
| --- | --- |
| 超时、缓冲区、压缩、安全头、代理默认值、限流阈值、TLS 参数 | `nginx.conf` 的 http 段 |
| HTTP 到 HTTPS 跳转（`listen 80` 与 `return 301`） | `conf.d/snippets/redirect-to-https.conf` |
| 错误页的落盘 location | `conf.d/snippets/error-pages.conf` |
| 错误码到错误页的映射表 | `nginx.conf` 的 3.15 段 |
| 哪些站点生效 | `conf.d/sites.conf` |
| 容器网络、挂载、日志轮转、停机宽限、文件描述符上限 | `docker-compose.yml` |

## 必须知道的几条约定

- **占位符都是假的**：域名用 `example.example.example`，端口用 `127.0.0.1:9001`–`9005`，证书用 `conf.d/cert/example/` 的自签样例。仓库里不放任何真实域名、IP、端口或凭据。
- **绝对路径是刻意的**：`nginx.conf` 使用 `/etc/nginx/mime.types` 与 `/etc/nginx/conf.d/*.conf`，对应容器内或软件包安装的路径。
- **注释即交付物**：每条指令都写清作用域、默认值与取值理由，不要删减或翻译这些注释。
- **三条继承陷阱**（站点层面最容易踩，细节见配置文件注释）：
  - `proxy_set_header`：站点里写任意一条，http 段那 8 条会整体失效；缺 `Host`、`Connection`、`Upgrade` 会断掉上游长连接与 WebSocket；
  - `add_header`：站点里写任意一条，http 段那三条安全头会整体失效，补 HSTS 时要四条一起写；
  - `error_page`：站点里写任意一条，http 段的统一错误页映射表在该站点整体失效（是取代，不是叠加）。
- **日志分两路**：容器 stdout 的日志由 Compose 轮转（`max-size`、`max-file`）；`./logs/` 下的访问日志与错误日志是宿主机上的真实文件，需要自己在宿主机上配置 logrotate。
