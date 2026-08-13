class_name City
extends RefCounted

## 城市节点。坐标使用 WGS84 经纬度，真实数据来自 OSM / Geofabrik。
var id: String = ""
var name: String = ""
var name_en: String = ""
var country: String = ""
var lat: float = 0.0
var lon: float = 0.0
var tier: int = 3            # 1=都会, 2=大城市, 3=中型, 4=小城
var population: int = 0
var coastal: bool = false
var has_port: bool = false   # 是否有海港（用于国际/海运）
var base_demand: float = 1.0 # 本地发货需求系数（由人口/层级推导）

func _init(p_id := "", p_name := "", p_lat := 0.0, p_lon := 0.0, p_tier := 3, p_pop := 0, p_coastal := false, p_port := false, p_name_en := ""):
	id = p_id
	name = p_name
	name_en = p_name_en
	lat = p_lat
	lon = p_lon
	tier = p_tier
	population = p_pop
	coastal = p_coastal
	has_port = p_port
	# 需求系数：人口越多、层级越高，发货需求越大
	base_demand = float(p_pop) / 1_000_000.0 * (5 - p_tier) * 0.6 + 0.4

## 从字典构造（用于 JSON 反序列化）
static func from_dict(d: Dictionary) -> City:
	var c := City.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.name_en = d.get("name_en", "")
	c.country = d.get("country", "")
	c.lat = float(d.get("lat", 0.0))
	c.lon = float(d.get("lon", 0.0))
	c.tier = int(d.get("tier", 3))
	c.population = int(d.get("population", 0))
	c.coastal = bool(d.get("coastal", false))
	c.has_port = bool(d.get("port", false))
	return c

## 按当前语言返回城市显示名（英文模式取 name_en，缺省回退中文）。
func display_name() -> String:
	if Localization.is_en() and name_en != "":
		return name_en
	return name
