#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "tools/codex_validation_map.json"


def load_config() -> dict[str, object]:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


CONFIG = load_config()
WINDOWS_GODOT = CONFIG["windows_godot"]
FILE_SETS = {name: set(paths) for name, paths in CONFIG["file_sets"].items()}
GDUNIT_TARGETS = CONFIG["gdunit_targets"]


def gdunit_command(target_key: str) -> str:
    return fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} {GDUNIT_TARGETS[target_key]}"


WINDOWS_HEADLESS_BOOT = CONFIG["headless_boot"].format(windows_godot=WINDOWS_GODOT)


def unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def classify(files: list[str]) -> dict[str, object]:
    buckets = {
        "docs_only": True,
        "rust": False,
        "rust_gdext": False,
        "godot_ui": False,
        "godot_project": False,
        "godot_tests": False,
        "ci_or_harness": False,
        "python_tools": False,
        "shell_tools": False,
        "heavy_validation": False,
    }

    local_checks: list[str] = ["python3 tools/check_doc_sync.py --files <changed_files>"]
    cloud_lanes: list[str] = []
    notes: list[str] = []

    for file_path in files:
        normalized = file_path.replace("\\", "/")
        path = Path(normalized)

        if normalized != "README.md" and not normalized.startswith("docs/"):
            buckets["docs_only"] = False

        if path.suffix == ".py":
            buckets["python_tools"] = True
            local_checks.append("python3 -m py_compile <changed_python_files>")

        if path.suffix == ".sh" or normalized.startswith(".githooks/"):
            buckets["shell_tools"] = True
            local_checks.append("bash -n <changed_shell_files>")

        if normalized.startswith(".github/workflows/") or normalized.startswith("tools/codex_"):
            buckets["ci_or_harness"] = True
            cloud_lanes.append("windows-fast")
            notes.append("CI / harness 改动至少观察一轮 windows-fast。")

        if normalized.startswith("cent-jours-core/src/") or normalized.startswith("cent-jours-core/tests/"):
            buckets["rust"] = True
            local_checks.append("cargo fmt --check --manifest-path cent-jours-core/Cargo.toml")
            cloud_lanes.extend(["windows-fast", "windows-full"])
            notes.append("Rust 改动至少过对应模块的定向 cargo test 或 windows-full。")

        if normalized == "cent-jours-core/src/lib.rs":
            buckets["rust_gdext"] = True
            local_checks.append("cargo build --features godot-extension")
            notes.append("`lib.rs` 改动至少验证一次 GDExt 构建。")

        if normalized.startswith("src/") and path.suffix in {".gd", ".tscn", ".tres"}:
            buckets["godot_ui"] = True
            cloud_lanes.extend(["windows-fast", "windows-full"])
            notes.append("Godot UI / 场景改动至少过核心 GdUnit4 与 headless boot。")

        if normalized in FILE_SETS["main_menu"]:
            local_checks.append(gdunit_command("main_menu"))

        if normalized in FILE_SETS["dialogs"]:
            local_checks.extend([gdunit_command("dialogs"), gdunit_command("settings")])

        if normalized in FILE_SETS["map"]:
            local_checks.extend([gdunit_command("map"), gdunit_command("main_menu")])

        if normalized in FILE_SETS["save_flow"]:
            local_checks.extend([gdunit_command("save_flow"), gdunit_command("main_menu")])

        if normalized == "project.godot":
            buckets["godot_project"] = True
            cloud_lanes.extend(["windows-fast", "windows-full"])
            notes.append("`project.godot` 改动需要观察 Windows headless boot。")

        if normalized.startswith("tests/godot/"):
            buckets["godot_tests"] = True
            cloud_lanes.extend(["windows-fast", "windows-full"])
            local_checks.append(
                fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} res://{normalized}"
            )

        if "monte_carlo" in normalized or "proptest" in normalized:
            buckets["heavy_validation"] = True
            cloud_lanes.append("windows-heavy-nightly")
            notes.append("Monte Carlo / 属性测试改动应观察 heavy-nightly。")

    if buckets["godot_ui"] or buckets["godot_project"] or buckets["godot_tests"]:
        local_checks.extend([
            "Windows 定向 GdUnit4（按改动模块选择）",
            WINDOWS_HEADLESS_BOOT,
        ])

    if buckets["rust"] and not buckets["rust_gdext"]:
        local_checks.append("Rust 最小本地验证：按需定向 cargo test 或交给 windows-full")

    if not cloud_lanes:
        cloud_lanes.append("doc-sync only")

    return {
        "files": files,
        "buckets": buckets,
        "local_checks": unique(local_checks),
        "cloud_lanes": unique(cloud_lanes),
        "notes": unique(notes),
    }


def print_text(result: dict[str, object]) -> None:
    print("Codex validation scope")
    print(f"Changed files: {len(result['files'])}")
    for file_path in result["files"]:
        print(f"  - {file_path}")

    print("\nBuckets:")
    for key, value in result["buckets"].items():
        print(f"  - {key}: {'yes' if value else 'no'}")

    print("\nRecommended local minimum checks:")
    for check in result["local_checks"]:
        print(f"  - {check}")

    print("\nRecommended cloud lanes:")
    for lane in result["cloud_lanes"]:
        print(f"  - {lane}")

    notes = result["notes"]
    if notes:
        print("\nNotes:")
        for note in notes:
            print(f"  - {note}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Classify changed files into Codex validation scope.")
    parser.add_argument("files", nargs="+", help="Changed files")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output JSON")
    args = parser.parse_args()

    result = classify(args.files)
    if args.as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print_text(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
