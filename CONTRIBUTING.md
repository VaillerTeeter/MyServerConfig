# 贡献指南

感谢你有兴趣为本项目做出贡献！

---

## 开始之前

- 请先阅读 [行为准则](./CODE_OF_CONDUCT.md)
- 查看现有的 [Issues](https://github.com/VaillerTeeter/MyServerConfig/issues) 和 [Pull Requests](https://github.com/VaillerTeeter/MyServerConfig/pulls) 以避免重复工作

---

## 本地开发环境

```bash
# Fork 本仓库到你的账号，然后克隆
git clone https://github.com/<your-username>/MyServerConfig.git
cd MyServerConfig
```

---

## 提交流程

本仓库所有变更必须通过 Pull Request 合并，**禁止直接 push 到 `MyFrps`**。

```bash
# 1. 基于 MyFrps 创建功能分支
git checkout MyFrps
git pull origin MyFrps
git checkout -b feat/your-feature-name

# 2. 完成修改，提交
git add .
git commit -m "feat: describe your change"

# 3. 推送
git push origin feat/your-feature-name

# 4. 创建 PR（需先写 body 文件，等待确认后再执行）
# 参考 .clinerules/git-workflow.md 中的 PR Workflow 规范
# a. 将 PR body 写入 tmp/pr-<number>-body.md（按 .github/PULL_REQUEST_TEMPLATE.md 填写）
# b. 确认内容后执行：
gh pr create --title "标题" --body-file tmp/pr-<number>-body.md --base MyFrps
```

---

## Commit 消息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

| 前缀 | 用途 |
| --- | --- |
| `feat:` | 新功能 |
| `fix:` | Bug 修复 |
| `docs:` | 文档变更 |
| `chore:` | 构建/工具/配置等杂项 |
| `refactor:` | 重构（不新增功能，不修复 Bug） |
| `style:` | 代码格式调整（不影响逻辑） |
| `test:` | 添加或修改测试 |

示例：`feat: add Python example code`

---

## Pull Request 要求

- 标题清晰描述改动内容
- 填写 PR 模板中的所有必填项
- 关联对应的 Issue（如有）
- 确保本地无明显错误后再提交

---

## 问题和讨论

如有疑问，欢迎通过 [Issue](https://github.com/VaillerTeeter/MyServerConfig/issues/new/choose) 或 [邮件](mailto:wyc_19533480830@outlook.com) 联系。
