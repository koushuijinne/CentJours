#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEV_PLAN = ROOT / "docs/plans/dev_plan.md"
HANDOFF = ROOT / "docs/history/agent_handoff.md"

TASK_ROW_RE = re.compile(
    r"^\|\s*(S\d-\d+)\s*\|\s*(.+?)\s*\|\s*(P\d)\s*\|\s*([SMLX]+)\s*\|\s*(.+?)\s*\|$"
)


def load_tasks() -> list[dict[str, str]]:
    tasks: list[dict[str, str]] = []
    current_section = ""
    for raw_line in DEV_PLAN.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("### "):
            current_section = line.removeprefix("### ").strip()
            continue
        match = TASK_ROW_RE.match(raw_line)
        if not match:
            continue
        task_id, title, priority, scale, detail = match.groups()
        tasks.append(
            {
                "id": task_id,
                "title": title,
                "priority": priority,
                "scale": scale,
                "detail": detail,
                "section": current_section,
            }
        )
    return tasks


def priority_rank(priority: str) -> int:
    try:
        return int(priority.removeprefix("P"))
    except ValueError:
        return 99


def infer_focus_keywords(focus: str) -> list[str]:
    focus_map = {
        "harness": ["harness", "验证链", "GdUnit4", "GitHub Actions", "CI", "文档同步"],
        "gameplay": ["教程", "行动", "地图", "结局", "百科", "设置"],
        "content": ["历史事件", "文本", "教程", "百科"],
    }
    return focus_map.get(focus, [])


def score_task(task: dict[str, str], focus: str) -> tuple[int, int, int]:
    section_bonus = 0
    if task["section"].startswith("阶段 0"):
        section_bonus = -20
    elif task["section"].startswith("阶段 1"):
        section_bonus = -10

    focus_bonus = 0
    haystack = f"{task['title']} {task['detail']} {task['section']}"
    for keyword in infer_focus_keywords(focus):
        if keyword in haystack:
            focus_bonus -= 15

    if focus == "harness" and ("Codex harness" in haystack or "harness engineering" in haystack):
        focus_bonus -= 30
    if focus == "gameplay" and task["section"].startswith("阶段 1"):
        focus_bonus -= 10
    if focus == "content" and "历史事件" in haystack:
        focus_bonus -= 20

    completed_penalty = 0
    if "已完成" in task["detail"]:
        completed_penalty = 100

    return (
        priority_rank(task["priority"]) * 10 + section_bonus + focus_bonus + completed_penalty,
        {"S": 0, "M": 1, "L": 2, "XL": 3}.get(task["scale"], 9),
        int(task["id"].split("-")[1]),
    )


def extract_handoff_priorities() -> list[str]:
    lines = HANDOFF.read_text(encoding="utf-8").splitlines()
    result: list[str] = []
    in_block = False
    for raw_line in lines:
        line = raw_line.strip()
        if line == "## 当前最高优先级":
            in_block = True
            continue
        if in_block and line.startswith("## "):
            break
        if in_block and re.match(r"^\d+\.\s", line):
            result.append(line)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Pick the next Codex task from dev_plan and handoff.")
    parser.add_argument("--focus", default="any", help="Task focus: harness / gameplay / content / any")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output JSON")
    args = parser.parse_args()

    tasks = load_tasks()
    ranked = sorted(tasks, key=lambda task: score_task(task, args.focus))
    next_task = ranked[0] if ranked else {}

    payload = {
        "focus": args.focus,
        "handoff_priorities": extract_handoff_priorities(),
        "selected_task": next_task,
        "top_candidates": ranked[:5],
    }

    if args.as_json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print("Codex next task")
        print(f"Focus: {args.focus}")
        for item in payload["handoff_priorities"]:
            print(f"Handoff: {item}")
        if next_task:
            print(
                f"Selected: {next_task['id']} | {next_task['title']} | "
                f"{next_task['priority']} | {next_task['section']}"
            )
            print(f"Detail: {next_task['detail']}")
        print("\nTop candidates:")
        for task in payload["top_candidates"]:
            print(
                f"  - {task['id']} | {task['title']} | {task['priority']} | "
                f"{task['section']}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
