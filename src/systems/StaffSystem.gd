extends Node
class_name StaffSystem

## 员工系统：招聘不同角色，提供速度/吞吐/满意度/成本等增益，每日发薪。

const HIRE_FEE := 2000

func contribute(game: GameManager, base: Dictionary) -> void:
	var drivers: Array[Staff] = []
	var sorters: Array[Staff] = []
	var managers: Array[Staff] = []
	var mechanics: Array[Staff] = []
	for s in game.staff:
		match s.role:
			Staff.Role.DRIVER: drivers.append(s)
			Staff.Role.SORTER: sorters.append(s)
			Staff.Role.MANAGER: managers.append(s)
			Staff.Role.MECHANIC: mechanics.append(s)
	var avg := func(arr: Array[Staff]) -> float:
		if arr.is_empty():
			return 0.0
		var s := 0.0
		for x in arr:
			s += x.skill
		return s / arr.size()
	var d: float = avg.call(drivers)
	var so: float = avg.call(sorters)
	var m: float = avg.call(managers)
	var me: float = avg.call(mechanics)
	if d > 0.0:
		base["speed_mult"] *= (1.0 + d * 0.15)
	if m > 0.0:
		base["satisfaction_mult"] *= (1.0 + m * 0.15)
	if me > 0.0:
		base["fuel_price_mult"] *= (1.0 - me * 0.1)
		base["accident_risk"] *= (1.0 - me * 0.2)
	for h in game.hubs:
		h.throughput_bonus += so * 0.25

func process_day(game: GameManager) -> void:
	var total := 0.0
	for s in game.staff:
		total += s.salary_per_day
	if total > 0.0:
		game.add_money(-int(total), "salary", "员工薪资")
	EventBus.reputation_changed.emit(game.reputation)

func hire(game: GameManager, role: int) -> Staff:
	if not game.spend(HIRE_FEE, "staff", "招聘 " + Staff.Role.keys()[role]):
		return null
	var s := Staff.new(game.uid("emp"), Staff.random_name(game.rng), role, game.rng.randf_range(0.3, 0.95))
	game.staff.append(s)
	game.recompute_baseline()
	EventBus.toast.emit("已招聘 %s：%s" % [s.role_name(), s.name])
	return s
