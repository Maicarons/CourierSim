# 车辆系统

车辆是运力的载体，是玩家最核心的"可操作资产"。本系统覆盖**购置、分配、调度、管理**四大环节。

## 一、车辆属性

```
Vehicle {
  id: String
  model: String          // 车型（面包车/厢式货车/冷藏车/重卡…）
  tier: int              // 1~5 等级
  capacity_kg: float     // 载重（公斤）
  capacity_vol: float    // 容积（立方米）
  speed_kmh: float       // 巡航速度
  fuel_cost_per_km: float// 每公里燃料成本
  maintenance_per_km: float // 每公里维护成本
  price: float           // 购置价
  status: Enum           // IDLE / ASSIGNED / TRANSIT / MAINTENANCE
  home_hub: String       // 归属仓库
  odometer_km: float     // 累计里程（影响残值与维护）
  condition: float       // 车况 0~1（越低越易故障）
}
```

## 二、车型谱系

| Tier | 车型 | 载重 | 速度 | 特点 |
|------|------|------|------|------|
| 1 | 面包车 | 800 kg | 60 km/h | 起步车，短途同城 |
| 2 | 轻型厢货 | 2 t | 75 km/h | 城际短途 |
| 3 | 中型厢货 | 5 t | 85 km/h | 干线主力 |
| 4 | 重型卡车 | 12 t | 80 km/h | 高载重长途 |
| 5 | 冷藏车 / 特种车 | 6~15 t | 85 km/h | 冷链/危险品专属 |

> 特殊车型对应**特殊货种**（生鲜冷链、医药、危险品），解锁后开辟高利润细分市场。

## 三、购置

- **来源**：4S 店（新车，价格高）/ 二手市场（价格低但车况随机）/ 融资租赁（低首付 + 分期）。
- **购买限制**：受公司等级、仓库停放位（Hub 的车辆泊位）限制。
- **车牌/许可**：某些区域（如市中心站点）限行，需购买通行许可（额外成本，制造区域差异）。

## 四、分配（归属与部署）

- 车辆必须**归属某个中转仓库（Hub）**，从该 Hub 出发执行任务。
- Hub 有**车辆泊位上限**，超过需扩建停车场（连接仓库升级）。
- 分配是"车队-仓库"的绑定关系，决定车辆的调度范围。

## 五、调度（线路与任务）

调度是核心策略点，玩家为车辆指派**线路（Route）**：

```
Route {
  id: String
  from: String       // 起点站点/仓库
  to: String         // 终点站点/仓库
  vehicle_id: String // 指派车辆
  depart_time: Time  // 发车时刻
  cargo_type: Enum   // 普通/冷链/加急…
}
```

- **直达 vs 中转**：短途直达，长途走 Hub 转运，玩家权衡成本与时效。
- **满载率阈值**：设置"满载 N% 才发车"，避免空驶浪费。
- **班次**：可设为每日定时发车（循环班线），减少重复操作。

## 六、管理

- **维护**：里程与车况下降 → 需定期进厂保养；车况过低则半路抛锚（触发随机事件）。
- **燃油**：油价波动影响成本（见 [突发事件](/gameplay/events)）。
- **司机**：每车需配司机（见 [员工系统](/gameplay/staff)）。
- **报废/出售**：车况或年限到限后残值回收，进入二手市场。
- **数据看板**：单车利用率、单位成本、准时率，辅助调度决策。

## 七、技术实现要点

```gdscript
# 车辆节点结构（示意）
class_name Vehicle
extends CharacterBody2D

@export var stats: VehicleStats          # Resource
var state: VehicleState = VehicleState.IDLE
var current_route: Route
var path: PackedVector2Array             # 由路网寻路生成
var path_index: int = 0

func _physics_process(delta):
    if state == VehicleState.TRANSIT:
        _move_along_path(delta)

func _move_along_path(delta):
    if path_index >= path.size():
        _arrive()
        return
    var target = path[path_index]
    position = position.move_toward(target, stats.speed_kmh * KMH_TO_PX * delta)
    if position.distance_to(target) < 1.0:
        path_index += 1
```

- 车辆用 `CharacterBody2D` 沿**预计算路径**（AStar2D 结果）平滑移动，避免逐帧寻路。
- 速度换算：真实 `km/h` 通过地图缩放系数转为像素/秒（见 [坐标转换](/map/coordinate)）。
- 车队数据由 `FleetManager`（Autoload 单例）统一管理，车辆节点只负责表现层移动。
