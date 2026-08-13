# 生涯模式剧情引导

> 适用版本：v0.4.0+
> 设计目标：通过 8 段渐进式剧情对白 + 右上目标卡片，引导新玩家自然掌握游戏核心机制。

## 一、玩家体验流程

```
开始新游戏 → 选「生涯模式」
        │
        ▼
┌─────────────────────────────────────────┐
│ 🎬 开场剧情（无前置条件）               │
│ "快递王国" 旁白：背景故事               │
└─────────────────────────────────────────┘
        │
        ▼ 玩家继续经营
        │
┌─────────────────────────────────────────┐
│ 🎯 目标 #1：购置第一辆车              │
│ （车辆页签）                            │
└─────────────────────────────────────────┘
        │
        ▼ 玩家买车
        │
┌─────────────────────────────────────────┐
│ 🎬 庆祝剧情：金社长讲解自动接单       │
│ 🎯 目标 #2：完成首单配送（自动）       │
└─────────────────────────────────────────┘
        ...
```

## 二、数据驱动（TutorialSystem）

所有剧情节奏在 `src/systems/TutorialSystem.gd::_build()` 中声明：

| 字段 | 含义 |
|---|---|
| `id` | 节标识（内部） |
| `speaker_key` | 发言者（tut.speaker.narrator / tut.speaker.ceo） |
| `icon` | 立绘图标 id（如 `bld_hub`） |
| `text_key` | 多行对白（用 `\n` 分段） |
| `obj_key` | 目标追踪 HUD 文案 |
| `cond` | Callable：条件满足 → 触发该节对白 |

节序（首 → 尾）：

| # | id | 条件 |
|---|---|---|
| 1 | intro | 开场无条件 |
| 2 | buy_vehicle | `vehicles.size() > 0` |
| 3 | first_delivery | `orders.any(o.status == DELIVERED)` |
| 4 | build_hub | `hubs.size() > 1` |
| 5 | build_station | `stations.size() > 0` |
| 6 | hire_staff | `staff.size() > 0` |
| 7 | unlock_tech | `techs.any(unlocked)` |
| 8 | share10 | `player_share() >= 0.10` |
| 9 | share25 | `player_share() >= 0.25` → 自由经营 |

## 三、检查触发时机

`TutorialSystem.check()` 在以下事件后调用：

- `EventBus.vehicles_changed`
- `EventBus.hubs_changed`
- `EventBus.stations_changed`
- `EventBus.orders_changed`
- `EventBus.money_changed`
- `EventBus.day_changed`
- `EventBus.reputation_changed`
- MapView 状态变化（`_on_state_changed`）

`check()` 内部循环触发所有当前条件已满足的节（防止多节同时触发时漏掉）。

## 四、UI 集成

```
┌─────────────────────────────────────────┐
│                              🎯 当前目标 │
│ GameScene 右上                购置第一辆车│
│ （生涯模式）                             │
└─────────────────────────────────────────┘
```

- 点击目标卡 → 重看上一节剧情对白
- 沙盒模式：教程系统整体禁用，目标卡隐藏
- 存档：`GameManager.tutorial_step` 同步在 `GameSave.to_dict/from_dict`

## 五、对白 UI（DialogueBox）

- 屏幕下半部遮罩（点击穿透停止，避免误操作地图）
- 卡通描边面板 + 角色头像（图标 id）+ 发言者名字 + 打字机文本 + 「继续 ▸」
- 打字速度 28 字符/秒；点「继续」可一次显示整句
- 多行（`\n` 分隔）逐句推进；全部说完后回调 `on_closed`
- 进入动画：modulate alpha 0→1，0.22s

## 六、扩展剧情

新章节只需：
1. 在 `TutorialSystem._build()` 加 `_mk(...)` 一行
2. 在 `strings.json` 加 `tut.<id>_text` / `tut.obj.<id>` 中英两套
3. 在 Localization.t() 时用正确的 key

无需改 UI 代码，剧情数据与逻辑完全分离。