class_name Hub
extends RefCounted

## 中转仓库（轴辐式网络的核心节点）。负责集散、分拣与跨城转运。

var id: String = ""
var name: String = ""
var city_id: String = ""
var level: int = 1
var base_capacity: int = 200      # 每日处理包裹能力（基础值）
var used_today: int = 0
var upgrade_base_cost: int = 0
var throughput_bonus: float = 0.0 # 科技/员工带来的吞吐加成

func _init(p_id := "", p_name := "", p_city := "", p_cap := 200, p_cost := 0):
	id = p_id
	name = p_name
	city_id = p_city
	base_capacity = p_cap
	upgrade_base_cost = p_cost

func capacity() -> int:
	return int(base_capacity * level * (1.0 + throughput_bonus))

func is_full() -> bool:
	return used_today >= capacity()

func upgrade_cost() -> int:
	return int(upgrade_base_cost * pow(1.6, level - 1))

func upgrade() -> void:
	level += 1
