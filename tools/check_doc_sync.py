#!/usr/bin/env python3
"""Fail CI when code changes are not accompanied by documentation updates."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


CODE_PREFIXES = (
    "src/",
    "cent-jours-core/",
    "tests/",
    "tools/",
    ".github/workflows/",
)
DOC_PREFIXES = (
    "docs/",
    "README.md",
)


def run_git_diff(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def run_git_show(commitish: str) -> list[str]:
    result = subprocess.run(
        ["git", "show", "--format=", "--name-only", commitish],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def load_event_payload() -> dict:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path:
        raise RuntimeError("GITHUB_EVENT_PATH is not set.")
    return json.loads(Path(event_path).read_text(encoding="utf-8"))


def changed_files_from_ci() -> list[str]:
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    payload = load_event_payload()

    if event_name == "pull_request":
        base = payload["pull_request"]["base"]["sha"]
        head = payload["pull_request"]["head"]["sha"]
        return run_git_diff(base, head)

    if event_name == "push":
        before = payload.get("before", "")
        after = payload.get("after", "HEAD")
        if before and set(before) != {"0"}:
            return run_git_diff(before, after)
        return run_git_show(after)

    return run_git_show("HEAD")


def is_code_path(path: str) -> bool:
    return path.startswith(CODE_PREFIXES)


def is_doc_path(path: str) -> bool:
    return path.startswith(DOC_PREFIXES) or path == "README.md"


def classify(paths: list[str]) -> tuple[list[str], list[str]]:
    code_files = [path for path in paths if is_code_path(path)]
    doc_files = [path for path in paths if is_doc_path(path)]
    return code_files, doc_files


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="Git diff base revision")
    parser.add_argument("--head", help="Git diff head revision")
    parser.add_argument(
        "--files",
        nargs="*",
        default=None,
        help="Explicit changed file list for local validation",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.files is not None:
        changed_files = [path for path in args.files if path]
    elif args.base and args.head:
        changed_files = run_git_diff(args.base, args.head)
    else:
        changed_files = changed_files_from_ci()

    code_files, doc_files = classify(changed_files)

    print("Changed files:")
    for path in changed_files:
        print(f"  - {path}")

    if not code_files:
        print("No code paths changed. Doc sync check passes.")
        return 0

    if doc_files:
        print("Code and documentation changed together. Doc sync check passes.")
        return 0

    print("Code paths changed without updating README.md or docs/.", file=sys.stderr)
    print("Changed code paths:", file=sys.stderr)
    for path in code_files:
        print(f"  - {path}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
