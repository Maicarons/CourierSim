# 坐标与投影转换

真实经纬度（WGS84）不能直接用于 2D 游戏坐标，需要一套投影与缩放转换链。本章定义统一的坐标系统与转换函数。

## 一、坐标系统

| 系统 | 说明 | 单位 |
|------|------|------|
| 地理坐标 | WGS84 经纬度 | 度（°） |
| 投影坐标 | 米卡托/等距投影后的平面坐标 | 米（m） |
| 瓦片坐标 | 游戏地图瓦片格 | 瓦片 |
| 世界坐标 | Godot 场景坐标 | 像素（px） |

## 二、投影选择

2D 像素地图推荐**等距圆柱投影（Equirectangular）**，而非 Web 米卡托，理由：

- 公式极简，利于像素瓦片对齐。
- 韩国/越南/马来西亚纬度范围不大，形变可接受。
- 与"像素地图"天然契合（网格规则）。

```gdscript
# 经纬度 → 平面米（等距圆柱，简化）
const EARTH_RADIUS_M := 6378137.0

func geo_to_meters(lng: float, lat: float, origin_lng: float, origin_lat: float) -> Vector2:
    var x = (lng - origin_lng) * PI / 180.0 * EARTH_RADIUS_M * cos(deg_to_rad(origin_lat))
    var y = (lat - origin_lat) * PI / 180.0 * EARTH_RADIUS_M
    return Vector2(x, y)
```

> 原点 `origin` 取区域中心或西南角，避免浮点精度问题（大坐标差会导致精度丢失）。

## 三、米 → 像素缩放

定义**地图缩放系数** `PIXELS_PER_METER`，控制地图精细度：

```
pixels = meters × PIXELS_PER_METER
```

| 缩放 | 像素/米 | 适用 |
|------|---------|------|
| 世界图 | 0.05 | 全国总览 |
| 区域图 | 0.2 | 城市群 |
| 城市图 | 1.0 | 街道级 |

> 本作采用**可变缩放（相机缩放）**，游戏内放大缩小地图，缩放系数动态变化。逻辑计算始终用"米"，渲染时再乘缩放。

## 四、经纬度 ↔ 瓦片（Web 米卡托，供矢量瓦片参考）

若后续引入矢量瓦片底图，需标准瓦片坐标：

```gdscript
func lnglat_to_tile(lng: float, lat: float, zoom: int) -> Vector2i:
    var n = pow(2.0, zoom)
    var xtile = int((lng + 180.0) / 360.0 * n)
    var lat_rad = deg_to_rad(lat)
    var ytile = int((1.0 - asinh(tan(lat_rad)) / PI) / 2.0 * n)
    return Vector2i(xtile, ytile)
```

## 五、精度与原点

- 所有地理计算在**逻辑层用米**，避免浮点精度问题。
- 每个区域设定独立原点（`origin_lng/lat`），区域切换时重设（见 [区域切换](/map/region-switching)）。
- 距离计算优先用 Haversine（球面），不依赖投影（投影只用于显示）。

## 六、统一转换工具类

```gdscript
# GeoUtils.gd（Autoload）
class_name GeoUtils
extends Node

const EARTH_RADIUS_M := 6378137.0
var region_origin_lng := 0.0
var region_origin_lat := 0.0

func geo_to_local(lng: float, lat: float) -> Vector2:
    return geo_to_meters(lng, lat, region_origin_lng, region_origin_lat)

func local_to_geo(pos: Vector2) -> Vector2:
    var lng = pos.x / (EARTH_RADIUS_M * cos(deg_to_rad(region_origin_lat))) * 180.0 / PI + region_origin_lng
    var lat = pos.y / EARTH_RADIUS_M * 180.0 / PI + region_origin_lat
    return Vector2(lng, lat)

func haversine_km(lng1, lat1, lng2, lat2) -> float:
    # 与 TransRoute 一致的球面距离
    ...
```
