# MyServerConfig

按分支组织的配置集合仓库。每个分支是一套完整、可独立取用的配置，自带自己的文档、规则与 CI，分支之间互不依赖。

本分支（`master`）只作为索引，不含任何配置内容。

## 分支

| 分支 | 用途 |
| --- | --- |
| [`MyNginx`](https://github.com/VaillerTeeter/MyServerConfig/tree/MyNginx) | Nginx 配置：多站点 HTTPS 反向代理、统一错误页、TLS 与安全响应头加固 |
| [`MyFrps`](https://github.com/VaillerTeeter/MyServerConfig/tree/MyFrps) | frp 服务端（frps）配置 |
| [`MyFrpc`](https://github.com/VaillerTeeter/MyServerConfig/tree/MyFrpc) | frp 客户端（frpc）配置 |

`MyFrps` 与 `MyFrpc` 是一套拓扑的两半：服务端接收隧道并按 `allowPorts` 放行端口，客户端把内网服务映射上来；两边的 `auth.token`、端口与 TLS 设置必须配对。`MyNginx` 在最前面终结 TLS，并反向代理到映射端口。

## 取用某一套配置

```bash
# 只克隆一个分支
git clone -b <分支名> https://github.com/VaillerTeeter/MyServerConfig.git

# 已经克隆过仓库时，切换分支即可
git switch <分支名>
```

每套配置的部署方式写在它自己的 README 里（含占位值替换清单与验证命令）。

## 许可

每个分支自带 `LICENSE`（GPL-3.0）与自己的文档、规则文件，随分支一起取用；本索引分支（`master`）不含这些内容。
