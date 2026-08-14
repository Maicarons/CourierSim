# 坐标与投影转换

真实经纬度（WGS84）不能直接用于 2D 游戏坐标，需要一套投影与缩放转换链。本章定义统一的坐标系统与转换函数（实际实现 `src/core/GeoMath.gd`）。

## 一、坐标系统

| 系统 | 说明 | 单位 |
|------|------|------|
| 地理坐标 | WGS84 经纬度 | 度（°） |
| 投影坐标 | 等距圆柱投影后的局部平面坐标 | 米（m） |
| 屏幕坐标 | 地图控件内的绘制坐标（线性 bbox 映射） | 像素（px） |

## 二、投影选择

2D 像素地图采用**等距圆柱投影（Equirectangular）**，理由：

- 公式极简，利于像素瓦片对齐。
- 韩国/越南/马来西亚纬度范围不大，形变可接受。
- 与"像素地图"天然契合（网格规则）。

```gdscript
# src/core/GeoMath.gd（摘录）
const EARTH_RADIUS_M := 6378137.0

static func to_local_meters(lat: float, lon: float, origin_lat: float, origin_lon: float) -> Vector2:
    var x := (lon - origin_lon) * PI / 180.0 * EARTH_RADIUS_M * cos(deg_to_rad(origin_lat))
    var y := (lat - origin_lat) * PI / 180.0 * EARTH_RADIUS_M
    return Vector2(x, y)
```

> 原点 `origin` 取区域中心（`Region.origin_lat/lon`），避免浮点精度问题；每区域独立原点，区域切换时重设。

## 三、米 → 像素（两套映射并存，务必区分）

### 1. 城市 / 车辆 / 折线（米制 → 屏幕）

```gdscript
# MapView._project(pos_m: Vector2) —— 等距圆柱米制 → 屏幕像素
```

- 城市、OSRM 折线、车辆位置均以**米制局部坐标**存储（`RegionManager.local(city)`），绘制时缩放+平移。

### 2. 陆地贴图 / 海岸描边（经纬度 → 屏幕，线性 bbox）

```gdscript
# MapView._bbox_to_screen(lng, lat) —— 与 terrain.png 同源的线性 bbox 映射
```

- terrain.png 由 PIL 按区域 `bbox` **线性拉伸**光栅化；陆地多边形、海岸描边必须用**同一线性映射**绘制，
  否则出现"描边漂移"（v0.12 修复，详见[真实地图渲染](/map/real-map)）。
- **关键教训**：同一地图上"米制投影"与"线性 bbox"两套映射并存，各自只用于其数据源——
  贴图/描边用 bbox 线性，城市/折线/车辆用等距圆柱米制。二者混用是早期描边错位的根因。

## 四、缩放与平移（MapView）

- `zoom`：滚轮缩放（0.5× ~ 8×），`_project` 将米制坐标 × 缩放 + 平移偏移。
- `offset`：左键拖拽平移。
- `_project(pos_m) -> pos_m × zoom + offset`；bbox 映射同理缩放。

## 五、距离计算（不依赖投影）

- 距离**优先用 OSRM 真实里程**（`Region.real_distance_m`），无数据时 `GeoMath.haversine × 1.25` 兜底
  （详见[距离与用时计算](/map/distance-time)）。
- Haversine 是球面距离，与投影无关；投影只用于显示。

## 六、统一转换工具（src/core/GeoMath.gd）

```gdscript
class_name GeoMath
extends RefCounted

static func haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float
static func to_local_meters(lat: float, lon: float, origin_lat: float, origin_lon: float) -> Vector2
static func local_to_geo(pos: Vector2, origin_lat: float, origin_lon: float) -> Vector2
static func city_distance(a: City, b: City, detour := 1.25) -> float
static func travel_hours(distance_m: float, speed_kmh: float) -> float
static func travel_days(distance_m: float, speed_kmh: float, daily_hours := 24.0) -> float
```

- 全部为 `static`，无状态，便于在 Vehicle / OrderSystem / Region 中直接调用。
- 区域级入口：`RegionManager.local(city) -> Vector2`（米制）、`RegionManager.current` 提供原点。
