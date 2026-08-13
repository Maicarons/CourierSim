# 距离与用时计算

真实距离与用时是本作"真实地理"承诺的核心，采用**三级策略**：离线烘焙优先、公式兜底、运行时插值。

## 一、三级计算策略

| 级别 | 方法 | 精度 | 适用 |
|------|------|------|------|
| L1 | 预烘焙距离矩阵（OSRM 批量） | 最高（真实路网） | 城市对/站点对，运行时查表 |
| L2 | Haversine 大圆距离 × 绕路系数 | 中（近似） | 无矩阵数据的临时计算 |
| L3 | 运行时路网寻路（AStar2D） | 中高 | 车辆在地图上的实际行驶路径 |

## 二、L1：预烘焙距离矩阵

开发期用 OSRM 批量计算所有城市对/重要节点的真实距离与用时，烘焙为矩阵：

```json
{
  "首尔": { "釜山": {"dist_km": 400.0, "hours": 4.2, "path": [[126.9,37.5], ...]},
            "仁川": {"dist_km": 36.0, "hours": 0.5, "path": [...]} },
  "釜山": { "首尔": {"dist_km": 400.0, "hours": 4.3, "path": [...]} }
}
```

- **批量脚本**：复用 TransRoute 的 `osrmMetrics` 思路，脚本遍历城市对调 OSRM（本地或公共）。
- **稀疏化**：只烘焙重要城市对（N 个城市 → N² 对），站点级距离用 Haversine 或就近城市插值。
- **路径折线**：`path` 用于渲染车辆沿真实道路行驶的折线（可选，量大则只存距离）。

## 三、L2：Haversine 兜底

```
距离 ≈ Haversine(A, B) × 绕路系数(1.25~1.4)
用时 ≈ 距离 / 平均速度 × 路况系数
```

- **绕路系数**：公路非直线，乘以经验系数修正（TransRoute 已验证此方案）。
- **路况系数**：高速路 1.0、城市路 1.5、山区 2.0（可基于路网类型统计）。

## 四、L3：运行时路网寻路

车辆在地图上的**实际行驶**用游戏内路网图寻路（见 [模块实现](/architecture/modules)）：

- 路网图为加权图，边权重 = 真实距离（烘焙时附带）。
- 车辆沿寻路得到的折线移动，行驶距离 = 路径累加，用时 = 距离 / 车速。

## 五、用时模型（含装卸与中转）

总用时 = 运输时间 + 装卸时间 + 中转等待时间

```
运输时间 = Σ(路段距离 / 路段车速)
装卸时间 = 货量 / 装卸效率（站点/仓库等级、员工加成）
中转等待 = 排队时间（吞吐瓶颈）+ 分拣时间
```

> 真实快递的"时效"由多环节累加，本作同样体现，让"优化中转"有实际收益。

## 六、速度分层

| 道路等级 | OSM highway | 速度 |
|----------|-------------|------|
| 高速 | motorway | 100 km/h |
| 国道/主干 | trunk/primary | 80 km/h |
| 次干道 | secondary | 60 km/h |
| 城市路 | tertiary/residential | 40 km/h |

车辆实际速度 = min(车辆巡航速度, 路段限速) × 路况/天气系数。

## 七、技术实现要点

```gdscript
# DistanceService.gd（Autoload）
class_name DistanceService
extends Node

var matrix: Dictionary = {}   # 距离矩阵

func load_region_matrix(region_id: String):
    matrix = load("res://data/regions/%s/distance_matrix.json" % region_id)

func distance_km(a: String, b: String) -> float:
    if matrix.has(a) and matrix[a].has(b):
        return matrix[a][b]["dist_km"]
    # L2 兜底
    var ca = CityCatalog.get_city(a)
    var cb = CityCatalog.get_city(b)
    return GeoUtils.haversine_km(ca.lng, ca.lat, cb.lng, cb.lat) * 1.3

func duration_hours(a: String, b: String, speed_kmh: float) -> float:
    return distance_km(a, b) / speed_kmh
```
