# 距离与用时计算

> 适用版本：v0.12+ · OSRM 真实路网烘焙 · 运行时查表 · Haversine 兜底

真实距离与用时是本作"真实地理"承诺的核心。v0.12 用 **OSRM（OpenStreetMap 路网引擎）** 一次性烘焙
城市对真实里程/耗时/折线为静态 JSON，运行时查表；无路网数据（如跨海）自动回退 Haversine。

## 一、三级计算策略

| 级别 | 方法 | 精度 | 适用 |
|------|------|------|------|
| L1 | **OSRM 烘焙矩阵**（`<id>_routes.json`） | 最高（真实路网里程/耗时/折线） | 同区域城市对，运行时查表 |
| L2 | Haversine 大圆距离 × 绕路系数 | 中（近似） | 无烘焙数据的临时计算（如跨海对） |
| L3 | 直线插值（地图绘制） | 低 | 路线数据缺失时车辆移动的视觉兜底 |

## 二、L1：OSRM 烘焙（tools/bake_routes.py）

```bash
python tools/bake_routes.py    # 遍历 4 区域所有城市对 → 调 OSRM 公共服务器
```

- **数据源**：`https://router.project-osrm.org`（公共实例，driving profile，overview=full geojson）。
- **产物**：`res://src/map/data/regions/<id>_routes.json`：

```json
{
  "routes": [
    { "a": "seoul", "b": "busan",
      "dist_km": 392.6, "dur_h": 4.85,
      "path": [[126.978, 37.5665], [127.1, 37.5], "..."] }
  ]
}
```

- **简化**：Douglas-Peucker 压缩折线点（距离阈值按比例），减小包体；`dist_km`/`dur_h` 保持 OSRM 原始值。
- **成果**：korea / hainan / vietnam 全量成功（163 条真实路网）；malaysia 11/21——跨海城市对
  （如新山→沙巴）OSRM 无路网连接（HTTP 400），运行时自动回退 L2，符合预期。
- 烘焙需联网且受公共实例速率限制，属**开发期一次性工具**；游戏运行时零网络、零延迟。

## 三、运行时查表（Region.route_between）

```gdscript
# src/core/Region.gd（摘录）
var _routes: Dictionary = {}    # "a|b" -> {dist_km, dur_h, path_m}，懒加载

func route_between(a_id: String, b_id: String) -> Dictionary
func real_distance_m(a: City, b: City) -> float      # L1 优先，L2 兜底
func real_duration_h(a: City, b: City) -> float      # L1 优先，公式兜底
```

- `path_m`：折线点已投影为区域局部**米制坐标**（等距圆柱投影 + 区域原点），车辆直接沿线移动。
- 键规范化：`a|b` 与 `b|a` 同一条（无向），运行时不区分方向。
- 订单奖励与时限**优先用真实里程/耗时**（见[订单与货流](/gameplay/order)）。

## 四、L2：Haversine 兜底

```gdscript
# src/core/GeoMath.gd（摘录）
static func haversine(lat1, lon1, lat2, lon2) -> float          # 球面距离（米）
static func city_distance(a: City, b: City, detour := 1.25)     # × 绕路系数
static func travel_hours(distance_m: float, speed_kmh: float)   # 24h 制用时
static func travel_days(distance_m: float, speed_kmh: float, daily_hours := 24.0)
```

- 兜底场景：跨海城市对（马来西亚东西海岸）、未来新增区域尚未烘焙时。
- 绕路系数 1.25 为公路非直线经验修正。

## 五、用时模型（24 小时制）

```
行驶小时 = 真实里程(km) / 车速(km/h)        # 无装卸/中转等待（当前简化模型）
订单时限 = 行驶小时 + 处理缓冲小时(24h，国际件 36h)
```

- 车辆**24 小时不间断运行**，不再按 8 小时工作制折算（见[时间系统](/gameplay/time)）。
- 未来可扩展：装卸时间（货量/效率）、中转排队（吞吐瓶颈）累加进总时效。

## 六、技术实现要点

- **投影一致性**：烘焙时折线用等距圆柱投影转米制（`cos(origin_lat)` 修正）；地图渲染陆地/城市用
  **线性 bbox 映射**（与 terrain 贴图同源）——两套只影响显示，不影响里程计算（里程取 OSRM 原值）。
- **内存**：单区域城市对 ≤ 数百条，JSON 懒加载一次驻留，运行时零网络零延迟。
