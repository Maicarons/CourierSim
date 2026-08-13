extends Node

## 数值平衡长局模拟（临时）：AI 策略自动经营 120 天，
## 输出资金/交付/市占/声誉/评级曲线，辅助调优经济数值。
## 运行：godot --headless --path G:/GitHub/CourierSim res://tools/balance_sim.tscn --quit-after 400

const DAYS := 120

## 车队策略：van / truck / mix（命令行 --strategy=xxx）
var _strategy := "van"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--strategy="):
			_strategy = a.trim_prefix("--strategy=")
	GameManager.new_game("career", "平衡测试", "korea")
	TimeSystem.set_speed(0)   # 暂停真实时间驱动，改由模拟显式推进车队
	print("[BAL] 起始资金 %d · 策略 %s" % [GameManager.money, _strategy])
	var bankrupt := false
	var milestone_day := 0
	for day in DAYS:
		_ai_turn()
		GameManager.tick_frame(1.0)   # 显式推进一天的车队行程
		GameManager.advance_day()
		if GameManager.money < 0 and not bankrupt:
			bankrupt = true
			print("[BAL] ⚠ 资金转负：Day %d (money=%d)" % [GameManager.day, GameManager.money])
		if GameManager.game_over_emitted:
			print("[BAL] ⛔ 游戏结束于 Day %d" % GameManager.day)
			break
		if day >= milestone_day:
			milestone_day += 20
			_snapshot(day)

	_snapshot(DAYS)
	var s := GameManager.summary_dict()
	print("[BAL] 结算：%s" % JSON.stringify(s))
	print("[BAL] 评级 %s · 破产 %s" % [s["rating"], str(bankrupt)])
	get_tree().quit(0)


func _ai_turn() -> void:
	var g := GameManager
	# 按策略购车（优先扩运力）
	if g.day % 2 == 0 and g.vehicles.size() < 8 and g.money > 50000:
		var c := _random_city(true)
		if c != null:
			var vtype := Vehicle.Type.VAN
			if _strategy == "truck":
				vtype = Vehicle.Type.TRUCK
			elif _strategy == "mix":
				vtype = Vehicle.Type.TRUCK if g.vehicles.size() % 3 == 2 else Vehicle.Type.VAN
			g.vehicle_sys.purchase(g, vtype, c.id)
	# 每 4 天建 1 个站点（最多 6 个）
	if g.day % 4 == 0 and g.stations.size() < 6 and g.money > 50000:
		var c := _random_city(false)
		if c != null:
			g.station_sys.build(g, c.id)
	# 每 8 天建 1 个仓（最多 2 个）
	if g.day % 8 == 0 and g.hubs.size() < 2 and g.money > 100000:
		var c := _random_city(true)
		if c != null:
			g.hub_sys.build(g, c.id)
	# 招聘（最多 4 人）
	if g.day % 6 == 0 and g.staff.size() < 4 and g.money > 80000:
		var st := Staff.new(g.uid("stf"), Staff.random_name(g.rng), Staff.Role.DRIVER, g.rng.randf_range(0.4, 0.9))
		g.staff.append(st)
		EventBus.hubs_changed.emit()
	# 解锁可解锁科技
	if g.day % 8 == 0 and g.money > 200000:
		for t in g.techs:
			if not t.unlocked and g.tech_sys.can_unlock(g, t):
				g.tech_sys.unlock(g, t)
				break


func _random_city(any: bool) -> City:
	var pool := []
	for c in RegionManager.current.cities:
		if c.id == "seoul":
			continue
		pool.append(c)
	if pool.is_empty():
		return null
	return pool[GameManager.rng.randi() % pool.size()]


func _snapshot(day: int) -> void:
	var g := GameManager
	print("[BAL] Day%-3d 资金%9d 资产%9d 交付%3d 车%2d 站%2d 仓%2d 员%2d 市占%3d%% 声誉%3d 评级%s" % [
		day, g.money, g.total_assets(), g.delivered_count(),
		g.vehicles.size(), g.stations.size(), g.hubs.size(), g.staff.size(),
		int(g.competitor_sys.player_share() * 100.0), int(g.reputation), g.rating()])
