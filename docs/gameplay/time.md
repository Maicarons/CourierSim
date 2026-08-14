# 时间系统（Time System）

> 适用版本：v0.12+ · 小时制 · 车辆 24 小时不间断运行

## 一、设计目标

真实物流是 24 小时流转的：干线车辆昼夜不停、站场三班倒。早期版本按"天"跳跃（1 游戏日 ≈ 2.5 真实秒），车辆像"按天瞬移"，既无沉浸感也让时限失去意义。v0.12 起改为**小时制**：

- **1 游戏小时 = 6 真实秒**（`TimeSystem.SECONDS_PER_HOUR = 6.0`，1 游戏日 = 144 真实秒）
- 车辆**全天候运行**（不再按 8 小时工作制折算，`daily_hours = 24`）
- 顶栏实时显示 `Day N HH:00`，让"几点发车、几点到"有了可读性

## 二、架构（TimeSystem Autoload）

```gdscript
# src/autoload/TimeSystem.gd（摘录）
const SECONDS_PER_HOUR := 6.0   # 1 游戏小时 = 6 真实秒
const SECONDS_PER_DAY := SECONDS_PER_HOUR * 24.0
const SPEEDS := [0, 1, 2, 4]    # 0 = 暂停

var speed_index: int = 1        # 默认 1x
var paused: bool = false
var current_day_fraction: float = 0.0   # 0..1，推进满 1 触发 advance_day
var total_days: float = 0.0
```

| 速度档 | 含义 | 1 游戏小时耗时 |
|---|---|---|
| 0（暂停） | 时间冻结，可查看面板/安排 | — |
| 1x | 标准流速 | 6 秒 |
| 2x | 快进 | 3 秒 |
| 4x | 极速 | 1.5 秒 |

## 三、与游戏循环的衔接

- `_process` 按 `delta × 倍速 / SECONDS_PER_HOUR` 累加 `current_day_fraction`；每满 1 小时触发 `GameManager.advance_hour()`（推进 `hour_of_day`），满 24 小时触发 `advance_day()`。
- 暂停菜单、设置页进出、弹窗展示均通过 `TimeSystem.set_speed(0)` 冻结时间，返回时恢复原倍速。
- 顶栏时间显示（`GameScene.refresh_top`）：`Day %d %02d:00`，由 `EventBus.hour_changed` 驱动刷新。

## 四、为什么是 6 秒/小时

| 方案 | 1 日耗时 | 体验 |
|---|---|---|
| 2.5 秒/天（旧） | 2.5 秒 | 车像瞬移，时限无意义 |
| 1 小时 = 6 秒 | 144 秒 | 肉眼可见车辆沿公路移动，订单时限有操作空间 |
| 1 小时 = 1 秒 | 24 秒 | 节奏过快，长距离订单（如首尔→釜山 4.8h）几乎无感 |

用户实测确认 6 秒/小时是"模拟经营节奏合理"的档位；玩家仍可用 2x/4x 快进跳过等待。

## 五、对其他系统的影响

- **订单时限**：`Order.deadline_day` 按真实行驶小时 + 处理缓冲小时折算成天（详见[订单与货流](/gameplay/order)）。
- **车辆移动**：`VehicleSystem.update_frame(delta_hours)` 每小时推进一次，车辆沿 OSRM 折线按弧长比例取点。
- **模拟脚本**：headless 长局模拟不再依赖真实时间，改为 `tick_frame(1.0)` 显式推进（每回合推 1 小时）。
