# MyServerConfig

按分支组织的配置集合仓库。每个分支是一套完整、可独立取用的配置，自带自己的文档、规则与 CI，分支之间互不依赖。

本分支（`master`）只作为索引，不含任何配置内容。

## 分支

| 分支 | 用途 |
| --- | --- |
| `MyNginx` | Nginx 配置：多站点 HTTPS 反向代理、统一错误页、TLS 与安全响应头加固 |
| `MyFrps` | frp 服务端（frps）配置 |
| `MyFrpc` | frp 客户端（frpc）配置 |

## 取用某一套配置

```bash
# 只克隆一个分支
git clone -b <分支名> https://github.com/VaillerTeeter/MyServerConfig.git

# 已经克隆过仓库时，切换分支即可
git switch <分支名>
```

每套配置的部署方式写在它自己的 README 里。
