class_name GeoMath
extends RefCounted

## 地理数学工具：真实距离计算与坐标投影。
## 距离采用球面 Haversine 公式（与 TransRoute 一致的兜底方案），
## 生产环境可被 OSRM 真实路网距离矩阵替代（见 docs/map/distance-time.md）。

const EARTH_R := 6371000.0  # 地球平均半径（米）

## 两经纬点间的真实地表距离（米）。
static func haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1 := deg_to_rad(lat1)
	var p2 := deg_to_rad(lat2)
	var dphi := deg_to_rad(lat2 - lat1)
	var dlam := deg_to_rad(lon2 - lon1)
	var a := sin(dphi * 0.5) * sin(dphi * 0.5) + cos(p1) * cos(p2) * sin(dlam * 0.5) * sin(dlam * 0.5)
	var c := 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return EARTH_R * c

## 等距圆柱（equirectangular）近似：把经纬度投影到以原点为基准的米制平面。
## 返回 Vector2：(东向 x 米, 北向 y 米)。用于把城市铺到像素地图上。
static func to_local_meters(lat: float, lon: float, origin_lat: float, origin_lon: float) -> Vector2:
	var lat_rad := deg_to_rad(lat)
	var mean_lat := deg_to_rad((lat + origin_lat) * 0.5)
	var dlat := deg_to_rad(lat - origin_lat)
	var dlon := deg_to_rad(lon - origin_lon)
	var x := dlon * cos(mean_lat) * EARTH_R
	var y := dlat * EARTH_R
	return Vector2(x, y)

## 两城市真实距离（米），内部用 Haversine，并乘以绕路系数模拟路网。
## 若区域已烘焙 OSRM 真实路网，请用 RegionManager.route_between()（真实里程优先）。
static func city_distance(a: City, b: City, detour := 1.25) -> float:
	return haversine(a.lat, a.lon, b.lat, b.lon) * detour

## 由距离（米）与速度（km/h）估算行驶时间（小时）。车辆 24 小时不间断运行。
static func travel_hours(distance_m: float, speed_kmh: float) -> float:
	var km := distance_m / 1000.0
	return km / maxf(speed_kmh, 1.0)

## 由距离（米）与速度（km/h）估算行驶天数（24h 制）。兼容旧调用。
static func travel_days(distance_m: float, speed_kmh: float, daily_hours := 24.0) -> float:
	return maxf(travel_hours(distance_m, speed_kmh) / daily_hours, 0.02)

## 限制数值到 [min,max]
static func clampf(v: float, lo: float, hi: float) -> float:
	return min(max(v, lo), hi)
