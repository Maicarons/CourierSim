# CourierSim 项目长期笔记

## 项目定位

Godot 4 的 2D 像素卡通任天堂风快递公司模拟经营游戏。规划阶段已完成，见 docs/（VitePress 文档站）。

## 关键约定

- 首发韩国，扩展海南/越南/马来西亚；AGPL-3.0 许可。
- 地理数据方案复用 `G:\workspace\transroute`（TransRoute 物流大亨）：城市目录/Haversine/OSRM/Nominatim/Geofabrik。
- 坐标用等距圆柱投影 + 米制中间层，区域独立原点。
- 存档 JSON + 版本迁移 + 原子写，金额用整数分。
- 表现/逻辑分离，Autoload 单例管状态，场景只渲染。

## UI/UX v0.4.0 重构要点

- **图标驱动 + Tooltip**：`src/ui/Tooltips.gd` 是 Autoload（layer=200），任何 Control 调 `Tooltips.register(c, text)` 即可获得 0.32s 延迟、深棕黑+橙边、避屏翻折的悬浮提示。`UI.icon_only_button(icon, tooltip, cb, size=40)` 是 tab/工具栏核心组件；`icon_button(text, icon, cb, tooltip="")` / `primary_button(text, color, cb, tooltip="")` 也支持可选 tooltip。
- **UI 主题**（`src/ui/widgets.gd`）：INK（深棕描边）/ CREAM（卡片主）/ CREAM_2（次）/ ORANGE（标题/主操作）/ BLUE（信息）/ GREEN（开始/完成）/ YELLOW（提示/目标）/ RED（退出/失败）/ PURPLE（设置/扩展）/ SKY（地图天空）。统一通过 `_cartoon_style(fill, border, radius, pad)` 工厂生成粗描边+圆角+投影 StyleBoxFlat。
- **三段式布局**：顶栏（持久状态 + 工具栏）+ 左 tab 栏（图标+分组+tooltip）+ 中央（地图/列表）。GameScene 顶栏所有 chip 用 `stat_tile`，工具栏全 `icon_only_button`；tab 栏按"运营/设施/发展/管理"四组（`TAB_GROUPS`），tab 文字本地化 `tab.group.*`。
- **全屏独立页**：Settings 和 About 各自为独立 .tscn 场景（**不是**弹窗），从游戏进入自动 `TimeSystem.set_speed(0)` 暂停，返回时由 GameScene 自行决定。
- **生涯剧情系统** `src/systems/TutorialSystem.gd`：8 段数据驱动 beat（开场+7 条件触发），每段 `{id, speaker_key, icon, text_key, obj_key, cond: Callable}`。`GameManager.tutorial_step` 持久化（GameSave 已扩展）。沙盒模式自动禁用整套系统。
- **对白 UI** `src/ui/DialogueBox.gd`：底部分隔面板+头像+发言者+打字机（28 char/s）+「继续」。支持多行（\n 分段）逐句推进，事件期间半透明遮罩拦截地图。
- **真实地图数据管线**：
  - 数据源：Natural Earth 50m land（Public Domain）+ 区域 JSON（OSM 城市）
  - 烘焙：`tools/bake_land.py`（Sutherland-Hodgman 裁剪 + Douglas-Peucker 简化 → `<id>_land.json`）+ `tools/bake_terrain.py`（PIL 光栅化 + 像素噪声地形 → `<id>_terrain.png`）
  - 运行时：`MapView._load_land()` 一次性读取，零网络零计算成本
  - 玩法整合：点击城市→操作栏直接调 `hub_sys.build/upgrade` / `station_sys.build/upgrade_marketing`
- **音频总线** `src/autoload/AudioManager.gd`：自动创建 BGM/SFX 两条总线（汇入 Master），`set_bus_volume/get_bus_volume` 持久化到 `user://settings.cfg [audio]`。设置页可分别调 Master/BGM/SFX。
- **Godot 4.7 类型推断坑**：`var x := 复杂表达式` 中表达式若返回 Variant 会 Parse Error。修法：加显式类型 `var x: Type = 复杂表达式`。批量修用 `tools/fix_typing.py` 风格（key 用 forward slash，单行 substring replace）。

## 生涯评级 / 存档 / 竞争（v0.5）

- **评级**：`GameManager.rating()` = 声誉+市占+总资产三项打分（各 0~2 分）→ S(≥5)/A(≥4)/B(≥2)/C。`total_assets()` = 现金+车辆×0.8+仓级×5000+站×3000。
- **胜负**：`_check_game_over()` 现金<-5万破产；生涯 Day≥20 且评级 S/A 胜利。`game_over_emitted` 防重复，读档重置，`advance_day` 在结算后停止。
- **结算页**：`GameOver.tscn` 用 `GameOver.last_reason`（静态）接收原因，`GameManager.summary_dict()` 展示 8 项统计。从 GameScene `_on_game_over` 跳转。
- **多槽位**：`SaveManager.next_free_slot/has_slot/slot_label`；`GameManager.active_slot` 绑定当前槽位（new_game=autosave，load 自动绑定）；主菜单继续→槽位面板；新游戏写空闲槽位。
- **多对手**：`CompetitorSystem` 4 家对手池，每 15 天 1 家（最多 3），12% 促销事件；`player_share()=1−Σ对手`。FinancePanel 逐家展示。
- **无头回归**：`tools/smoke_test.tscn`（`godot --headless --path . res://tools/smoke_test.tscn --quit-after 300`）覆盖新游戏/资产/多对手/评级/槽位/破产/结算，全 PASS。

## 游戏体验层（v0.6）

- **暂停菜单** `PauseMenu.gd`：ESC 开关，打开暂停/关闭恢复原倍速；挂 CanvasLayer(60) 防 UI 重建清除；「主菜单」按钮弹 `ConfirmDialog` 确认。
- **确认弹窗** `ConfirmDialog.gd`：`ask(title,msg,cb)` 通用模态；删除存档/返回主菜单等误触风险操作复用。
- **成就** `AchievementSystem.gd` + `src/data/achievements.json`（12 项）：`_sync_all()` 自动 check，解锁→toast+`GameManager.achievements`（存档）；设置页「成就」tab 展示。**typed Array 从 JSON 读回需逐项 append**（`Array[String]` 直接赋值报类型错）。
- **竞争模型**：开局 1 家初始对手（share≈0.5+），玩家以挑战者起步；对手扩张受交付压制；教程 share 节需 ≥2/≥3 对手；市占成就门槛 45%。
- **导出** `export_presets.cfg`（Windows/Linux x86_64）；`.gitignore` 含 `build/`。
- **新 class_name 注册**：新增 .gd 的 class_name 首次引用报 "Could not find type" → 先跑 `godot --headless --import` 重建类名缓存。

## 数值平衡（v0.7）与 headless 模拟铁律

- **headless 模拟车辆不动**：车辆移动由 TimeSystem 真实时间驱动（`SECONDS_PER_DAY=2.5`），手动 `advance_day()` 不推车队。模拟长局必须 `TimeSystem.set_speed(0)` + 每回合 `GameManager.tick_frame(1.0)` 显式推进。
- **市占模型**：对手份额若只增不减 → 玩家市占锁死 ~10%（评级/成就永不可达）。修法：玩家累计交付按比例蚕食对手（`delivered×0.0003` clamp 0.02）。
- **经济健康基准**（`tools/balance_sim.tscn` 120 天 AI 基准）：Day106 A 级通关、不破产、声誉 70+、市占 27→94% 弧线。
- **平衡调优记录**：compute_spawn 站点基数 0.8；deadline buffer 4/6；奖励 km×(2.2+0.12w)；超时 -1.5 / 交付 +1.5 声誉；VAN 620km/日；胜利 Day≥30。
- **数值平衡必须用长局模拟验证**，纯读码看不出涌现问题（AI 破产/市占天花板/声誉崩塌）。

## 工程化（v0.7）

- Git 仓库已初始化（`G:\GitHub\CourierSim`），首次提交 212 文件；`nul`（Windows 保留名）阻塞 git add 已删除。
- CI：`.github/workflows/test.yml` — Godot 4.6.3 Linux headless 启动 + smoke_test + balance_sim + VitePress build。
- README 反映真实结构（src/assets/comfyui/tools/docs）。

## 内容填充（v0.8）

- **能力矩阵**：`vehicles.json` cap 位 — 面包车 0 / 货车 4 / 冷藏车 3 / 无人机 0 / 飞机 15 / 货轮 15（CargoType.capability: STANDARD=0, COLDCHAIN=1, PHARMA=2, HAZMAT=4, INT=8）。
- **降级保护**：`spawn_one` 无对应能力车辆时特殊货降级为标准货（`_has_carrier` 检查）。
- **区域特色**：`region.json` 加 `features{demand_bonus, events[]}`；`EventSystem` 40% 抽区域事件池；`compute_spawn` 乘 demand_bonus。
- **沙盒参数**：`GameManager.sandbox_cfg{funds_mult, events, competition}`；MainMenu 沙盒模式显示参数区；竞争 0 时无初始对手。
- **胜利条件**：仅 rating()=="S" 且 Day≥40 通关（A 不结束）。

## 工具脚本

- `tools/bake_land.py` — 从 Natural Earth 50m land 烘焙区域陆地多边形 JSON
- `tools/bake_terrain.py` — PIL 光栅化多边形为卡通地形贴图 PNG
- `tools/merge_strings.py` / `merge_strings_v3.py` — 合并 strings.json 新键（中英）保留已有
- `tools/fix_typing.py` — Godot 4.7 严格类型推断兼容（显式类型标注）
- `tools/smoke_test.tscn` — 无头回归测试
- `comfyui/gen_ui_icons.py` / `gen_ui_icons_v2.py` — ComfyUI 批量生成像素图标

## 文档站

- `docs/` VitePress，构建/预览用 `npm run build` / `npm run dev`（vp.mjs 已清 NODE_OPTIONS）。
- 部署 GitHub Pages 时需在 config.ts 设 `base: '/CourierSim/'`。
- v0.4.0 新增顶级 nav「UI / UX」+ 三个新页面：ui-design.md / plugins.md / map/real-map.md / gameplay/career-tutorial.md。
