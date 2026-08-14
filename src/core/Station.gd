class_name Station
extends RefCounted

## 末端站点：直接面向收寄客户的覆盖节点。以圆覆盖模型服务周边区域。
## 站点越多、覆盖越密，本地订单生成率越高（受市场宣传加成）。

var id: String = ""
var name: String = ""
var city_id: String = ""
var coverage_radius_km: float = 8.0
var marketing_level: int = 0      # 宣传等级 0~5
var daily_orders: int = 0          # 昨日实际产生订单数（统计）
var satisfaction: float = 1.0     # 客户满意度 0..1

func _init(p_id := "", p_name := "", p_city := "", p_radius := 8.0):
	id = p_id
	name = p_name
	city_id = p_city
	coverage_radius_km = p_radius

## 宣传带来的订单生成倍率
func marketing_mult() -> float:
	return 1.0 + marketing_level * 0.35

func marketing_upgrade_cost() -> int:
	return StationSystem.STATION_UPGRADE_BASE * (marketing_level + 1)

func upgrade_marketing() -> void:
	marketing_level = min(marketing_level + 1, 5)
