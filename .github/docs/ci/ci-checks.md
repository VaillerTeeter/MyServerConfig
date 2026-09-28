# CI 检查说明

所有 Pull Request 合并到 `master` 前，必须通过下列自动检查；工作流定义在 [.github/workflows/lint.yml](../../../.github/workflows/lint.yml)。

- **触发时机**：PR 目标分支为 `master`；直接 push 到 `master`
- **唯一必需检查**：`All Lint Checks Passed` 汇总门（见文末）
- **配置集中管理**：所有检查配置都在 [.lintrc/](../../../.lintrc) 下，一个配置对应一个 job
- **`.lintrc` 的定位**：既是各 job 引用的配置来源，也与其他文件一样接受通用规范与安全检查（命名、空白与行尾、拼写、YAML、密钥、SAST）
- **统一排除策略**：除 `.git`、`conf.d/error`、`logs` 外不做任何排除；editorconfig-checker 的内置默认排除与 cspell 的 `.gitignore` 复用均已关闭

## 检查总览

| Job | 检查对象 | 配置文件 | 工具 |
| --- | --- | --- | --- |
| Markdown Lint | 全部 `*.md` | [.markdownlint.json](../../../.lintrc/docs/markdown/.markdownlint.json) | markdownlint-cli2 |
| YAML Lint | 全部 `*.yml`、`*.yaml`（含 `.lintrc/**`） | [.yamllint.yml](../../../.lintrc/general/.yamllint.yml) | yamllint |
| CSpell | 全仓文本 | [cspell.json](../../../.lintrc/general/cspell.json) | cspell |
| ls-lint | 文件与目录命名 | [.ls-lint.yml](../../../.lintrc/general/.ls-lint.yml) | ls-lint |
| EditorConfig Checker | 全仓文本 | [.editorconfig](../../../.editorconfig) | editorconfig-checker |
| GitHub Actions Lint | `.github/workflows/*.yml` | 内建规则 | actionlint |
| Issue Chooser Config | `.github/ISSUE_TEMPLATE/config.yml` | [issue-config.schema.json](../../../.lintrc/data-formats/yaml/issue-config.schema.json) | check-jsonschema |
| Broken Links | `**/*.md` 里的链接 | 命令行参数 | lychee |
| Commitlint | PR 的 commit message | [.commitlintrc.cjs](../../../.lintrc/git/.commitlintrc.cjs) | commitlint |
| Secret Scan | 提交历史 | [.gitleaks.toml](../../../.lintrc/security/.gitleaks.toml) | gitleaks |
| SAST | 全仓（nginx 与 GitHub Actions 规则） | [.semgrep.yml](../../../.lintrc/security/.semgrep.yml) | semgrep |
| Nginx Config | `nginx.conf`、`conf.d/*.conf` | [gixy.conf](../../../.lintrc/infrastructure/nginx/gixy.conf) | nginx -t、gixy |

## 触发时机

- **PR 创建或更新**：目标分支为 `master` 时自动触发
- **直接 push 到 master**：管理员操作时同样触发
- **并发控制**：同一 PR 或分支的新提交会取消上一次仍在运行的检查

## Markdown Lint

使用 markdownlint-cli2 检查全部 Markdown 文档，配置文件为 [.lintrc/docs/markdown/.markdownlint.json](../../../.lintrc/docs/markdown/.markdownlint.json)。

| 规则 | 状态 | 说明 |
| --- | --- | --- |
| 默认全部规则 | 启用 | 标题层级、列表缩进、空行、代码块语言、表格风格等 |
| MD013 行长度 | 放宽到 400 字符 | 中文文档与宽表格不适合 80 字符限制 |
| MD033 内联 HTML | 允许列表为空 | 文档中不写 HTML 标签 |
| MD041 首行 H1 | 关闭 | Issue 模板以 front matter 或 H2 开头 |

本地复现：

```bash
npx markdownlint-cli2 --config .lintrc/docs/markdown/.markdownlint.json "**/*.md"
```

编辑器侧由 VS Code 的 markdownlint 扩展读取同一份配置（`.vscode/settings.json` 的 `markdownlint.configFile`）；`markdownlint.config` 已被官方弃用，不要再使用。

## YAML Lint

使用 yamllint 检查全部 `*.yml` 与 `*.yaml`，配置文件为 [.lintrc/general/.yamllint.yml](../../../.lintrc/general/.yamllint.yml)。含 `.lintrc/**` 在内的全部 YAML 都受这些规则约束。

| 规则 | 配置 | 说明 |
| --- | --- | --- |
| 基础规则 | `extends: default` | yamllint 默认规则集 |
| document-start | 要求首行 `---` | 注释不能替代文档起始标记 |
| 行长度 | 最长 200 字符 | 放宽默认的 80 字符 |
| 布尔值写法 | 仅允许 `true`、`false`、`on` | `on` 保留给 GitHub Actions 触发器 |
| 冒号后空格 | 最多 2 个 | 兼容 `key:  value` 的对齐写法 |
| 注释与内容间距 | 最少 1 个空格 | 允许行尾注释 |

同一 job 随后再跑一次 `--strict`（把警告升级为错误）。本地复现：

```bash
pip install yamllint==1.35.1
yamllint --config-file .lintrc/general/.yamllint.yml --strict "**/*.yml"
```

## CSpell 拼写检查

使用 cspell 检查全仓文本（含配置文件与工作流），配置文件为 [.lintrc/general/cspell.json](../../../.lintrc/general/cspell.json)。

| 配置项 | 当前值 | 说明 |
| --- | --- | --- |
| `words` | 空数组 | 增量维护：CI 报出的未知词再手动加入 |
| `dictionaries` | `en_US`、`markdown`、`networking-terms` | 英文基础、Markdown 术语、网络与 TLS 术语 |
| `ignorePaths` | `.git/**`、`conf.d/error/**`、`logs/**` | 不检查版本库、第三方子模块与运行时目录 |
| `flagWords` | 19 个常见拼写错误 | 出现即报错，例如 `teh`、`recieve` |
| `minWordLength` | 4 | 少于 4 个字符的词不检查，用于降低噪声 |

本地复现：

```bash
npx cspell@8.17.1 lint --config .lintrc/general/cspell.json --no-progress "**"
```

编辑器侧通过 `.vscode/settings.json` 的 `cSpell.import` 导入同一份配置，因此本地与 CI 共用同一份词表。

## ls-lint 文件命名检查

使用 ls-lint 检查文件与目录命名，配置文件为 [.lintrc/general/.ls-lint.yml](../../../.lintrc/general/.ls-lint.yml)。

| 对象 | 约定 |
| --- | --- |
| 目录名 | `regex:[a-z0-9._-]+`，禁止大写、空格与驼峰写法 |
| `.conf` | kebab-case，即 nginx 配置 |
| `.md` | SCREAMING_SNAKE_CASE 或 kebab-case |
| `.yml`、`.yaml`、`.json`、`.mjs`、`.cjs`、`.html` | kebab-case |
| `.github/ISSUE_TEMPLATE` | 目录名 SCREAMING_SNAKE_CASE，Markdown 文件为 snake_case |
| 兜底规则 | 任意段数的未知扩展名也必须满足 kebab-case |

`.git` 是唯一在配置里被忽略的目录；`conf.d/error` 与 `logs` 在配置文件的忽略段中声明。

本地复现：

```bash
ls-lint --config .lintrc/general/.ls-lint.yml
```

## EditorConfig 检查

使用 editorconfig-checker 校验换行符、编码、缩进与行尾空格，规则来自仓库根目录的 [.editorconfig](../../../.editorconfig)。

| 规则 | 配置 | 说明 |
| --- | --- | --- |
| 编码 | `utf-8` | 全仓统一无 BOM 的 UTF-8 |
| 换行符 | `lf` | 工作区在 Windows 上可能是 CRLF，Git 入库为 LF，CI 检出为 LF |
| 缩进 | 空格、2 个 | nginx 配置单独覆盖为 4 个 |
| 行尾 | 去尾空格、文件末尾保留一个换行 | Markdown 例外，允许行尾空格 |

本地复现：

```bash
ec -ignore-defaults -exclude '(^|/)\.git/' -exclude '(^|/)conf\.d/error/' -exclude '(^|/)logs/'
```

## GitHub Actions 工作流检查

使用 actionlint 校验 `.github/workflows/*.yml` 的语法、表达式与 shell 片段质量，无需额外配置文件。

本地复现：

```bash
docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
```

## Issue 模板选择页配置检查

使用 check-jsonschema 按本地 schema 校验 `.github/ISSUE_TEMPLATE/config.yml`，schema 位于 [.lintrc/data-formats/yaml/issue-config.schema.json](../../../.lintrc/data-formats/yaml/issue-config.schema.json)。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `blank_issues_enabled` | 布尔 | 是否允许创建空白 Issue |
| `contact_links[].name` | 字符串 | 链接标题 |
| `contact_links[].url` | 字符串 | 链接地址，允许 `mailto:` 写法 |
| `contact_links[].about` | 字符串 | 链接说明 |

本地复现：

```bash
pip install check-jsonschema==0.38.0
check-jsonschema \
  --schemafile .lintrc/data-formats/yaml/issue-config.schema.json \
  .github/ISSUE_TEMPLATE/config.yml
```

## 文档死链检查

使用 lychee 检查 `**/*.md` 里的外链是否可访问；`.git`、`conf.d/error`、`logs` 被排除，并允许 `200`、`206`、`429` 状态码与最多 3 次重试。

本地复现：

```bash
docker run --rm -v "$PWD:/repo" -w /repo lycheeverse/lychee:latest \
  --no-progress --accept 200,206,429 --max-retries 3 \
  --exclude-path .git --exclude-path conf.d/error --exclude-path logs "**/*.md"
```

## 提交信息检查

使用 commitlint 检查 PR 区间内的每条 commit message，配置文件为 [.lintrc/git/.commitlintrc.cjs](../../../.lintrc/git/.commitlintrc.cjs)，仅在 `pull_request` 事件运行。

| 规则 | 配置 | 说明 |
| --- | --- | --- |
| 类型前缀 | `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`、`security`、`deps` | 与 `.clinerules/git-workflow.md` 的分支命名配套 |
| 描述长度 | 最少 10、最多 100 字符 | 描述不能为空，不能以句号结尾 |
| 标题长度 | 15 到 120 字符 | 含 `type(scope): ` 前缀 |
| 正文与脚注 | 前置空行，正文每行最多 200、脚注每行最多 100 字符 | 与忽略空行的规则共同生效 |

本地复现：

```bash
npm install --no-save @commitlint/cli@19.6.0 @commitlint/config-conventional@19.6.0 conventional-changelog-conventionalcommits@8.0.0
echo "feat: add nginx upstream health check" | npx commitlint --config .lintrc/git/.commitlintrc.cjs
```

## 密钥与凭据扫描

使用 gitleaks 全量扫描提交历史，配置通过环境变量 `GITLEAKS_CONFIG` 指定为 [.lintrc/security/.gitleaks.toml](../../../.lintrc/security/.gitleaks.toml)；该 action 没有 `config-path` 输入，误用会导致配置不生效。

| 内容 | 说明 |
| --- | --- |
| 默认规则集 | `[extend] useDefault = true`，在 gitleaks 内建规则之上叠加 |
| 自定义规则 | 通用 API Key、通用 secret 两类正则 |
| 白名单 | 配置文件自身、图片与文档后缀、锁文件、`${{ secrets.X }}` 引用 |

本地复现：

```bash
docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:latest \
  detect --source . -c .lintrc/security/.gitleaks.toml --verbose
```

## 静态安全扫描

使用 semgrep 加载本地规则 [.lintrc/security/.semgrep.yml](../../../.lintrc/security/.semgrep.yml) 与官方规则集 `p/github-actions`；本地规则覆盖 nginx 配置的文本级风险与工作流的供应链风险。

| 规则组 | 示例检查项 |
| --- | --- |
| nginx 配置 | 旧版 TLS、`ssl_session_tickets on`、`autoindex on`、变量 `proxy_pass`、`add_header` 缺少 `always` |
| 工作流 | 分支锁定的 action、curl 管道给 shell、`write-all` 权限、`pull_request_target` 检出 PR 代码 |
| 缺失项 | 文件级检查关键加固指令是否存在，例如 `proxy_ssl_verify on` |

命令行使用 `--error`，任何 severity 的命中都会让 job 失败；若判定为可接受风险，请在对应位置写 `# nosemgrep: <rule-id>` 并说明原因。

本地复现：

```bash
pip install semgrep
semgrep scan --config .lintrc/security/.semgrep.yml --config p/github-actions \
  --exclude .git/ --exclude conf.d/error/ --exclude logs/ .
```

## Nginx 配置检查

仓库核心内容是 nginx 配置，因此单独用一个 job 做语法与安全两层检查，配置文件为 [.lintrc/infrastructure/nginx/gixy.conf](../../../.lintrc/infrastructure/nginx/gixy.conf)。

| 层次 | 工具 | 说明 |
| --- | --- | --- |
| 语法 | `nginx -t` | 在 `nginx:alpine` 镜像内执行；配置先复制到临时目录，并用一次性自签证书覆盖仓库内的示例证书 |
| 安全 | gixy | 使用 `yandex/gixy` 镜像，用 `-c` 指定配置文件；开启全部插件并扩大 `add_header` 覆盖检测范围 |

直接在本机执行 `nginx -t` 会失败：

- `nginx.conf` 使用绝对路径（`/etc/nginx/mime.types`、`/etc/nginx/conf.d/*.conf`），必须挂载到镜像内的相同位置；
- 仓库内的 `conf.d/cert/example/*` 只是示例自签证书，CI 会先用一次性证书覆盖它，避免把示例材料当成真实凭据。

本地复现（等价于 CI 的两步）：

```bash
mkdir -p /tmp/nginx-test && cp nginx.conf /tmp/nginx-test/ && cp -r conf.d /tmp/nginx-test/
openssl req -x509 -newkey rsa:2048 -days 1 -nodes -subj "/CN=example.example.example" \
  -keyout /tmp/nginx-test/conf.d/cert/example/example.example.example.key \
  -out /tmp/nginx-test/conf.d/cert/example/example.example.example_bundle.crt
docker run --rm \
  -v /tmp/nginx-test/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /tmp/nginx-test/conf.d:/etc/nginx/conf.d:ro \
  nginx:alpine nginx -t
docker run --rm -v "$PWD:/repo" -w /repo yandex/gixy \
  -c .lintrc/infrastructure/nginx/gixy.conf nginx.conf conf.d/sites.conf conf.d/sites/
```

## 汇总门

`All Lint Checks Passed` 是分支保护里的唯一必需状态检查，它依赖上述全部 job：只要有一个 job 失败或被取消，汇总门就失败；`skipped` 视为通过（例如提交信息检查在 `push` 事件下会跳过）。

## 新增检查的约定

1. 把配置文件放到 `.lintrc/<分类>/` 下，命名风格与现有文件保持一致；
2. 在 `.github/workflows/lint.yml` 增加一个 job，用相对路径引用该配置；
3. 把新 job 名加入 `all-checks` 的 `needs` 列表；
4. 在本文件补一节，写清检查目的、关键规则、本地复现命令与常见报错处理。

## 本地复现速查

| 检查 | 一条命令 |
| --- | --- |
| Markdown | `npx markdownlint-cli2 --config .lintrc/docs/markdown/.markdownlint.json "**/*.md"` |
| YAML | `yamllint --config-file .lintrc/general/.yamllint.yml --strict "**/*.yml"` |
| 拼写 | `npx cspell@8.17.1 lint --config .lintrc/general/cspell.json "**"` |
| 命名 | `ls-lint --config .lintrc/general/.ls-lint.yml` |
| EditorConfig | `ec -ignore-defaults`（仅排除 `.git`、`conf.d/error`、`logs`，详见上文） |
| 工作流 | `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest` |
| Issue 模板配置 | `check-jsonschema --schemafile .lintrc/data-formats/yaml/issue-config.schema.json .github/ISSUE_TEMPLATE/config.yml` |
| 死链 | 见上文文档死链检查一节 |
| 提交信息 | `npx commitlint --config .lintrc/git/.commitlintrc.cjs` |
| 密钥 | `docker run --rm -v "$PWD:/repo" -w /repo zricethezav/gitleaks:latest detect -c .lintrc/security/.gitleaks.toml` |
| SAST | `semgrep scan --config .lintrc/security/.semgrep.yml .` |
| nginx | 见上文 Nginx 配置检查一节 |
