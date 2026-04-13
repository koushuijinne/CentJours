# Development Log 011 — i18n 字符串扩展 + events/pool.rs 拆分

> **日期**: 2026-04-13
> **分支**: `claude/review-project-status-05vxD`
> **任务**: S5-1 i18n 扩展 / 硬约束 #10 P2 拆分

## 本轮完成

### i18n 字符串扩展
- game_text.csv: 45→60+ 翻译键
- main_menu.gd 新增 tr() 调用：日期标签、托盘锁定提示（5 种）、卡片锁定文案（5 种）、行动预算提示（4 种）、确认按钮文案（3 种）、机动/决策禁用原因
- 总计约 25+ 处硬编码中文改为 tr() 调用

### events/pool.rs 拆分（P2，1313→370 行）
- 提取 `pool_tests.rs`（945 行）
- Rust 215/215 全通过

## 验证
- Rust: 215/215 ✓
- Godot headless: 通过 ✓
