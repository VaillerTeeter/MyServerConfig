---
description: "MyNginx project overview — production-grade nginx configuration reference repository. Always apply."
globs: ""
alwaysApply: true
---

# Project Identity

## Project Name & Purpose

MyNginx (`VaillerTeeter/MyServerConfig`, branch `MyNginx`) is a **production-grade Nginx
configuration reference repository**. Its deliverable is configuration and documentation: there is no application source
code, no package manager, no build step, and no runtime service owned by this repository.

## Nature

This is a **single-technology repository** — hand-written Nginx configuration plus the docs and lint
tooling that keep it correct. The substance of the project lives in these files:

| File | Size | Scope |
| --- | --- | --- |
| `nginx.conf` | ~695 lines | main / events / http contexts: worker tuning, buffers, timeouts, hash tables, logging, limit-req and limit-conn, gzip, proxy defaults, global TLS, then `include /etc/nginx/conf.d/*.conf` |
| `conf.d/sites/*.conf` | one file per site | `upstream` keepalive pool, HTTP to HTTPS redirect, HTTPS server, error pages, and the per-site differences (streaming buffer and timeout tuning, admin panel hardening); loaded only when listed in `conf.d/sites.conf` |

Every directive is preceded by an explanatory Chinese comment block that states its type, scope,
default value and the reasoning (performance or security trade-off) behind the chosen value.
**Those comments are the deliverable, not decoration** — never delete, shorten or translate them.

## Intentional Placeholders

The repository is meant to be reusable as an example, so every environment-specific value is
deliberately fake. Keep it that way:

- Domain name: `example.example.example` (subdomains reuse the same placeholder, e.g.
  `stream.example.example.example`)
- Upstream address and port: loopback with a numeric placeholder port, e.g. `127.0.0.1:7500`
  (a non-numeric port such as `xxxx` fails `nginx -t`)
- TLS material: a self-signed example chain under `conf.d/cert/example/`, committed on purpose

Never commit a real hostname, IP address, port or credential into this repository. The single
exception is the self-signed example material under `conf.d/cert/example/`.

## Third-party Submodule

`conf.d/error/` is a git submodule pointing at `tarampampam/error-pages` (branch `gh-pages`). It
holds generated error pages (11 themes x 20 status codes, 221 HTML files, about 14 MB) served by the
`location /error` block. Treat it as read-only: never edit files inside it, update the submodule
pointer instead. It is excluded from every lint check, and `.clineignore` keeps it out of the agent
context.

## Repository Layout

```text
.
├── .clineignore                          # agent context exclusions: conf.d/error, TLS material, logs
├── .clinerules/                          # Cline rules: this file and git-workflow.md
│   ├── git-workflow.md                   # Cline git workflow rules (English)
│   └── project-identity.md               # this file
├── .editorconfig                         # charset / EOL / indent: 4 spaces for .conf, 2 elsewhere
├── .gitignore                            # ignores logs and TLS material (except conf.d/cert/example)
├── .gitmodules                           # declares the conf.d/error submodule
├── .github/                              # GitHub community files and CI metadata
│   ├── dependabot.yml                    # weekly GitHub Actions dependency updates
│   ├── PULL_REQUEST_TEMPLATE.md          # PR template (bilingual; every section required)
│   ├── docs/                             # project documentation
│   │   └── ci/                           # CI documentation
│   │       └── ci-checks.md              # CI check reference (Chinese)
│   ├── ISSUE_TEMPLATE/                   # issue templates (bilingual)
│   │   ├── bug_report_en.md
│   │   ├── bug_report_zh.md
│   │   ├── config.yml                    # issue template chooser configuration
│   │   ├── feature_request_en.md
│   │   └── feature_request_zh.md
│   ├── scripts/                          # automation scripts
│   │   └── ai-review.mjs                 # AI review script behind the /review command
│   └── workflows/                        # GitHub Actions workflows
│       ├── lint.yml                      # the only lint workflow: 12 check jobs plus a gate
│       └── review-command.yml            # trigger for the /review PR command
├── .lintrc/                              # one config per job in lint.yml
│   ├── data-formats/                     # structured data format configs
│   │   └── yaml/                         # YAML schemas
│   │       └── issue-config.schema.json  # JSON Schema for ISSUE_TEMPLATE/config.yml
│   ├── docs/                             # documentation tooling
│   │   └── markdown/                     # Markdown tooling
│   │       └── .markdownlint.json        # markdownlint rules
│   ├── frontend/                         # frontend tooling
│   │   └── prettier/                     # Prettier
│   │       └── .prettierrc               # Prettier config (mjs / cjs / yaml / json / md)
│   ├── general/                          # general purpose checks
│   │   ├── .ls-lint.yml                  # file and directory naming rules
│   │   ├── .yamllint.yml                 # YAML rules
│   │   └── cspell.json                   # spelling word list and dictionaries
│   ├── git/                              # git related checks
│   │   └── .commitlintrc.cjs             # Conventional Commits validation
│   ├── infrastructure/                   # infrastructure tooling
│   │   └── nginx/                        # nginx tooling
│   │       └── gixy.conf                 # gixy (nginx security scanner) configuration
│   └── security/                         # security checks
│       ├── .gitleaks.toml                # secret scanning rules
│       └── .semgrep.yml                  # SAST rules (nginx config and workflows)
├── .vscode/                              # VS Code workspace configuration
│   ├── extensions.json                   # recommended extensions
│   └── settings.json                     # workspace settings, pointing at the .lintrc configs
├── conf.d/                               # virtual host configuration snippets
│   ├── cert/                             # TLS material; git-ignored except example/
│   │   └── example/                      # self-signed example chain (committed on purpose)
│   │       ├── example.example.example.key
│   │       ├── example.example.example_bundle.crt
│   │       └── example.example.example_bundle.pem
│   ├── error/                            # git submodule: error-pages (gh-pages, read-only)
│   │   ├── .nojekyll
│   │   ├── index.html                    # theme index page
│   │   ├── app-down/
│   │   ├── cats/
│   │   ├── connection/
│   │   ├── ghost/
│   │   ├── hacker-terminal/
│   │   ├── l7/
│   │   ├── lost-in-space/
│   │   ├── noise/
│   │   ├── orient/
│   │   ├── shuffle/
│   │   └── win98/                        # each of the 11 themes holds 20 status code pages (400-505)
│   ├── sites.conf                        # enable switchboard: only listed sites are loaded
│   ├── sites/                            # one file per site (not auto-included)
│   │   ├── default-server.conf           # fallback: unknown host 444 / TLS rejection
│   │   ├── frps.conf                     # frps web console reverse proxy
│   │   └── stream.conf                   # video streaming (Emby)
│   └── snippets/                         # fragments shared by the site files
│       ├── error-pages.conf              # serves the themed error pages (internal only)
│       └── redirect-to-https.conf        # listen 80 + 301 to HTTPS
├── logs/                                 # runtime log directory; only .gitkeep is tracked
│   └── .gitkeep                          # placeholder that keeps the directory in git
├── CODE_OF_CONDUCT.md                    # code of conduct
├── CONTRIBUTING.md                       # contribution guide
├── LICENSE                               # GPL-3.0
├── README.md                             # project readme
├── SECURITY.md                           # security policy and vulnerability reporting
├── docker-compose.yml                    # nginx service: host network, config and log mounts
└── nginx.conf                            # main Nginx configuration
```

## Key Rules

- **All validation runs in CI; do not build a local verification path.** Syntax, security, docs,
  naming, spelling, secret and SAST checks all run through `.github/workflows/lint.yml` on GitHub
  Actions, and the single required status check is the `All Lint Checks Passed` aggregate gate.
  Do not add local verification scripts, npm scripts, Makefiles or test suites; CI is the only
  validation path, and no local reproduction steps are documented.
- **Config paths are absolute on purpose.** `nginx.conf` includes `/etc/nginx/mime.types` and
  `/etc/nginx/conf.d/*.conf`, mirroring a container or package installation. Keep that convention.
- **`nginx -t` cannot run against the working tree directly.** The absolute includes do not exist
  locally and the bundled TLS material is only a self-signed example. CI copies the configuration to
  a temp directory, overwrites `conf.d/cert/example/example.example.example*` with a throwaway
  self-signed certificate and runs `nginx -t` inside the `nginx:alpine` image; see the Nginx section
  of `ci-checks.md` for the exact commands.
- **Credentials never enter the repository — with one deliberate exception.** `*.key`, `*.pem`,
  `*.crt` and `*.csr` are git-ignored everywhere, except the path-allowlisted example directory
  `conf.d/cert/example/`, which ships a self-signed sample so a fresh clone can start. Real
  certificates belong in another `conf.d/cert/<domain>/` directory and stay ignored; never place real
  material in the example directory, it is allowlisted in `.gitleaks.toml`.
- **One lint config, one CI job.** Every config under `.lintrc/<family>/` must have a matching job in
  `lint.yml` and an entry in the `all-checks` `needs` list. Adding a check means four things: the
  config file, the job, the `needs` entry, and a new section in `ci-checks.md`.
- **`.lintrc/**` is linted too.** Configuration files obey the same file-naming, whitespace and line
  ending, spelling, YAML and secret/SAST rules as the rest of the repository.
- **Naming and formatting are enforced.** kebab-case for `.conf`, `.yml`, `.yaml`, `.json`, `.mjs`,
  `.cjs`, `.html` and for `.clinerules/*.md`; `SCREAMING_SNAKE_CASE` for root-level docs; 4-space
  indentation and LF in `.conf` files, 2-space indentation elsewhere (see `.editorconfig` and
  `.lintrc/general/.ls-lint.yml`).
- **Language conventions.** Repository documentation is Chinese-first, git commit messages and this
  rule file are English, and the PR template is bilingual.
- **All changes go through feature branches.** Never commit or push to `MyNginx`. See
  `.clinerules/git-workflow.md` for the complete git workflow rules.
