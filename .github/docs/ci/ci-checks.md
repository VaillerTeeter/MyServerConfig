# CI 检查说明

所有 Pull Request 合并到 `MyNginx` 前，必须通过下列自动检查；工作流定义在 [.github/workflows/lint.yml](../../../.github/workflows/lint.yml)。

- **触发时机**：PR 目标分支为 `MyNginx`；直接 push 到 `MyNginx`
- **唯一必需检查**：`All Lint Checks Passed` 汇总门（见文末）
- **配置集中管理**：所有检查配置都在 [.lintrc/](../../../.lintrc) 下，一个配置对应一个 job
- **`.lintrc` 的定位**：既是各 job 引用的配置来源，也与其他文件一样接受通用规范与安全检查（命名、空白与行尾、拼写、YAML、密钥、SAST）
- **警告即失败**：所有检查都必须「命中即失败」，不允许存在「只提示」档。各工具对低级别问题（warning）的退出码语义并不一致，因此由 `strictness-guard` job 在配置层兜底（见下文「严格性守卫」一节）
- **验证入口**：所有检查只在 CI 运行；本文件只说明每个 job 检查什么、依据哪条规则，不提供本地复现命令
- **统一排除策略**：显式排除项为 `.git`、`conf.d/cert`、`conf.d/error`、`logs` 四处；editorconfig-checker 的内置默认排除已关闭（`-ignore-defaults`），cspell 侧保持 `useGitignore: true`，因此 `.gitignore` 命中的未跟踪文件（日志、真实证书等）在本地也不会被检查

## 检查总览

| Job | 检查对象 | 配置文件 | 工具 |
| --- | --- | --- | --- |
| Markdown Lint | 全部 `*.md` | [.markdownlint.json](../../../.lintrc/docs/markdown/.markdownlint.json) | markdownlint-cli2 |
| YAML Lint | 全部 `*.yml`、`*.yaml`（含 `.lintrc/**`） | [.yamllint.yml](../../../.lintrc/general/.yamllint.yml) | yamllint |
| CSpell | 全仓文本 | [cspell.json](../../../.lintrc/general/cspell.json) | cspell |
| ls-lint | 文件与目录命名 | [.ls-lint.yml](../../../.lintrc/general/.ls-lint.yml) | ls-lint |
| EditorConfig Checker | 全仓文本 | [.editorconfig](../../../.editorconfig) | editorconfig-checker |
| Prettier | `**/*.mjs`、`**/*.cjs` | [.prettierrc](../../../.lintrc/frontend/prettier/.prettierrc) | prettier |
| GitHub Actions Lint | `.github/workflows/*.yml` | 内建规则 | actionlint |
| Issue Chooser Config | `.github/ISSUE_TEMPLATE/config.yml` | [issue-config.schema.json](../../../.lintrc/data-formats/yaml/issue-config.schema.json) | check-jsonschema |
| Broken Links | `**/*.md` 里的链接 | 命令行参数 | lychee |
| Commitlint | PR 的 commit message | [.commitlintrc.cjs](../../../.lintrc/git/.commitlintrc.cjs) | commitlint |
| Secret Scan | 提交历史 | [.gitleaks.toml](../../../.lintrc/security/.gitleaks.toml) | gitleaks |
| SAST | 全仓（nginx 与 GitHub Actions 规则） | [.semgrep.yml](../../../.lintrc/security/.semgrep.yml) | semgrep |
| Nginx Config | `nginx.conf`、`conf.d/sites.conf`、`conf.d/sites/*.conf`、`conf.d/snippets/*.conf` | [gixy.conf](../../../.lintrc/infrastructure/nginx/gixy.conf) | nginx -t、gixy |
| Strictness Guard | `.lintrc/**`、`.github/workflows/**` | 内建规则 | grep（禁止降级与放行写法） |

## 触发时机

- **PR 创建或更新**：目标分支为 `MyNginx` 时自动触发
- **直接 push 到 MyNginx**：管理员操作时同样触发
- **并发控制**：同一 PR 或分支的新提交会取消上一次仍在运行的检查

## Markdown Lint

使用 markdownlint-cli2 检查全部 Markdown 文档，配置文件为 [.lintrc/docs/markdown/.markdownlint.json](../../../.lintrc/docs/markdown/.markdownlint.json)。

| 规则 | 状态 | 说明 |
| --- | --- | --- |
| 默认全部规则 | 启用 | 标题层级、列表缩进、空行、代码块语言、表格风格等 |
| MD013 行长度 | 放宽到 400 字符 | 中文文档与宽表格不适合 80 字符限制 |
| MD033 内联 HTML | 允许列表为空 | 文档中不写 HTML 标签 |
| MD041 首行 H1 | 关闭 | Issue 模板以 front matter 或 H2 开头 |

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

job 在同一趟里同时带 `--strict` 与 `--format github`：前者把 warning 升级为错误（yamllint 默认只对 error 返回非 0，warning 不会让 job 失败），后者让问题以 `::error::` / `::warning::` 注解出现在 PR 界面。

## CSpell 拼写检查

使用 cspell 检查全仓文本（含配置文件与工作流），配置文件为 [.lintrc/general/cspell.json](../../../.lintrc/general/cspell.json)。

| 配置项 | 当前值 | 说明 |
| --- | --- | --- |
| `words` | 增量维护的词表（约 100 词） | CI 报出的未知词经确认后再手动加入 |
| `dictionaries` | `en_US`、`markdown`、`networking-terms` | 英文基础、Markdown 术语、网络与 TLS 术语 |
| `ignorePaths` | `**/.git/**`、`**/conf.d/cert/**`、`**/conf.d/error/**`、`**/logs/**` | 不检查版本库、示例证书、第三方子模块与运行时目录 |
| `enableGlobDot` | `true` | 允许检查以 `.` 开头的文件与目录（`.github`、`.lintrc`、`.clinerules` 必须被检查） |
| `useGitignore` | `true` | 复用 `.gitignore`，本地未跟踪的日志与真实证书不会被检查 |
| `flagWords` | 19 个常见拼写错误 | 出现即报错，例如 `teh`、`recieve` |
| `minWordLength` | 4 | 少于 4 个字符的词不检查，用于降低噪声 |

> **`ignorePaths` 必须写成 `**/` 开头的模式。** cspell 的相对 glob 是相对「声明它的配置文件的 `globRoot`」解析的，而 `globRoot` 默认就是该配置文件所在目录（此处为 `.lintrc/general/`），因此写 `.git/**` 会被解析成 `.lintrc/general/.git/**`，永远匹配不到仓库根下的 `.git`；只有以 `**` 开头的 global pattern 对绝对路径匹配，不受 `globRoot` 影响。
>
> 另外 cspell CLI 不内置排除 `.git`（默认只排除 `node_modules/**`），本仓库又开启了 `enableGlobDot`，一旦 `ignorePaths` 失效，`.git/**` 会被整棵扫描。后续改动 `ignorePaths` 时请沿用 `**/` 前缀。

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

> **`--warn` 永远不要加。** ls-lint 的该开关语义是「把 lint 错误写到 stdout 并以 0 退出」，加上去这个 job 就永远绿了。同理，配置里没有任何键命中的文件会被静默跳过，所以 `.ls-lint.yml` 用兜底键（`.*`、`.*.*`、`.*.*.*`）把「跳过」压到 0。

## EditorConfig 检查

使用 editorconfig-checker 校验换行符、编码、缩进与行尾空格，规则来自仓库根目录的 [.editorconfig](../../../.editorconfig)。

| 规则 | 配置 | 说明 |
| --- | --- | --- |
| 编码 | `utf-8` | 全仓统一无 BOM 的 UTF-8 |
| 换行符 | `lf` | 工作区在 Windows 上可能是 CRLF，Git 入库为 LF，CI 检出为 LF |
| 缩进 | 空格、2 个 | nginx 配置单独覆盖为 4 个 |
| 行尾 | 去尾空格、文件末尾保留一个换行 | Markdown 例外，允许行尾空格 |

> **ec 有两处「不会失败」的通道（已知、已接受）**：来自 `.editorconfig` 解析的告警（`Logger.Warning()`）与「Could not decode the ... encoded file」都只写日志，不计入退出码（其 `main.go` 里只有验证错误计数非 0 才 `exit 1`）。本仓只有一份内容简单的 `.editorconfig`，风险面很小；ec 3.x 又没有注解输出格式、日志前缀受颜色影响，做输出匹配式的守卫很脆，因此这里不额外兜底 —— 若将来升到 ec 4.x（在 GitHub Actions 下会自动切到注解格式），再考虑并入 `strictness-guard`。

## GitHub Actions 工作流检查

使用 actionlint 校验 `.github/workflows/*.yml` 的语法、表达式与 shell 片段质量，无需额外配置文件。

actionlint 没有 warning 档：任何问题都返回 1（源码里只有 `ExitStatusSuccessNoProblem = 0` 与 `ExitStatusSuccessProblemFound = 1` 两个状态），因此它天然满足「警告即失败」。CI 里额外用官方模板把输出转成 `::error` 注解，让问题直接标在 PR 的 Files changed 上而不是埋在日志里；`-ignore` 这类放行开关由 `strictness-guard` 禁止。

## Issue 模板选择页配置检查

使用 check-jsonschema 按本地 schema 校验 `.github/ISSUE_TEMPLATE/config.yml`，schema 位于 [.lintrc/data-formats/yaml/issue-config.schema.json](../../../.lintrc/data-formats/yaml/issue-config.schema.json)。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `blank_issues_enabled` | 布尔 | 是否允许创建空白 Issue |
| `contact_links[].name` | 字符串 | 链接标题 |
| `contact_links[].url` | 字符串 | 链接地址，允许 `mailto:` 写法 |
| `contact_links[].about` | 字符串 | 链接说明 |

## 文档死链检查

使用 lychee 检查 `**/*.md` 里的外链是否可访问；`.git`、`conf.d/error`、`logs` 被排除，并允许 `200`、`206`、`429` 状态码与最多 3 次重试。

## 提交信息检查

使用 commitlint 检查 PR 区间内的每条 commit message，配置文件为 [.lintrc/git/.commitlintrc.cjs](../../../.lintrc/git/.commitlintrc.cjs)，仅在 `pull_request` 事件运行。

| 规则 | 配置 | 说明 |
| --- | --- | --- |
| 类型前缀 | `feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`、`security`、`deps` | 与 `.clinerules/git-workflow.md` 的分支命名配套 |
| 描述长度 | 最少 10、最多 100 字符 | 描述不能为空，不能以句号结尾 |
| 标题长度 | 15 到 120 字符 | 含 `type(scope):` 前缀 |
| 正文与脚注 | 前置空行，正文每行最多 200、脚注每行最多 100 字符 | 与忽略空行的规则共同生效 |

## 密钥与凭据扫描

使用 gitleaks 全量扫描提交历史，配置通过环境变量 `GITLEAKS_CONFIG` 指定为 [.lintrc/security/.gitleaks.toml](../../../.lintrc/security/.gitleaks.toml)；该 action 没有 `config-path` 输入，误用会导致配置不生效。

| 内容 | 说明 |
| --- | --- |
| 默认规则集 | `[extend] useDefault = true`，在 gitleaks 内建规则之上叠加 |
| 自定义规则 | 通用 API Key、通用 secret 两类正则 |
| 白名单 | 配置文件自身、图片与文档后缀、锁文件、`${{ secrets.X }}` 引用 |

## 静态安全扫描

使用 semgrep 加载本地规则 [.lintrc/security/.semgrep.yml](../../../.lintrc/security/.semgrep.yml) 与官方规则集 `p/github-actions`；本地规则覆盖 nginx 配置的文本级风险与工作流的供应链风险。

| 规则组 | 示例检查项 |
| --- | --- |
| nginx 配置 | 旧版 TLS、`ssl_session_tickets on`、`autoindex on`、变量 `proxy_pass`、`add_header` 缺少 `always` |
| 工作流 | 分支锁定的 action、curl 管道给 shell、`write-all` 权限、`pull_request_target` 检出 PR 代码 |
| 缺失项 | 文件级检查关键加固指令是否存在；有条件才成立的项按条件判定，例如 `proxy_ssl_verify on` 只在同文件出现 `proxy_pass https://` 时才要求 |

严重度策略：**本仓规则一律 `severity: ERROR`**，不留 WARNING/INFO 档，`strictness-guard` 会拒绝降级写法。

| 参数 | 作用 | 依据 |
| --- | --- | --- |
| `--error` | 只要命中就 exit 1（`error_on_findings` 且结果非空即返回 1） | semgrep 退出码文档 |

> **不要给 semgrep 传 `--severity`。** 它筛的是**规则**而不是**命中**（语义为 `Report findings only from rules matching the supplied severity`，精确匹配）。本仓规则全是 `ERROR`，传 `INFO` 会加载 0 条规则：日志里只剩一句 `Nothing to scan.`、退出码 0 —— 扫描被静默关掉，job 反而变绿。
>
> **也不要传 `--strict`。** 它把 semgrep 自身的 WARN 级问题升级为失败，与「让本仓规则更严格」无关。
>
> 为了不让这类「空跑 = 假绿」复发，job 里另有一道**空扫描守卫**：`semgrep` 输出经 `tee` 落盘后断言不出现 `Nothing to scan`、且出现 `with N Code rules`，否则直接失败。

若判定某条命中是可接受风险，请在该位置写 `# nosemgrep: <rule-id>` 并说明原因，不要通过降级 severity、跳过规则或放行开关绕过去。

## Nginx 配置检查

仓库核心内容是 nginx 配置，因此单独用一个 job 做语法与安全两层检查，配置文件为 [.lintrc/infrastructure/nginx/gixy.conf](../../../.lintrc/infrastructure/nginx/gixy.conf)。

| 层次 | 工具 | 说明 |
| --- | --- | --- |
| 语法 | `nginx -t` | 在 `nginx:alpine` 镜像内执行；配置先复制到临时目录，并用一次性自签证书覆盖仓库内的示例证书 |
| 语法（升格） | `[warn]` 断言 | `nginx -t` 的 `[warn]` 不影响退出码，在 CI 里完全看不见；job 把输出 tee 到文件后断言不出现 `warn`/`error`/`crit`/`alert`/`emerg`，出现即失败。白名单只有一条：仓库内是自签示例证书、没有 OCSP responder URL，nginx 必然对 `ssl_stapling` 打 warn 并忽略它（以 notice 打印，换真实证书后自动消失） |
| 安全 | gixy | 使用 `yandex/gixy` 镜像，用 `-c` 指定配置文件；开启全部插件并扩大 `add_header` 覆盖检测范围 |

gixy 的调用有三条容易踩的规则（细节见 [gixy.conf](../../../.lintrc/infrastructure/nginx/gixy.conf) 头部注释）：

1. **位置参数只能是文件。** gixy 对每个参数直接打开文件，传目录会抛错并让整个进程非 0 退出（前面文件的审计结果也一起丢），所以目录必须写成 shell glob（`conf.d/sites/*.conf`）交给 bash 展开；
2. **多参数时不校验文件是否存在。** 缺文件只打一行日志然后继续、退出码仍是 0，因此 job 里先由 `Check gixy targets` 步骤断言每个 glob 至少命中一个文件，避免改名或改布局让覆盖范围静默缩水；
3. **`--disable-includes` 是刻意打开的。** 仓库的 include 全是 `/etc/nginx/...` 绝对路径，容器里挂在 `/repo`，include 链永远解析不到（只会打 4 行 `File not found` 告警、不影响退出码），实际就是逐文件独立审计 —— 写成显式开关，而不是靠「忽略告警」。同理不要加 `-l/--level`：默认已是最低档（全部上报），`-l` 会把低危过滤掉，那是放宽。

本 job 的固定动作：

1. 把 `nginx.conf` 与 `conf.d/` 复制到临时目录，删掉 `conf.d/error`（第三方子模块，14 MB，不参与语法校验），并用一次性自签证书覆盖 `conf.d/cert/example/*`，避免把仓库里的示例材料当成真实凭据；
2. 把临时目录里的这两项挂到镜像内 `/etc/nginx/nginx.conf` 与 `/etc/nginx/conf.d`：`nginx.conf` 的 include 与证书都是 `/etc/nginx/...` 绝对路径，挂载位置必须一致；
3. 先在 `nginx:alpine` 里执行 `nginx -t`，输出落盘后断言不出现 `[warn]`/`[error]`/`[crit]`/`[alert]`/`[emerg]`；再用 `yandex/gixy` 做安全审计。

## 严格性守卫（警告即失败）

`strictness-guard` job 是「warning 也要当 error」这条纪律的兜底实现：它不依赖各工具的退出码语义，而是用 grep 在配置层直接拒绝所有「降级」与「放行」写法。

| 禁止的写法 | 为什么危险 |
| --- | --- |
| JSON 里的 severity 降级（键为 `severity`、取值为 `warning` 或 `info`） | markdownlint 的规则支持把违规从 error 降级成 warning |
| YAML 行首的 `severity:` 取 `WARNING` / `INFO` | semgrep 规则一旦降级，未来任何收窄 severity 阈值的写法都会让它静默失效 |
| YAML 行首的 `level:` 取 `warning` | yamllint 的规则级降级 |
| 行首数组以 `1` 开头 | commitlint 用 1 表示 warning，而 warning 不会让命令失败 |
| `--warn`、`--no-error`、`--exit-code 0`、`-ignore`、`continue-on-error`、`true` | 工具级 / 工作流级的放行开关，出现一个守卫就形同虚设 |
| semgrep step 里出现 `--severity`（后接空格、`=` 或行尾） | 它筛的是**规则**而不是命中：传 `INFO` 会加载 0 条规则（日志只剩 `Nothing to scan.`、退出码 0），扫描被静默关掉而 job 反而变绿 |

实现细节（改这一段前务必先读）：

- 模式里的关键字符串用 `''` 拼接（例如 `'--wa''rn'` 才等于 `--warn`），这样**守卫脚本自己的文本不会被自己的 grep 命中**，也不会被拼写检查当成生造的单词；
- 它只扫描 `.lintrc/` 与 `.github/workflows/`，不扫文档 —— 文档需要引用这些写法才能把规则说清楚。

## Prettier 代码格式检查

`.lintrc/frontend/prettier/.prettierrc` 被两处共用：编辑器侧由 `.vscode/settings.json` 的 `prettier.configPath` 指向它，CI 侧由 `prettier-check` job 以 `--config` 指向它。本 job 把关 `.mjs` / `.cjs` 的格式。

| 项 | 当前值 | 说明 |
| --- | --- | --- |
| 覆盖范围 | `**/*.mjs`、`**/*.cjs` | Markdown 的 `proseWrap: always` 与 JSON/YAML 的 `printWidth` 差异会让一次性格式化影响面过大，扩大范围需要单独评估 |
| 配置 | `--config` 显式传入 | 配置文件不在标准路径，不依赖 prettier 的自动发现 |
| 判定 | `--check` | 任何文件不符合格式即返回非 0 |

## 汇总门

`All Lint Checks Passed` 是分支保护里的唯一必需状态检查，它依赖上述全部 job，并按白名单判定：

| job 结果 | 判定 |
| --- | --- |
| `success` | 通过 |
| `skipped` | 仅当该 job 是 `commitlint-lint` 且事件不是 `pull_request` 时通过（它带 `if:` 条件） |
| `failure`、`cancelled`、其他 `skipped` | 失败 |

除明确登记的那一种跳过外，其他情况一律失败：job 名写错、`if:` 条件写错或上游被取消都不会被放行。

## 新增检查的约定

1. 把配置文件放到 `.lintrc/<分类>/` 下，命名风格与现有文件保持一致；
2. 在 `.github/workflows/lint.yml` 增加一个 job，用相对路径引用该配置；
3. 把新 job 名加入 `all-checks` 的 `needs` 列表；
4. 在本文件补一节，写清检查目的、关键规则与常见报错处理。
