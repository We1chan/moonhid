#!/bin/zsh
set -eu
cd "${0:A:h}"
export PATH="$HOME/.moon/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

node_bin="$(command -v node || true)"
if [[ -z "$node_bin" && -x "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node" ]]; then
  node_bin="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
python_bin="$(command -v python3 || true)"
if [[ -z "$python_bin" && -x "$HOME/.local/bin/python3" ]]; then
  python_bin="$HOME/.local/bin/python3"
fi
if [[ -z "$node_bin" || -z "$python_bin" ]] || ! command -v moon >/dev/null; then
  print "需要 MoonBit 官方工具链、Node.js 22+ 和 Python 3。安装后再双击此文件。"
  read -r "?按回车关闭…"
  exit 1
fi

"$node_bin" scripts/build-web.mjs
if [[ "${MOONHID_NO_OPEN:-0}" == "1" ]]; then
  exec "$python_bin" scripts/serve-web.py
else
  exec "$python_bin" scripts/serve-web.py --open
fi
