# 车辆系统（Vehicle）

> 适用版本：v0.12+ · 购置 / 租赁 / 出售 · 沿真实 OSRM 折线 24h 移动

车辆是运力的载体，是玩家最核心的"可操作资产"。本系统覆盖**购置、租赁、调度、返程**全链路。

## 一、车型谱系（src/data/vehicles.json）

| 车型 | 载重 | 时速 | 购置价 | 日租（2%） | 能力位 | 可运货种 |
|---|---|---|---|---|---|---|
| 电动面包车 | 500 kg | 70 km/h | ¥60,000 | ¥1,200 | 0 | 标准 |
| 厢式货车 | 3,000 kg | 95 km/h | ¥140,000 | ¥2,800 | 4 | 标准 + 危险品 |
| 冷藏车 | 2,000 kg | 75 km/h | ¥260,000 | ¥5,200 | 3 | 标准 + 冷链 + 医药 |
| 配送无人机 | 30 kg | 60 km/h | ¥90,000 | ¥1,800 | 0 | 标准（轻型） |
| 货运飞机 | 15,000 kg | 700 km/h | ¥2,500,000 | ¥50,000 | 15 | 全部 + 国际 |
| 货轮 | 80,000 kg | 35 km/h | ¥4,000,000 | ¥80,000 | 15 | 全部 + 国际 |

- **能力位（capabilities）**：位掩码，`STANDARD=0 / COLDCHAIN=1 / PHARMA=2 / HAZMAT=4 / INT=8`，决定可承运货种。若车队无对应能力车辆，特殊货订单自动降级为标准货（`_has_carrier` 保护，避免无人接单卡死）。
- **车辆数据对象**：`Vehicle` 是纯数据（RefCounted），不参与物理渲染；地图上的精灵由 `MapView` 根据 `map_pos` 绘制。

## 二、车辆状态机

```
IDLE ──派单──▶ ENROUTE（沿折线载货行驶）
  ▲                 │ 到达
  │                 ▼
  └──────◀────── RETURNING（空驶返程回 home 城市）
```

- `IDLE`：空闲可接单；`ENROUTE`：载货干线运输中；`LOADING`：装卸等待；`RETURNING`：卸货后空驶返程。
- `is_busy()` = ENROUTE / LOADING / RETURNING 任一状态，繁忙车辆不可再派单、不可出售。

## 三、购置 / 租赁 / 出售

| 操作 | 入口 | 规则 |
|---|---|---|
| 购买 | 车辆面板「购买」按钮 | 立即付款 `cost`，车辆归自有（`owned=true`），驻车于所选城市 |
| 租赁 | 车辆面板「租赁」按钮 | 免首付即得车（`owned=false`），**每日扣日租**（`lease_daily = cost × 2%`），缓解前期资金压力 |
| 退租 | 车辆面板「退租」 | 归还车辆，停止扣租；租赁车不可出售 |
| 出售 | 车辆面板「出售」 | 仅限自有车辆，回收 50% 购车款；在途/返程车辆不可出售 |

> 租赁是 v0.12 的核心新增：前期现金紧张时"租 2~3 辆面包车撑运力、赚钱后再退租换购货车"是常见的过渡策略。

## 四、调度与移动（不再瞬移）

v0.11 起订单支持手动派单（订单页「派单 ▸」弹出 VehiclePicker），v0.12 起车辆**沿真实道路移动**：

1. **空驶接货**：车辆从当前位置出发，沿 OSRM 真实折线空驶到发货城市（不再"凭空出现在发货城"）。
2. **干线运输**：装货后沿 `Region.route_between(origin, dest).path_m` 真实公路折线逐段推进，按**弧长比例**取点（`Vehicle._point_at_progress`），地图上可见车辆沿高速走向移动。
3. **卸货返程**：送达后沿折线空驶返回 home 城市，恢复 IDLE。

- 行驶时间用真实里程与车速计算（`GeoMath.travel_hours`），不再有 8 小时工作制折算。
- 路线数据缺失的城市对自动回退直线插值（详见[距离与用时计算](/map/distance-time)）。
- `EventBus.vehicles_changed` / `map_updated` 驱动地图重绘。

## 五、经济关联

- **油费**：每次抵达按 `seg_km × fuel_per_km` 扣费（受 `fuel_price_mult` 事件影响）。
- **维护费**：每日 `maintenance_per_day` 计入成本（见[经济与财务](/gameplay/finance)）。
- **总资产**：`total_assets()` 中车辆按 `cost × 0.8` 计入（租赁车不计）。

## 六、技术实现要点

```gdscript
# src/core/Vehicle.gd（摘录）
var owned: bool = true              # 是否自有（false = 租赁）
var route_path: PackedVector2Array  # 当前行程的折线（米制局部坐标）
var travel_total_days: float        # 全程用时（天）
var travel_elapsed_days: float
var map_pos: Vector2                # 当前屏幕投影位置（渲染用）

func start_trip_path(path_m: PackedVector2Array, total_days: float) -> void
func advance(delta_days: float) -> bool   # 沿折线推进，返回是否到达
```

- `VehicleSystem.update_frame(delta_hours)`：每小时推进所有在途车辆；`process_hour` 在 `advance_day` 内被调用。
- 车辆速度 = 车型巡航速度（不叠加道路限速，保持简单可控）。
