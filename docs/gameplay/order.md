# 订单与货流（Order & Cargo Flow）

> 适用版本：v0.12+ · 站点门控生成 · 真实里程计价 · 小时制时限

订单系统是"血液"，连接站点、车辆与收益。v0.12 起**只有建了站/仓的城市才产生订单**——未建网络的城市不再空转货流。

## 一、订单生命周期

```
生成(PENDING) → 派单(INTRANSIT) → 送达(DELIVERED) 或 超时(TIMEOUT)
```

```gdscript
# src/core/Order.gd
enum Status { PENDING, INTRANSIT, DELIVERED, TIMEOUT }
```

- `Order` 是纯数据对象（RefCounted），字段含 origin_id / dest_id / cargo_type / weight_kg / distance_m / distance_days / reward / created_day / deadline_day / assigned_vehicle_id。
- 待分配订单在地图上画**橙色虚线**，在途订单画**蓝色实线 + 流动光点**（见[真实地图渲染](/map/real-map)）。

## 二、站点门控生成（v0.12 核心）

```gdscript
func served_cities(game) -> Array[City]   # 已建站点(Station)或中转仓(Hub)的城市
func spawn_one(game) -> void:
    var served := served_cities(game)
    if served.size() < 2: return          # 网络未成型 → 无跨城订单
    origin := 随机从 served 中按需求加权选取
    dest   := 随机从 served 中选取（≠ origin）
```

- **未建站的城市不再产生订单**：玩家必须先布局网络（首府免费赠送 1 个中转仓起步），再在目标城市建站/建仓，才能把该城市接入货流。
- 日均生成量：`compute_spawn = max(1, 站点数 × 0.8) × demand_mult × 区域需求加成`。
- 订单权重：城市 `base_demand × 10` + 站点 `marketing_level` 加成，站点多的城市更易成为发货端。

## 三、货种与能力矩阵

| 货种 | 奖励倍率 | 要求 | 能力位 |
|---|---|---|---|
| 标准货 | 1.0× | 任意车辆 | STANDARD=0 |
| 冷链 | 1.6× | 冷藏车 | COLDCHAIN=1 |
| 医药 | 1.9× | 冷藏车 | PHARMA=2 |
| 危险品 | 2.2× | 厢式货车 | HAZMAT=4 |
| 国际件 | 2.4× | 飞机/货轮 | INT=8 |

- 无对应能力车辆时，特殊货**自动降级为标准货**，保证订单池不卡死。
- 特殊货种同时计入**区域特色事件**加成（如半导体出货潮 → 需求 ×1.2）。

## 四、奖励与时限（真实里程 · 小时制）

```gdscript
# 奖励：按「吨·公里」计价（参考 TransRoute rate.costPerTonKm 量级）
func reward_for(game, distance_m, cargo, weight) -> int:
    var km   := distance_m / 1000.0
    var tons := weight / 1000.0
    var base := km * tons * 45.0 * (1.0 + weight * 0.004)
    var r := int(base * CargoType.reward_mult(cargo) * modifiers["reward_mult"])
    return max(800, r)                    # 保底 800 元

# 时限：真实行驶小时 + 处理缓冲小时
o.distance_days = GeoMath.travel_days(dist, 80.0)        # 24h 制
var buffer_h := 24.0                                     # 基础 1 天处理
if cargo == INTERNATIONAL: buffer_h = 36.0
o.deadline_day = game.day + int(ceil(o.distance_days + buffer_h / 24.0))
```

- **超时惩罚**：`TIMEOUT` 订单声誉 −1.5（货种倍率加权），无运费。
- **交付奖励**：+2.0 声誉 + 全额运费（`reward_for` 结果）。
- 声誉不对称问题在 v0.12 平衡轮中修正：奖励（+2.0）高于惩罚（−1.5），保证口碑可恢复。

## 五、派单（自动 / 手动）

- **自动派单**（订单页顶部 CheckButton，默认开）：`OrderSystem.auto_assign_enabled = true` 时，`advance_day` 内自动把待分配订单派给可承运空闲车辆。
- **手动派单**：关闭自动后，每张待分配卡出现「派单 ▸」按钮，弹出 `VehiclePicker`，按距发货城市距离升序列出**可承运 + 空闲 + 载重足够**的车辆；无车可用时给出引导提示。

## 六、与地图/区域的联动

- 订单端点城市必须属于**当前区域**；跨区域订单通过解锁第二区域后自然产生。
- 区域 `features.demand_bonus`（越南/马来西亚 1.05）提升该区域订单量。
- 订单生成、派单、送达全程由 `OrderSystem.process_day` 驱动，`EventBus.orders_changed` 通知 UI 刷新。
