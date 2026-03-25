# 开发日志 002

承接 `development_log_001.md`；当单份日志接近 `500` 行时，从本文件继续记录。

## 2026-03-24 第 29 轮
分支: `auto/gameplay_update`
范围: 主菜单 bug sweep，收口地图交互、回合卡死护栏和存读档 UX
变更:
- 新建了 `bug_audit_2026-03-24.md`，把主菜单、地图交互、回合推进和存读档 UX 的高优先级问题统一列成修复台账。
- `save_manager.gd` 从单槽升级成 3 槽位存档，并保留旧 `user://cent_jours_save.json` 的兼容读取；`main_menu.gd` 顶栏补上 `新局`，`存档 / 读档` 改成槽位选择弹窗。
- `turn_manager.gd` 的 `submit_action()` 现在会返回成功/失败；`main_menu.gd` 在行动提交失败时会恢复交互，读档后也会强制回到 `action` 阶段，补上“增加军费后卡在结算中”的 UI 防呆链。
- 地图交互拆成两层：hover 改成顶部小预览，click 才打开锁定详情；`main_menu.tscn`、`layout_controller.gd`、`map_controller.gd` 同时收口了详情面板宽度、滚动、最小内容宽度和 hover / click 分层逻辑。
- 地图现在支持 `MapScroll + 滚轮缩放 + 右键复位`，用 scroll 容器承接高密节点区的查看需求；前 10 天教程重复、地图副标题重复、动作按钮语义不清也在这轮一起清了。
验证:
- Windows Godot 无头主项目已通过两次，确认主菜单脚本链和场景节点结构可以正常加载。
- Windows Godot smoke scene 已通过，确认行动提交 -> 结算 -> 次日这条关键主循环链仍可运行。
- Windows GUI 启动冒烟已通过，主项目能正常打开并存活至少 5 秒，没有出现启动即崩的 UI 结构错误。
- 本轮未运行 Linux / WSL 侧测试。
提交/推送:
- 本轮将以主菜单 bug sweep 独立提交并推送到 `auto/gameplay_update`。
下一步:
- 回到玩法主线，继续把区域运营从“知道哪里承压”推进到“知道这一段区域该怎么经营和回收收益”。
