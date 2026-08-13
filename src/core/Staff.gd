class_name Staff
extends RefCounted

## 员工：司机、分拣员、网点经理、维修师。影响运力、效率与成本。

enum Role {
	DRIVER,   # 司机：提升车辆速度/载量
	SORTER,   # 分拣员：提升仓库吞吐
	MANAGER,  # 网点经理：提升满意度/订单
	MECHANIC, # 维修师：降低维修成本/故障率
}

var id: String = ""
var name: String = ""
var role: int = Role.DRIVER
var skill: float = 0.5        # 0..1 技能
var salary_per_day: float = 0.0
var efficiency: float = 1.0   # 派生：对产出的增益系数
var assigned_hub_id: String = ""

func _init(p_id := "", p_name := "", p_role := Role.DRIVER, p_skill := 0.5):
	id = p_id
	name = p_name
	role = p_role
	skill = p_skill
	salary_per_day = 60.0 + p_skill * 140.0
	efficiency = 1.0 + p_skill * 0.5

func role_name() -> String:
	var key := "staff.%s" % Role.keys()[role]
	var s := Localization.t(key)
	if s == key:
		return Role.keys()[role]
	return s

static func random_name(rng: RandomNumberGenerator) -> String:
	var surnames := ["金", "李", "朴", "崔", "郑", "姜", "赵", "尹", "张", "林"]
	var givens := ["敏浩", "志勋", "俊昊", "秀贤", "允真", "在勋", "泰宇", "承佑", "慧琳", "艺珍"]
	return surnames[rng.randi() % surnames.size()] + givens[rng.randi() % givens.size()]
