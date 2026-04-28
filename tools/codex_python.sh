#!/usr/bin/env bash
# 提供共享的 Python 解释器解析逻辑给 codex_*_guard 脚本使用。
# Windows 上 `python3` 常是 Microsoft Store 的占位 stub（未安装时直接 exit 9009），
# 因此按 PYTHON / python3 / python / py 顺序探测，并跳过 WindowsApps stub 路径。
# 用法：source tools/codex_python.sh; "$PY" 你的脚本 ...

resolve_python() {
  if [[ -n "${PYTHON:-}" ]]; then
    echo "${PYTHON}"
    return 0
  fi
  for cand in python3 python py; do
    if command -v "${cand}" >/dev/null 2>&1; then
      local resolved
      resolved="$(command -v "${cand}")"
      case "${resolved}" in
        */WindowsApps/*) continue ;;
      esac
      echo "${cand}"
      return 0
    fi
  done
  return 1
}

PY="$(resolve_python)" || {
  echo "找不到可用的 Python 解释器（尝试了 PYTHON / python3 / python / py）" >&2
  exit 1
}
export PY
