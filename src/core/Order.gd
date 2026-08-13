class_name Order
extends RefCounted

## 订单：连接发货城市与收货城市，决定货种、重量、收益与时限。
enum Status {
	PENDING,     # 待分配车辆
	ASSIGNED,    # 已分配车辆（装载中）
	INTRANSIT,   # 运送途中
	DELIVERED,   # 已送达
	FAILED,      # 超时失败
}

var id: String = ""
var origin_id: String = ""
var dest_id: String = ""
var cargo_type: int = CargoType.Type.STANDARD
var weight_kg: float = 5.0
var created_day: int = 0
var deadline_day: int = 0
var reward: int = 0
var status: int = Status.PENDING
var assigned_vehicle_id: String = ""
var distance_m: float = 0.0
var distance_days: float = 1.0

func _init(p_id := "", p_origin := "", p_dest := "", p_cargo := CargoType.Type.STANDARD, p_weight := 5.0):
	id = p_id
	origin_id = p_origin
	dest_id = p_dest
	cargo_type = p_cargo
	weight_kg = p_weight

func is_urgent(day: int) -> bool:
	return (deadline_day - day) <= 1

## 是否已超过时限
func is_overdue(day: int) -> bool:
	return day > deadline_day

func progress(vehicle: Vehicle) -> float:
	if status == Status.DELIVERED:
		return 1.0
	if status == Status.FAILED:
		return 0.0
	if vehicle == null:
		return 0.0
	return vehicle.travel_progress
