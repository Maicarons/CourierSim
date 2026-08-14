class_name Vehicle
extends RefCounted

## 车辆：可购置、分配、调度与管理的核心资产。

enum Type {
	VAN,         # 面包车
	TRUCK,       # 厢式货车
	REFRIGERATED,# 冷藏车
	DRONE,       # 配送无人机
	PLANE,       # 货运飞机（国际）
	SHIP,        # 货轮（国际海运）
}

## 能力位掩码（与 CargoType.REQUIRED_CAP 对应）
enum Capability {
	NONE = 0,
	REFRIGERATED = 1,
	PHARMA = 2,
	HAZMAT = 4,
	INTERNATIONAL = 8,
}

enum Status {
	IDLE,       # 空闲待命
	LOADING,    # 装载中
	ENROUTE,    # 运送途中
	RETURNING,  # 返程
	MAINTENANCE,# 维修中
}

var id: String = ""
var name: String = ""
var type: int = Type.VAN
var capacity_kg: int = 500
var speed_kmh: float = 70.0
var km_per_day: float = 480.0      # 每日可行驶里程（影响 ETA）
var cost: int = 0                   # 购置价
var fuel_per_km: float = 0.0        # 每公里油费（元）
var maintenance_per_day: float = 0.0
var capabilities: int = Capability.NONE
var assigned_hub_id: String = ""
var home_city_id: String = ""
var status: int = Status.IDLE
var current_order_id: String = ""
var owned: bool = true             # true=自有，false=租赁
var lease_daily: int = 0           # 日租金（自有车为 0）

# ---- 运行时移动状态（仅供地图渲染与模拟）----
var route_from: Vector2 = Vector2.ZERO
var route_to: Vector2 = Vector2.ZERO
var route_path: PackedVector2Array = PackedVector2Array()   # 折线（局部米制），空=直线
var travel_progress: float = 0.0    # 0..1
var travel_total_days: float = 1.0
var travel_elapsed_days: float = 0.0
var map_pos: Vector2 = Vector2.ZERO # 当前屏幕投影位置（由渲染器更新）

func _init(p_id := "", p_name := "", p_type := Type.VAN, p_cap := 500, p_speed := 70.0, p_cost := 0):
	id = p_id
	name = p_name
	type = p_type
	capacity_kg = p_cap
	speed_kmh = p_speed
	cost = p_cost

func type_name() -> String:
	var key := "vehicle.%s" % Type.keys()[type]
	var s := Localization.t(key)
	if s == key:
		return Type.keys()[type]
	return s

func can_carry(cargo_type: int) -> bool:
	var need := CargoType.required_cap(cargo_type)
	return (capabilities & need) == need

func is_busy() -> bool:
	return status == Status.ENROUTE or status == Status.LOADING or status == Status.RETURNING

func start_trip(from: Vector2, to: Vector2, total_days: float) -> void:
	route_from = from
	route_to = to
	route_path = PackedVector2Array()
	travel_progress = 0.0
	travel_elapsed_days = 0.0
	travel_total_days = max(total_days, 0.02)
	map_pos = from
	status = Status.ENROUTE

## 带真实折线路径的出发：path_m 为局部米制折线（首尾=from/to）。
func start_trip_path(path_m: PackedVector2Array, total_days: float) -> void:
	if path_m.size() >= 2:
		route_from = path_m[0]
		route_to = path_m[path_m.size() - 1]
		route_path = path_m
	else:
		route_from = Vector2.ZERO
		route_to = Vector2.ZERO
		route_path = PackedVector2Array()
	travel_progress = 0.0
	travel_elapsed_days = 0.0
	travel_total_days = max(total_days, 0.02)
	map_pos = route_from
	status = Status.ENROUTE

## 推进行程（delta_days 为游戏内经过的天数）。返回 true 表示本次已到达。
func advance(delta_days: float) -> bool:
	if status != Status.ENROUTE and status != Status.RETURNING:
		return false
	travel_elapsed_days += delta_days
	travel_progress = clampf(travel_elapsed_days / travel_total_days, 0.0, 1.0)
	map_pos = _point_at_progress(travel_progress)
	return travel_progress >= 1.0

## 沿折线取 progress 处坐标（无折线则直线插值）。
func _point_at_progress(t: float) -> Vector2:
	if route_path.size() < 2:
		return route_from.lerp(route_to, t)
	return _polyline_point(route_path, t)

## 在折线上按弧长比例取点。
static func _polyline_point(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector2.ZERO
	var seg_lens := PackedFloat32Array()
	var total := 0.0
	for i in range(1, pts.size()):
		var l := pts[i].distance_to(pts[i - 1])
		seg_lens.append(l)
		total += l
	if total <= 0.001:
		return pts[0]
	var target := t * total
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := seg_lens[i - 1]
		if acc + seg >= target or i == pts.size() - 1:
			var local := 0.0 if seg <= 0.0 else (target - acc) / seg
			return pts[i - 1].lerp(pts[i], clampf(local, 0.0, 1.0))
		acc += seg
	return pts[pts.size() - 1]
