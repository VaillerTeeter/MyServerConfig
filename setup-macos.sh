#!/usr/bin/env bash
set -euo pipefail

# 第一步：检查 Xcode Command Line Tools（xcode-select）是否已安装。
# xcode-select 命令本身几乎总在，真正会缺的是 Command Line Tools，
# 因此以 `xcode-select -p` 是否成功作为判断依据。
if ! xcode-select -p >/dev/null 2>&1; then
  echo "错误：未检测到 Xcode Command Line Tools（xcode-select）。" >&2
  echo "请在终端执行下面的命令，然后在弹出的 macOS 窗口中完成安装：" >&2
  echo "" >&2
  echo "    xcode-select --install" >&2
  echo "" >&2
  echo "安装完成后，重新运行本脚本。" >&2
  exit 1
fi

echo "OK: Xcode Command Line Tools 已就绪（$(xcode-select -p)）"

# 第二步：检查 Homebrew 环境，没有则用清华镜像安装，并把 brew 的源换成清华源。
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew，开始安装（使用清华镜像源）..."

  # 安装时使用的清华镜像环境变量
  export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  export HOMEBREW_INSTALL_FROM_API=1
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_PIP_INDEX_URL="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple"

  git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git brew-install
  # NONINTERACTIVE=1 让官方安装脚本跳过 “Press RETURN/ENTER to continue...” 之类的交互提示
  NONINTERACTIVE=1 /bin/bash brew-install/install.sh
  rm -rf brew-install

  # 将 brew 的源换为清华源（写入 ~/.zprofile）
  echo 'export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"' >> ~/.zprofile
  echo 'export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"' >> ~/.zprofile
  echo 'export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"' >> ~/.zprofile
  echo 'export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"' >> ~/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  source ~/.zprofile

  # 检查清华源是否设置成功
  brew config | grep -E "HOMEBREW_API_DOMAIN|HOMEBREW_BOTTLE_DOMAIN"
else
  echo "OK: Homebrew 已就绪（$(command -v brew)）"
fi

# 第三步：检查 Node.js（npm / pnpm 都依赖它），没有则用 brew 安装。
if ! command -v node >/dev/null 2>&1; then
  echo "未检测到 Node.js，开始安装（brew install node）..."
  # HOMEBREW_NO_ASK=1 关闭 Homebrew 7.x 默认的 ask 模式，避免出现 “Do you want to proceed ... [y/n]” 确认提示
  HOMEBREW_NO_ASK=1 brew install node
fi
echo "OK: Node.js 已就绪（$(node -v)）"

# 第四步：检查 npm（正常情况下随 Node 一起安装）。
if ! command -v npm >/dev/null 2>&1; then
  echo "错误：未检测到 npm（正常应随 Node 一起安装）。" >&2
  echo "请尝试重装 Node：brew reinstall node" >&2
  exit 1
fi
echo "OK: npm 已就绪（npm $(npm -v)）"

# 第五步：检查 pnpm，没有则通过 npm 全局安装。
if ! command -v pnpm >/dev/null 2>&1; then
  echo "未检测到 pnpm，开始安装（npm install -g pnpm）..."
  npm install -g pnpm
fi
echo "OK: pnpm 已就绪（pnpm $(pnpm -v)）"

# 第六步：用 src/skeleton 无条件覆盖 homepage 配置目录（先重建出“上游原样”的 config/）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEPAGE_DIR="${HOMEPAGE_DIR:-$SCRIPT_DIR/homepage}"
if [ ! -d "$HOMEPAGE_DIR/src/skeleton" ]; then
  echo "错误：未找到 homepage 源码（$HOMEPAGE_DIR/src/skeleton 不存在）。" >&2
  echo "请先：git submodule update --init --recursive" >&2
  exit 1
fi
CONFIG_DIR="${HOMEPAGE_CONFIG_DIR:-$HOMEPAGE_DIR/config}"
mkdir -p "$CONFIG_DIR"
cp -R "$HOMEPAGE_DIR"/src/skeleton/. "$CONFIG_DIR/"

# 第七步：若存在配置 patch，打到刚生成的 config/ 上（必须在覆盖之后，否则会被冲掉）。
PATCH_FILE="${HOMEPAGE_CONFIG_PATCH:-$SCRIPT_DIR/homepage-config.patch}"
if [ -f "$PATCH_FILE" ]; then
  echo "应用配置 patch：$PATCH_FILE"
  git -C "$HOMEPAGE_DIR" apply -p1 "$PATCH_FILE"
else
  echo "提示：未找到配置 patch（${PATCH_FILE}），config/ 保持上游 skeleton 原样。"
fi

# 第八步：构建 homepage 生产包（pnpm install + pnpm build，需在项目目录内执行）。
cd "$HOMEPAGE_DIR"
echo "安装依赖（pnpm install）..."
pnpm install
echo "构建生产包（pnpm build）..."
pnpm build
echo "OK: homepage 构建完成（${HOMEPAGE_DIR}）"

# 第九步：后台启动 homepage（nohup + 追加日志）；若已在运行则先停止再重启。
# 默认放行本机所有非回环 IPv4 + localhost（IP 变化时自动重新检测）；可用 HOMEPAGE_ALLOWED_HOSTS 覆盖。
cd "$HOMEPAGE_DIR"
LOG_DIR="${HOMEPAGE_LOG_DIR:-$SCRIPT_DIR/logs}"
LOG_FILE="$LOG_DIR/homepage.log"
PID_FILE="$LOG_DIR/homepage.pid"
PORT="${PORT:-3000}"
# 自动收集本机非回环 IPv4（IP 变化时下次启动会重新检测），据此放行对应 host:port。
# 可用环境变量 HOMEPAGE_ALLOWED_HOSTS 覆盖（例如追加域名，或用 * 放行全部，但不推荐）。
if [ -n "${HOMEPAGE_ALLOWED_HOSTS:-}" ]; then
  ALLOWED_HOSTS="$HOMEPAGE_ALLOWED_HOSTS"
else
  ALLOWED_HOSTS="localhost:${PORT},127.0.0.1:${PORT},[::1]:${PORT}"
  for ip in $(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.'); do
    ALLOWED_HOSTS="${ALLOWED_HOSTS},${ip}:${PORT}"
  done
fi
mkdir -p "$LOG_DIR"

# 判断某 PID 是否为本项目的 homepage 进程：存在 + 工作目录 == 本项目目录。
# （Next 16 会把进程名改成 "next-server (v16.3.8)"，命令行不含项目路径，故以 cwd 判定。）
# lsof 返回的是物理路径，故把项目目录也归一化为物理路径再比较（/var → /private/var 等符号链接）。
HOMEPAGE_DIR_REAL="$(cd "$HOMEPAGE_DIR" 2>/dev/null && pwd -P || printf '%s' "$HOMEPAGE_DIR")"
is_homepage_pid() {
  local pid="$1" cwd
  if [ -z "$pid" ]; then
    return 1
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
  if [ -n "$cwd" ] && [ "$cwd" = "$HOMEPAGE_DIR_REAL" ]; then
    return 0
  fi
  return 1
}

# 以“端口”为准找出正在运行的本项目实例（不依赖可能陈旧的 PID 文件）。
running_pids=""
if command -v lsof >/dev/null 2>&1; then
  for p in $(lsof -ti tcp:"$PORT" 2>/dev/null || true); do
    if is_homepage_pid "$p"; then
      running_pids="$running_pids $p"
    fi
  done
fi

if [ -n "$running_pids" ]; then
  echo "检测到 homepage 正在运行（PID:${running_pids}），执行重启..."
  kill $running_pids 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    still=""
    for p in $running_pids; do
      if kill -0 "$p" 2>/dev/null; then
        still="$still $p"
      fi
    done
    if [ -z "$still" ]; then
      break
    fi
    sleep 1
  done
  kill -9 $running_pids 2>/dev/null || true
else
  # 端口上没有本项目的实例：清理可能陈旧的 PID 文件（非本项目进程只清理、绝不误杀）。
  if [ -f "$PID_FILE" ]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if is_homepage_pid "$old_pid"; then
      echo "PID 文件登记的进程仍在运行（PID ${old_pid}），停止它..."
      kill "$old_pid" 2>/dev/null || true
    fi
  fi
  echo "未检测到运行中的 homepage，直接启动。"
fi
rm -f "$PID_FILE"

echo "后台启动 homepage（日志：${LOG_FILE}，追加模式）..."
{
  echo ""
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') 启动 homepage ====="
  echo "HOMEPAGE_ALLOWED_HOSTS=$ALLOWED_HOSTS"
} >> "$LOG_FILE"
HOMEPAGE_ALLOWED_HOSTS="$ALLOWED_HOSTS" nohup pnpm start >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "已启动（PID $(cat "$PID_FILE")）。访问：http://localhost:${PORT}"

# 部署后健康检查（/api/healthcheck 走 localhost 默认端口，可正常通过）
if command -v curl >/dev/null 2>&1; then
  for _ in 1 2 3 4 5; do
    if curl -fsS "http://localhost:$PORT/api/healthcheck" >/dev/null 2>&1; then
      echo "OK: 健康检查通过（http://localhost:${PORT}）"
      break
    fi
    sleep 1
  done
fi
