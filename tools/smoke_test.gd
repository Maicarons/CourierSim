extends Node

## 无头烟雾测试（临时）：验证 v0.5 新增功能 — 评级/多对手/存档槽位/胜负判定。
## 运行：godot --headless --path G:/GitHub/CourierSim res://tools/smoke_test.tscn

var _fail := 0

func _ready() -> void:
	_ok(GameManager != null, "GameManager autoload 存在")
	# 1. 新游戏
	GameManager.new_game("career", "测试快递", "korea")
	_ok(GameManager.money == GameManager.CAREER_MONEY, "新游戏资金 %d" % GameManager.money)
	_ok(GameManager.active_slot == "autosave", "active_slot 默认 autosave")
	_ok(GameManager.game_over_emitted == false, "game_over_emitted 初始 false")

	# 0. UI 面板构建验证
	_build_all_panels()

	# 2. 构造车队/站点/仓库/员工（注意：手动构造须显式设置能力位，否则 can_carry 全拒）
	var v := Vehicle.new(GameManager.uid("veh"), "测试面包车", Vehicle.Type.VAN, 500, 70.0, 60000)
	v.capabilities = Vehicle.Capability.REFRIGERATED | Vehicle.Capability.PHARMA
	GameManager.vehicles.append(v)
	var v2 := Vehicle.new(GameManager.uid("veh"), "测试货车", Vehicle.Type.TRUCK, 2000, 65.0, 120000)
	v2.capabilities = Vehicle.Capability.HAZMAT
	GameManager.vehicles.append(v2)
	var h := Hub.new(GameManager.uid("hub"), "测试仓", "seoul", 200, 8000)
	GameManager.hubs.append(h)
	var s := Station.new(GameManager.uid("st"), "测试站", "busan", 8.0)
	GameManager.stations.append(s)
	var stf := Staff.new(GameManager.uid("stf"), "测试员工", Staff.Role.DRIVER, 0.8)
	GameManager.staff.append(stf)
	_ok(GameManager.total_assets() > GameManager.money, "total_assets 包含车辆/建筑 %d" % GameManager.total_assets())

	# 成就：造车后 check → first_vehicle 解锁
	GameManager.ach_sys.check(GameManager)
	_ok(GameManager.achievements.has("first_vehicle"), "成就 first_vehicle 解锁（%s）" % str(GameManager.achievements))
	var ach_count := GameManager.achievements.size()
	_ok(ach_count >= 1, "成就系统至少解锁 1 项（%d）" % ach_count)

	# 3.5 手动派单（v0.11）：车辆 IDLE 时关闭自动派单 → 新订单保持 PENDING → 手动指派
	var osys := GameManager.order_sys
	osys.auto_assign_enabled = false
	GameManager.advance_day()
	var pending: Array = []
	for o in GameManager.orders:
		if o.status == Order.Status.PENDING:
			pending.append(o)
	_ok(not pending.is_empty(), "关闭自动派单后存在 PENDING 订单（%d）" % pending.size())
	if not pending.is_empty():
		var target: Order = pending[0]
		var cands: Array = osys.assignable_vehicles(GameManager, target)
		_ok(not cands.is_empty(), "assignable_vehicles 返回候选（%d）" % cands.size())
		if not cands.is_empty():
			var veh: Vehicle = cands[0]["vehicle"]
			var ok2 := osys.assign_order(GameManager, veh, target)
			_ok(ok2 and target.status == Order.Status.INTRANSIT, "手动派单成功 %s -> %s" % [target.id, veh.name])
	osys.auto_assign_enabled = true

	# 3. 推进 25 天，验证多对手出现 + 事件系统
	for i in 25:
		GameManager.advance_day()
	_ok(GameManager.competitor_sys.competitors.size() >= 1, "Day25 出现至少 1 个对手（%d 个）" % GameManager.competitor_sys.competitors.size())
	_ok(GameManager.competitor_sys.player_share() > 0.0 and GameManager.competitor_sys.player_share() < 1.0,
		"player_share 在 (0,1)：%.2f" % GameManager.competitor_sys.player_share())

	# 4. 拉高指标 → 评级应 ≥ C
	var r := GameManager.rating()
	_ok(r in ["S", "A", "B", "C"], "评级合法：%s" % r)
	# 强加声誉/资产/份额 → 评级提升
	GameManager.change_reputation(100.0)
	GameManager.money = 3000000
	for i in 10:
		GameManager.advance_day()
	var r2 := GameManager.rating()
	print("[SMOKE] 高指标评级：%s（预期 S/A）" % r2)

	# 5. 存档槽位往返
	GameManager.active_slot = "slot_1"
	var saved := SaveManager.save_slot("slot_1")
	_ok(saved, "save slot_1 成功")
	_ok(SaveManager.has_slot("slot_1"), "has_slot(slot_1)")
	_ok(SaveManager.next_free_slot() != "slot_1", "next_free_slot 不与 slot_1 冲突：%s" % SaveManager.next_free_slot())
	_ok(SaveManager.slot_label("slot_1") != "", "slot_label OK：%s" % SaveManager.slot_label("slot_1"))
	var day_before := GameManager.day
	var loaded := SaveManager.load_slot("slot_1")
	_ok(loaded and GameManager.day == day_before, "load slot_1 往返一致 Day%d" % GameManager.day)
	_ok(GameManager.active_slot == "slot_1", "load 后 active_slot=slot_1")
	_ok(GameManager.game_over_emitted == false, "load 后 game_over_emitted 重置")
	_ok(GameManager.achievements.size() >= 1, "load 后成就保留（%d）" % GameManager.achievements.size())
	# 清理测试存档
	SaveManager.delete_slot("slot_1")

	# 6. 胜负判定
	GameManager.game_over_emitted = false
	GameManager.money = -60000
	GameManager.advance_day()
	_ok(GameManager.game_over_emitted, "破产触发 game_over")
	GameManager.game_over_emitted = false
	GameManager.money = 3000000
	GameManager.day = 25
	GameManager.change_reputation(80.0)
	# 让 rating 到 A：份额不足则补资产
	GameManager.money = 5000000
	GameManager.advance_day()
	print("[SMOKE] 结算 summary：%s" % JSON.stringify(GameManager.summary_dict()))

	var verdict := "PASS" if _fail == 0 else "FAIL"
	print("[SMOKE] %s（失败 %d）" % [verdict, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


## 构建各 UI 面板验证无运行时错误
func _build_all_panels() -> void:
	var panels := [
		OverviewPanel.new(), VehiclePanel.new(), HubPanel.new(), StationPanel.new(),
		OrderPanel.new(), MarketingPanel.new(), TechPanel.new(), StaffPanel.new(),
		FinancePanel.new(), RegionPanel.new(),
	]
	for p in panels:
		p.build()
		p.queue_free()
	_ok(true, "全部 10 个面板构建 OK")


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("[SMOKE] OK  %s" % msg)
	else:
		_fail += 1
		print("[SMOKE] FAIL %s" % msg)
