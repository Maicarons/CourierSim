class_name Region
extends RefCounted

## 一个可游玩的地理区域（如韩国、海南）。拥有独立的局部坐标系原点，
## 避免大跨度经纬度带来的浮点精度问题（参考 TransRoute 的区域独立原点方案）。
var id: String = ""
var region_name: String = ""
var region_name_en: String = ""
var country: String = ""
var origin_lat: float = 0.0   # 局部坐标系原点（区域质心）
var origin_lon: float = 0.0
var color: String = "#4a90d9"
var unlock_cost: int = 0      # 解锁所需资金（0 = 首发免费）
var difficulty: int = 1       # 1~5，影响竞争强度与成本
var unlocked: bool = false
var cities: Array[City] = []
var features: Dictionary = {} # 区域特色：{demand_bonus: float, events: Array}

# ---- 运行时缓存 ----
var _local_cache: Dictionary = {}  # city_id -> Vector2 (米, 东向x/北向y)
var _routes: Dictionary = {}       # "a|b" -> {dist_km, dur_h, path_m: PackedVector2Array}
var _routes_loaded := false

func _init(p_id := "", p_name := "", p_country := "", p_olat := 0.0, p_olon := 0.0, p_color := "#4a90d9", p_cost := 0, p_diff := 1):
	id = p_id
	region_name = p_name
	country = p_country
	origin_lat = p_olat
	origin_lon = p_olon
	color = p_color
	unlock_cost = p_cost
	difficulty = p_diff
	unlocked = p_cost == 0

static func from_dict(d: Dictionary) -> Region:
	var r := Region.new()
	r.id = d.get("id", "")
	r.region_name = d.get("name", "")
	r.region_name_en = d.get("name_en", "")
	r.country = d.get("country", "")
	r.origin_lat = float(d.get("origin_lat", 0.0))
	r.origin_lon = float(d.get("origin_lon", 0.0))
	r.color = d.get("color", "#4a90d9")
	r.unlock_cost = int(d.get("unlock_cost", 0))
	r.difficulty = int(d.get("difficulty", 1))
	r.unlocked = r.unlock_cost == 0
	r.features = d.get("features", {})
	var arr: Array = d.get("cities", [])
	for cd in arr:
		r.cities.append(City.from_dict(cd))
	return r

func get_city(city_id: String) -> City:
	for c in cities:
		if c.id == city_id:
			return c
	return null

## 城市在区域局部坐标下的位置（米）。+x 东, +y 北。带缓存。
func local_of(city: City) -> Vector2:
	if _local_cache.has(city.id):
		return _local_cache[city.id]
	var v := GeoMath.to_local_meters(city.lat, city.lon, origin_lat, origin_lon)
	_local_cache[city.id] = v
	return v

## 按当前语言返回区域显示名（英文模式取 region_name_en，缺省回退中文）。
func display_name() -> String:
	if Localization.is_en() and region_name_en != "":
		return region_name_en
	return region_name

# ================= OSRM 真实路网 =================

## 懒加载烘焙好的城市对路线（<id>_routes.json，由 tools/bake_routes.py 生成）。
func load_routes() -> void:
	if _routes_loaded:
		return
	_routes_loaded = true
	var path := "res://src/map/data/regions/%s_routes.json" % id
	if not ResourceLoader.exists(path):
		return
	var txt := FileAccess.get_file_as_string(path)
	if txt.is_empty():
		return
	var d: Dictionary = JSON.parse_string(txt)
	var arr: Array = d.get("routes", [])
	for r in arr:
		var key := "%s|%s" % [r.get("a", ""), r.get("b", "")]
		var pts: Array = r.get("path", [])
		var path_m := PackedVector2Array()
		for p in pts:
			path_m.append(GeoMath.to_local_meters(p[1], p[0], origin_lat, origin_lon))
		_routes[key] = {
			"dist_km": float(r.get("dist_km", 0.0)),
			"dur_h": float(r.get("dur_h", 0.0)),
			"path_m": path_m,
		}

## 两城市的真实路线信息（OSRM）。找不到时返回 null。
func route_between(city_a_id: String, city_b_id: String) -> Dictionary:
	load_routes()
	var key := "%s|%s" % [city_a_id, city_b_id]
	if _routes.has(key):
		return _routes[key]
	# 反向（OSRM 路线无向存储，双向可复用）
	key = "%s|%s" % [city_b_id, city_a_id]
	if _routes.has(key):
		return _routes[key]
	return {}

## 两城市的真实里程（米）。无烘焙数据时回退 Haversine×绕路。
func real_distance_m(city_a_id: String, city_b_id: String) -> float:
	var r := route_between(city_a_id, city_b_id)
	if not r.is_empty():
		return float(r.get("dist_km", 0.0)) * 1000.0
	var a := get_city(city_a_id)
	var b := get_city(city_b_id)
	if a == null or b == null:
		return 0.0
	return GeoMath.city_distance(a, b)

## 两城市的真实耗时（小时）。无烘焙数据时按速度估算。
func real_duration_h(city_a_id: String, city_b_id: String, speed_kmh: float) -> float:
	var r := route_between(city_a_id, city_b_id)
	if not r.is_empty():
		return float(r.get("dur_h", 0.0))
	var d := real_distance_m(city_a_id, city_b_id)
	return GeoMath.travel_hours(d, speed_kmh)
