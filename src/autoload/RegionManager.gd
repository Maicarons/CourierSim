extends Node
## 区域管理器：加载真实地理数据（城市经纬度），维护当前区域，
## 提供坐标投影与距离查询。数据来源于 OSM / Geofabrik（参考 TransRoute）。

var regions: Array[Region] = []
var current: Region = null

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	regions.clear()
	var dir := DirAccess.open("res://src/map/data/regions")
	if dir == null:
		push_error("无法打开区域数据目录")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with(".") and fname.ends_with(".json"):
			var path := "res://src/map/data/regions/" + fname
			var txt := FileAccess.get_file_as_string(path)
			if txt.is_empty():
				push_error("区域文件为空: " + path)
				fname = dir.get_next()
				continue
			var parsed: Variant = JSON.parse_string(txt)
			# 只加载真正的区域定义（含 cities 数组），跳过 _land / _terrain 等烘焙产物
			if parsed is Dictionary and parsed.has("cities"):
				regions.append(Region.from_dict(parsed))
		fname = dir.get_next()
	dir.list_dir_end()
	# 默认选中首发区域（unlock_cost==0）
	for r in regions:
		if r.unlock_cost == 0:
			current = r
			break
	if current == null and regions.size() > 0:
		current = regions[0]
	print("[RegionManager] 已加载 %d 个区域" % regions.size())

func get_region(id: String) -> Region:
	for r in regions:
		if r.id == id:
			return r
	return null

func set_current(id: String) -> bool:
	var r := get_region(id)
	if r == null:
		return false
	current = r
	EventBus.region_changed.emit()
	return true

## 当前区域内两城市的真实距离（米）
func distance(city_a_id: String, city_b_id: String) -> float:
	var a := current.get_city(city_a_id)
	var b := current.get_city(city_b_id)
	if a == null or b == null:
		return 0.0
	return GeoMath.city_distance(a, b)

## 城市在区域局部坐标下的位置（米，东向x/北向y）
func local(city: City) -> Vector2:
	if current == null:
		return Vector2.ZERO
	return current.local_of(city)

## 区域内所有城市的局部坐标包围盒（米）
func bounds() -> Rect2:
	if current == null:
		return Rect2(0, 0, 1, 1)
	var minx := INF; var miny := INF; var maxx := -INF; var maxy := -INF
	for c in current.cities:
		var v := local(c)
		minx = min(minx, v.x); miny = min(miny, v.y)
		maxx = max(maxx, v.x); maxy = max(maxy, v.y)
	return Rect2(minx, miny, maxx - minx, maxy - miny)
