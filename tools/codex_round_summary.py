#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HANDOFF = ROOT / "docs/history/agent_handoff.md"
DEV_PLAN = ROOT / "docs/plans/dev_plan.md"


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, cwd=ROOT, text=True).strip()


def handoff_table() -> dict[str, str]:
    rows: dict[str, str] = {}
    table_re = re.compile(r"^\|\s*(.+?)\s*\|\s*(.+?)\s*\|$")
    for line in HANDOFF.read_text(encoding="utf-8").splitlines():
        match = table_re.match(line)
        if not match:
            continue
        key, value = match.groups()
        if key != "维度" and not set(key) <= {"-"}:
            rows[key] = value
    return rows


def current_priorities() -> list[str]:
    lines = HANDOFF.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    in_block = False
    for raw_line in lines:
        line = raw_line.strip()
        if line == "## 当前最高优先级":
            in_block = True
            continue
        if in_block and line.startswith("## "):
            break
        if in_block and re.match(r"^\d+\.\s", line):
            out.append(line)
    return out


def current_p0() -> list[str]:
    lines = DEV_PLAN.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    in_block = False
    for raw_line in lines:
        line = raw_line.strip()
        if line.startswith("## 当前 P0"):
            in_block = True
            continue
        if in_block and line.startswith("### "):
            break
        if in_block and line.startswith("- `P0"):
            out.append(line)
    return out


def main() -> int:
    summary = {
        "branch": run(["git", "branch", "--show-current"]),
        "head": run(["git", "rev-parse", "--short", "HEAD"]),
        "status_short": run(["git", "status", "--short"]) or "clean",
        "baseline": handoff_table(),
        "handoff_priorities": current_priorities(),
        "current_p0": current_p0()[:6],
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
