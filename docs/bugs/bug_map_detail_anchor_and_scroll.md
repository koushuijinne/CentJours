# BUG-2026-03-27-MAP-DETAIL-ANCHOR

## 标题

地图 hover 预览与锁定详情位置跳变，长文本详情缺少稳定滚动护栏

## 级别

P1

## 状态

已修复

## 来源

- [docs/bugs/bugs_check.md](/mnt/e/projects/CentJours/docs/bugs/bugs_check.md)
- Windows 真机截图：`image1.png`、`image2.png`

## 现象

- hover 预览与点击后的锁定详情出现在不同位置，切换时跳变明显。
- 节点史实、补给说明较长时，玩家会感觉底部内容被“吃掉”，难以判断是否还能继续阅读。

## 根因

- `MapHoverPanel` 与 `MapInspectorPanel` 采用了两套不同的响应式尺寸和偏移量。
- 详情层虽然已经有 `ScrollContainer`，但几何契约没有被测试锁住，后续布局调整很容易再次漂移。

## 修复

- 在 [layout_controller.gd](/mnt/e/projects/CentJours/src/ui/main_menu/layout_controller.gd) 中统一 hover 与 inspector 的右上展示锚点、尺寸和顶部偏移。
- 在 [main_menu.tscn](/mnt/e/projects/CentJours/src/ui/main_menu.tscn) 中显式固定 `MapHoverScroll` 与 `MapInspectorScroll` 的滚动模式。
- 在 [map_controller_contract_test.gd](/mnt/e/projects/CentJours/tests/godot/map_controller_contract_test.gd) 中新增回归，锁住：
  - hover / inspector 共用同一右上展示锚点
  - 两层都保留纵向滚动容器
  - 横向滚动保持禁用

## 回归

- Windows `GdUnit4`
- Windows Godot headless 主项目
- Windows Godot smoke scene

## 备注

- 这条 bug 解决的是“展示契约漂移”，不是最终视觉 polish。字体、密度和信息优先级仍以 Windows 真机体验为准继续收口。
