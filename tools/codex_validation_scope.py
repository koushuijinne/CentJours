#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

WINDOWS_GODOT = r"E:\software\godot\Godot_v4.6.1-stable_win64_console.exe"

MAIN_MENU_FILES = {
    "src/ui/main_menu.gd",
    "src/ui/main_menu.tscn",
    "src/ui/main_menu/tray_controller.gd",
    "src/ui/main_menu/topbar_actions_controller.gd",
    "src/ui/components/decision_card.gd",
}

DIALOG_FILES = {
    "src/ui/main_menu/dialogs_controller.gd",
    "src/core/settings_manager.gd",
}

MAP_FILES = {
    "src/ui/main_menu/map_controller.gd",
    "src/ui/main_menu/map_render_controller.gd",
    "src/ui/main_menu/layout_controller.gd",
    "src/ui/main_menu/sidebar_controller.gd",
    "src/ui/main_menu/ui_formatters.gd",
}

SAVE_FLOW_FILES = {
    "src/core/save_manager.gd",
    "src/core/game_state.gd",
    "src/core/turn_manager.gd",
    "src/core/event_bus.gd",
}

MAIN_MENU_GDUNIT = (
    fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} "
    r"res://tests/godot/main_menu_flow_test.gd"
)
DIALOG_GDUNIT = (
    fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} "
    r"res://tests/godot/dialog_flow_test.gd"
)
MAP_GDUNIT = (
    fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} "
    r"res://tests/godot/map_controller_contract_test.gd"
)
SAVE_GDUNIT = (
    fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} "
    r"res://tests/godot/save_load_flow_test.gd"
)
SETTINGS_GDUNIT = (
    fr"tools\run_gdunit_windows.cmd {WINDOWS_GODOT} "
    r"res://tests/godot/settings_manager_test.gd"
)
WINDOWS_HEADLESS_BOOT = (
    fr"{WINDOWS_GODOT} --headless --path E:\projects\CentJours --quit"
)


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

        if normalized in MAIN_MENU_FILES:
            local_checks.append(MAIN_MENU_GDUNIT)

        if normalized in DIALOG_FILES:
            local_checks.extend([DIALOG_GDUNIT, SETTINGS_GDUNIT])

        if normalized in MAP_FILES:
            local_checks.extend([MAP_GDUNIT, MAIN_MENU_GDUNIT])

        if normalized in SAVE_FLOW_FILES:
            local_checks.extend([SAVE_GDUNIT, MAIN_MENU_GDUNIT])

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
