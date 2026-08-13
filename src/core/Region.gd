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
