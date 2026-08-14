# 模块实现要点（实际代码）

本章按**当前实现**（v0.12）列出每个模块的类结构、关键 API 与职责边界。所有"数据类"为纯数据（RefCounted），"系统类"为普通 Node（由 GameManager 持有），UI 只负责渲染。

## 一、Autoload 单例（project.godot [autoload]）

| 单例 | 文件 | 职责 |
|---|---|---|
| EventBus | `src/autoload/EventBus.gd` | 全局信号中枢（day_changed / hour_changed / money_changed / toast / map_updated 等） |
| GameManager | `src/autoload/GameManager.gd` | 全局状态（资金/声誉/天数/车队/网络/订单）+ 模拟循环（advance_hour / advance_day）+ 借贷 |
| TimeSystem | `src/autoload/TimeSystem.gd` | 小时制时间推进（1 游戏小时 = 6 真实秒），倍速 0/1/2/4 |
| SaveManager | `src/autoload/SaveManager.gd` | 多槽位存档 / 读取 / 删除 |
| RegionManager | `src/autoload/RegionManager.gd` | 区域加载 / 切换 / 城市查询 / 米制坐标 |
| Localization | `src/autoload/Localization.gd` | 中英双语（strings.json），`t(key)` 取文案 |
| UI | `src/ui/widgets.gd` | 主题样式工厂（card / info_row / stat_tile / 图标按钮） |
| Tooltips | `src/ui/Tooltips.gd` | 图标悬浮提示（CanvasLayer 200） |
| Assets | `src/autoload/Assets.gd` | 图标/贴图资源表 |
| AudioManager | `src/autoload/AudioManager.gd` | BGM/SFX 总线与音量持久化 |

## 二、核心数据类（src/core/，均为 RefCounted）

| 类 | 说明 |
|---|---|
| `City` | 城市（经纬度/人口/需求/港口标志/首都） |
| `Region` | 区域（城市列表 + OSRM 路线矩阵懒加载 + `route_between()`） |
| `Vehicle` | 车辆（车型/载重/速度/能力位/`owned`/折线行程状态） |
| `Hub` / `Station` | 中转仓 / 站点（绑定城市，等级/容量） |
| `Order` | 订单（端点城市/货种/重量/奖励/时限/状态机） |
| `Staff` / `TechNode` | 员工 / 科技节点 |
| `CargoType` | 货种枚举 + 倍率/能力位 |
| `GeoMath` | 静态地理工具（Haversine / 等距圆柱投影 / 24h 用时） |

## 三、系统类（src/systems/，由 GameManager 在 advance_day 内驱动）

| 系统 | 职责 |
|---|---|
| `OrderSystem` | 订单生成（**站点门控**）/ 奖励 / 派单（自动+手动）/ 超时判定 |
| `VehicleSystem` | 购置/租赁/出售/退租 + 折线行程推进（24h） |
| `HubSystem` / `StationSystem` | 建仓/建站/升级/营销升级（价格 60 万/20 万） |
| `FinanceSystem` | 每日成本结算（维护/日租/利息）+ 流水 |
| `MarketingSystem` | 宣传推广（提升城市需求） |
| `StaffSystem` | 招聘与效率 |
| `TechSystem` | 科技树解锁 |
| `CompetitorSystem` | AI 对手出现/扩张/促销/市占蚕食 |
| `EventSystem` | 全局事件 + 区域特色事件 |
| `AchievementSystem` | 成就判定（12 项） |
| `TutorialSystem` | 生涯剧情 beat（8 段，数据驱动） |

## 四、模拟循环（GameManager）

```gdscript
# 每帧（TimeSystem 驱动）：推进小时
func tick_frame(delta_hours: float) -> void:   # 车辆沿折线移动
func advance_hour() -> void:                    # hour_of_day += 1，满 24 触发 advance_day
func advance_day() -> void:
    day += 1
    event_sys.process_day(self)       # 事件（可能改需求/价格）
    marketing_sys.process_day(self)
    order_sys.process_day(self)       # 生成订单 + 自动派单
    hub_sys.process_day(self)
    station_sys.process_day(self)
    staff_sys.process_day(self)
    finance_sys.process_day(self)     # 维护/日租/利息
    competitor_sys.process_day(self)
    _check_game_over()
    EventBus.day_changed.emit(day)
    _sync_all()                       # 成就检查 + 自动存档
```

## 五、UI 架构（表现/逻辑分离）

```
GameScene（主场景，只做布局与渲染）
├── dialogue_layer (CanvasLayer 30)     # 对白框（最高层，不被 UI 遮挡）
├── hud_layer (CanvasLayer 25)          # 目标 HUD / 成就横幅
├── pause_layer (CanvasLayer 60)        # 暂停菜单 / 确认弹窗
└── 主 UI VBox（顶栏 + 左 tab 栏 + 中央面板 + 底栏日志）
```

- **状态全在 GameManager**，面板只读状态渲染；操作通过 EventBus 信号回写。
- 左 tab 栏四组（运营/设施/发展/管理），中央面板切换渲染（总览/订单/车辆/网络/财务/科技…）。
- 独立全屏页：Settings / About（进入自动暂停，返回恢复原倍速）。

## 六、信号约定（EventBus）

```gdscript
signal day_changed(day: int)
signal hour_changed(hour: int)
signal money_changed(money: int)
signal debt_changed(debt: int)
signal reputation_changed(rep: float)
signal toast(text: String)
signal map_updated
signal vehicles_changed
signal orders_changed
signal stations_changed
signal hubs_changed
signal company_ready
```

- 系统间通信统一走 EventBus，避免相互引用耦合。
- 地图重绘由 `map_updated` / `vehicles_changed` 触发 `queue_redraw()`。

## 七、常见坑位提醒（Godot 4.x）

1. **Godot 4.7 类型推断**：`var x := min(...)` / `max(...)` / 复杂表达式返回 Variant 会 Parse Error → 显式 `var x: int = mini(...)`。
2. **CanvasLayer 层级**：后添加的子节点绘制在上层——对白等浮层必须挂到更高 layer 的 CanvasLayer，否则被主 UI 遮挡。
3. **anchors 设置顺序**：`set_anchors_and_offsets_preset` 需在 `add_child` **之后**调用才生效。
4. **Label 无 bbcode**：Godot 4 只有 `RichTextLabel` 支持 BBCode（`bbcode_text`）；`Label.bbcode_enabled` 是 Godot 3 API。
5. **typed Array 从 JSON 读回**：`Array[String]` 直接赋值 JSON 数组报类型错，需逐项 append。
6. **_ready 内换场景**：直接 `change_scene_to_file` 卸载自身报 busy 错误 → 用 `call_deferred`。
7. **绘制裁剪**：`_draw` 内容默认溢出，需 `clip_contents = true` 防止画到相邻 UI。
