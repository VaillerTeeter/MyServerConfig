---
description: "MyFrps project overview — frp server (frps) configuration repository. Always apply."
globs: ""
alwaysApply: true
---

# Project Identity

## Project Name & Purpose

MyFrps (`VaillerTeeter/MyServerConfig`, branch `MyFrps`) is a **frp server (frps)
configuration reference repository**. Its deliverable is configuration and documentation: there is
no application source code, no package manager and no build step.

## Nature

This is a **single-technology repository** — hand-written frps TOML configuration plus the docs and
lint tooling that keep it correct. The substance of the project lives in these files:

| File | Size | Scope |
| --- | --- | --- |
| `frps.toml` | ~146 lines | the frps server configuration: bind address and port, auth, transport (TCP mux keepalive, heartbeat, QUIC), dashboard / `webServer`, logging, port-range limits, optional SSH tunnel gateway and HTTP plugins |
| `docker-compose.yml` | 21 lines | runs the frps container (host network, log rotation, restart policy) |

Every directive is preceded by an explanatory Chinese comment block that states its type, scope,
default value and the reasoning behind the chosen value. **Those comments are the deliverable, not
decoration** — never delete, shorten or translate them.

## Intentional Placeholders

The repository is meant to be reusable as an example, so every environment-specific value is
deliberately fake. Keep it that way:

- Bind address and port: `bindAddr = "0.0.0.0"` with the default `bindPort = 7000`
- Auth token and dashboard credentials: obviously fake placeholder values, never a real secret
- TLS / dashboard TLS material: comment-only placeholders (`transport.tls.*`, `webServer.tls.*`) —
  no real certificate or private key is committed
- Port ranges: the numeric example inside `allowPorts`

Never commit a real hostname, IP address, port, token or credential into this repository.

## Repository Layout

```text
.
├── .clineignore                          # agent context exclusions: logs
├── .clinerules/                          # Cline rules: this file and git-workflow.md
│   ├── git-workflow.md                   # Cline git workflow rules (English)
│   └── project-identity.md               # this file
├── .editorconfig                         # charset / EOL / indent: LF, 2 spaces
├── .gitignore                            # ignores log files
├── .github/                              # GitHub community files and CI metadata
│   ├── dependabot.yml                    # weekly GitHub Actions dependency updates
│   ├── PULL_REQUEST_TEMPLATE.md          # PR template (bilingual; every section required)
│   ├── docs/ci/ci-checks.md              # CI check reference (Chinese)
│   ├── ISSUE_TEMPLATE/                   # issue templates (bilingual)
│   │   ├── bug_report_en.md
│   │   ├── bug_report_zh.md
│   │   ├── config.yml                    # issue template chooser configuration
│   │   ├── feature_request_en.md
│   │   └── feature_request_zh.md
│   ├── scripts/ai-review.mjs             # AI review script behind the /review command
│   └── workflows/                        # GitHub Actions workflows
│       ├── lint.yml                      # the only lint workflow, plus its aggregate gate
│       └── review-command.yml            # trigger for the /review PR command
├── .lintrc/                              # one config per job in lint.yml
│   ├── data-formats/
│   │   ├── toml/taplo.toml               # TOML formatter config (taplo check / fmt)
│   │   └── yaml/issue-config.schema.json # JSON Schema for ISSUE_TEMPLATE/config.yml
│   ├── docs/markdown/.markdownlint.json  # markdownlint rules
│   ├── frontend/prettier/.prettierrc     # Prettier config (mjs / cjs / yaml / json / md)
│   ├── general/
│   │   ├── .ls-lint.yml                  # file and directory naming rules
│   │   ├── .yamllint.yml                 # YAML rules
│   │   └── cspell.json                   # spelling word list and dictionaries
│   ├── git/.commitlintrc.cjs             # Conventional Commits validation
│   └── security/
│       ├── .gitleaks.toml                # secret scanning rules
│       └── .semgrep.yml                  # SAST rules (workflows: supply chain / permissions)
├── .vscode/                              # VS Code workspace configuration
│   ├── extensions.json                   # recommended extensions
│   └── settings.json                     # workspace settings, pointing at the .lintrc configs
├── logs/                                 # runtime log directory; only .gitkeep is tracked
│   └── .gitkeep                          # placeholder that keeps the directory in git
├── CODE_OF_CONDUCT.md                    # code of conduct
├── CONTRIBUTING.md                       # contribution guide
├── docker-compose.yml                    # container definition for the frps server
├── frps.toml                             # the frps server configuration (the deliverable)
├── LICENSE                               # GPL-3.0
├── README.md                             # project readme
└── SECURITY.md                           # security policy and vulnerability reporting
```

## Key Rules

- **All validation runs in CI; do not build a local verification path.** Syntax, security, docs,
  naming, spelling, secret and SAST checks all run through `.github/workflows/lint.yml` on GitHub
  Actions, and the single required status check is the `All Lint Checks Passed` aggregate gate.
  Do not add local verification scripts, npm scripts, Makefiles or test suites; CI is the only
  validation path, and no local reproduction steps are documented.
- **Container paths are absolute on purpose.** `frps.toml` refers to `/etc/frp/...` (for example
  `log.to = "/etc/frp/log/frps.log"`), mirroring the layout inside the frps container. Keep that
  convention when adding configuration.
- **Credentials never enter the repository.** `frps.toml` ships placeholder values only
  (`auth.token`, `webServer.user`, `webServer.password`); never put a real token, password,
  certificate or private key into the working tree or into git history.
- **One lint config, one CI job.** Every config under `.lintrc/<family>/` must have a matching job in
  `lint.yml` and an entry in the `all-checks` `needs` list. Adding a check means four things: the
  config file, the job, the `needs` entry, and a new section in `ci-checks.md`.
- **`.lintrc/**` is linted too.** Configuration files obey the same file-naming, whitespace and line
  ending, spelling, YAML and secret/SAST rules as the rest of the repository.
- **Naming and formatting are enforced.** kebab-case for `.yml`, `.yaml`, `.json`, `.mjs`, `.cjs`,
  `.toml` and for `.clinerules/*.md`; `SCREAMING_SNAKE_CASE` for root-level docs; LF line endings and
  2-space indentation everywhere (see `.editorconfig` and `.lintrc/general/.ls-lint.yml`).
- **Language conventions.** Repository documentation is Chinese-first, git commit messages and this
  rule file are English, and the PR template is bilingual.
- **All changes go through feature branches.** Never commit or push to `MyFrps`. See
  `.clinerules/git-workflow.md` for the complete git workflow rules.
