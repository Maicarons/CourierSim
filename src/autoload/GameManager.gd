extends Node

## 预加载核心类与系统，确保全局 class_name 在 Autoload 解析阶段即被注册，
## 避免 "Could not find type" 的解析顺序问题。
const _PreCargo := preload("res://src/core/CargoType.gd")
const _PreGeo := preload("res://src/core/GeoMath.gd")
const _PreCity := preload("res://src/core/City.gd")
const _PreRegion := preload("res://src/core/Region.gd")
const _PreVeh := preload("res://src/core/Vehicle.gd")
const _PreHub := preload("res://src/core/Hub.gd")
const _PreSt := preload("res://src/core/Station.gd")
const _PreOrd := preload("res://src/core/Order.gd")
const _PreStaff := preload("res://src/core/Staff.gd")
const _PreTech := preload("res://src/core/TechNode.gd")
const _PreOS := preload("res://src/systems/OrderSystem.gd")
const _PreVS := preload("res://src/systems/VehicleSystem.gd")
const _PreHS := preload("res://src/systems/HubSystem.gd")
const _PreSS := preload("res://src/systems/StationSystem.gd")
const _PreMS := preload("res://src/systems/MarketingSystem.gd")
const _PreTS := preload("res://src/systems/TechSystem.gd")
const _PreStfS := preload("res://src/systems/StaffSystem.gd")
const _PreES := preload("res://src/systems/EventSystem.gd")
const _PreFS := preload("res://src/systems/FinanceSystem.gd")
const _PreCS := preload("res://src/systems/CompetitorSystem.gd")
const _PreAch := preload("res://src/systems/AchievementSystem.gd")
const _PreSave := preload("res://src/save/GameSave.gd")

## 中央游戏状态与模拟循环。拥有全部实体集合，驱动每日系统结算，
## 并提供存档序列化。各子系统通过 class_name 引用本单例。

const SAVE_VERSION := 1
const CAREER_MONEY := 300000
const SANDBOX_MONEY := 1000000
const LOAN_RATE := 0.0008   # 每日贷款利息

# ---- 全局状态 ----
var mode: String = "career"          # career / sandbox
var company_name: String = ""
var day: int = 1
var money: int = 0
var reputation: float = 50.0
var id_counter: int = 0
var tutorial_step: int = 0
var game_over_emitted := false
var active_slot: String = "autosave"   # 当前游戏绑定的存档槽位

# ---- 实体集合 ----
var vehicles: Array[Vehicle] = []
var hubs: Array[Hub] = []
var stations: Array[Station] = []
var orders: Array[Order] = []
var staff: Array[Staff] = []
var techs: Array[TechNode] = []
var unlocked_region_ids: Array = []
var competitors: Array = []   # 由 CompetitorSystem 填充

# ---- 事件/科技等产生的全局修正 ----
var modifiers := {
	"fuel_price_mult": 1.0,
	"speed_mult": 1.0,
	"demand_mult": 1.0,
	"satisfaction_mult": 1.0,
	"accident_risk": 1.0,
	"reward_mult": 1.0,
}
## 基线修正：由科技树与员工贡献，每日重置为基线后再叠加事件临时修正。
var base_modifiers: Dictionary = {
	"fuel_price_mult": 1.0, "speed_mult": 1.0, "demand_mult": 1.0,
	"satisfaction_mult": 1.0, "accident_risk": 1.0, "reward_mult": 1.0,
}

# ---- 子系统 ----
var order_sys: OrderSystem
var vehicle_sys: VehicleSystem
var hub_sys: HubSystem
var station_sys: StationSystem
var marketing_sys: MarketingSystem
var tech_sys: TechSystem
var staff_sys: StaffSystem
var event_sys: EventSystem
var finance_sys: FinanceSystem
var competitor_sys: CompetitorSystem
var ach_sys: AchievementSystem

var rng := RandomNumberGenerator.new()
var ledger: Array = []   # {day, amount, category, label}
var achievements: Array[String] = []   # 已解锁成就 id
## 沙盒自由参数：{funds_mult: float, events: bool, competition: float}（仅沙盒模式生效）
var sandbox_cfg := {"funds_mult": 1.0, "events": true, "competition": 1.0}

func _ready() -> void:
	rng.randomize()
	order_sys = OrderSystem.new()
	vehicle_sys = VehicleSystem.new()
	hub_sys = HubSystem.new()
	station_sys = StationSystem.new()
	marketing_sys = MarketingSystem.new()
	tech_sys = TechSystem.new()
	staff_sys = StaffSystem.new()
	event_sys = EventSystem.new()
	finance_sys = FinanceSystem.new()
	competitor_sys = CompetitorSystem.new()
	ach_sys = AchievementSystem.new()
	add_child(order_sys); add_child(vehicle_sys); add_child(hub_sys)
	add_child(station_sys); add_child(marketing_sys); add_child(tech_sys)
	add_child(staff_sys); add_child(event_sys); add_child(finance_sys)
	add_child(competitor_sys); add_child(ach_sys)
	ach_sys.load_defs()
	recompute_baseline()

# ================= 生命周期 =================

func new_game(p_mode: String, p_company: String, region_id: String) -> void:
	mode = p_mode
	company_name = p_company
	RegionManager.set_current(region_id)
	day = 1
	reputation = 50.0
	money = CAREER_MONEY if mode == "career" else int(SANDBOX_MONEY * float(sandbox_cfg.get("funds_mult", 1.0)))
	id_counter = 0
	tutorial_step = 0
	game_over_emitted = false
	active_slot = "autosave"
	achievements.clear()
	ach_sys.load_defs()
	TimeSystem.speed_index = 1
	TimeSystem.paused = false
	TimeSystem.current_day_fraction = 0.0
	TimeSystem.total_days = 0.0
	_reset_modifiers()
	vehicles.clear(); hubs.clear(); stations.clear(); orders.clear()
	staff.clear(); techs.clear(); competitors.clear(); ledger.clear()
	unlocked_region_ids.clear()
	for r in RegionManager.regions:
		if r.unlock_cost == 0:
			unlocked_region_ids.append(r.id)
	tech_sys.load_tree()
	# 起始资产：在首府城市赠送一个中转仓库
	var cap := capital_city()
	if cap != null:
		var h := Hub.new(uid("hub"), "%s %s" % [Localization.t("hub.hq"), cap.display_name()], cap.id, 200, 8000)
		hubs.append(h)
	EventBus.company_ready.emit()
	EventBus.toast.emit(Localization.t("toast.welcome") % [RegionManager.current.display_name(), company_name])
	_sync_all()

func capital_city() -> City:
	var best: City = null
	for c in RegionManager.current.cities:
		if best == null or (c.tier < best.tier) or (c.tier == best.tier and c.population > best.population):
			best = c
	return best

func _reset_modifiers() -> void:
	modifiers = {
		"fuel_price_mult": 1.0, "speed_mult": 1.0, "demand_mult": 1.0,
		"satisfaction_mult": 1.0, "accident_risk": 1.0, "reward_mult": 1.0,
	}

## 重新计算基线修正（科技 + 员工贡献），并应用到 base_modifiers。
func recompute_baseline() -> void:
	base_modifiers = {
		"fuel_price_mult": 1.0, "speed_mult": 1.0, "demand_mult": 1.0,
		"satisfaction_mult": 1.0, "accident_risk": 1.0, "reward_mult": 1.0,
	}
	for h in hubs:
		h.throughput_bonus = 0.0
	tech_sys.contribute(self, base_modifiers)
	staff_sys.contribute(self, base_modifiers)
	modifiers = base_modifiers.duplicate()

func uid(prefix: String) -> String:
	id_counter += 1
	return "%s_%d" % [prefix, id_counter]

# ================= 模拟推进 =================

## 每帧推进：平滑移动车辆（按分数天）
func tick_frame(delta_days: float) -> void:
	if company_name == "":
		return
	vehicle_sys.update_frame(delta_days)

## 每日结算：依次驱动各子系统
func advance_day() -> void:
	if company_name == "" or game_over_emitted:
		return
	day += 1
	modifiers = base_modifiers.duplicate()   # 重置为科技/员工基线
	event_sys.process_day(self)
	marketing_sys.process_day(self)
	order_sys.process_day(self)
	hub_sys.process_day(self)
	station_sys.process_day(self)
	staff_sys.process_day(self)
	finance_sys.process_day(self)
	competitor_sys.process_day(self)
	_check_game_over()
	EventBus.day_changed.emit(day)
	_sync_all()

func _check_game_over() -> void:
	if game_over_emitted:
		return
	if money < -50000:
		game_over_emitted = true
		EventBus.game_over.emit("game.over.bankrupt")
		return
	# 生涯模式：达成 S 评级（且至少运营 40 天）视为通关胜利；
	# A 级不结束，给玩家继续冲击 S 的空间
	if mode == "career" and day >= 40 and rating() == "S":
		game_over_emitted = true
		EventBus.game_over.emit("game.over.victory")

# ================= 评级 / 结算统计 =================

## 总资产（现金 + 车辆购置成本 + 建筑残值）
func total_assets() -> int:
	var a := money
	for v in vehicles:
		a += int(v.cost * 0.8)
	for h in hubs:
		a += h.level * 5000
	for s in stations:
		a += 3000
	return a

## 累计送达订单数
func delivered_count() -> int:
	var n := 0
	for o in orders:
		if o.status == Order.Status.DELIVERED:
			n += 1
	return n

## 生涯评级：S/A/B/C（声誉、市占、资产综合）
func rating() -> String:
	var score := 0
	if reputation >= 80.0:
		score += 2
	elif reputation >= 60.0:
		score += 1
	if competitor_sys.player_share() >= 0.35:
		score += 2
	elif competitor_sys.player_share() >= 0.20:
		score += 1
	if total_assets() >= 1500000:
		score += 2
	elif total_assets() >= 800000:
		score += 1
	if score >= 5:
		return "S"
	if score >= 4:
		return "A"
	if score >= 2:
		return "B"
	return "C"

## 结算面板展示数据
func summary_dict() -> Dictionary:
	return {
		"days": day,
		"money": money,
		"assets": total_assets(),
		"share": int(competitor_sys.player_share() * 100.0),
		"reputation": int(reputation),
		"delivered": delivered_count(),
		"rating": rating(),
		"vehicles": vehicles.size(),
		"hubs": hubs.size(),
		"stations": stations.size(),
		"staff": staff.size(),
	}

func _sync_all() -> void:
	EventBus.vehicles_changed.emit()
	EventBus.hubs_changed.emit()
	EventBus.stations_changed.emit()
	EventBus.orders_changed.emit()
	EventBus.money_changed.emit(money)
	EventBus.reputation_changed.emit(reputation)
	EventBus.map_updated.emit()
	if ach_sys != null:
		ach_sys.check(self)

# ================= 资金 =================

func add_money(amount: int, category: String = "misc", label: String = "") -> void:
	money += amount
	_ledger(amount, category, label)
	EventBus.money_changed.emit(money)

func spend(amount: int, category: String = "misc", label: String = "") -> bool:
	if money < amount:
		EventBus.toast.emit(Localization.t("toast.insufficient") % amount)
		return false
	money -= amount
	_ledger(-amount, category, label)
	EventBus.money_changed.emit(money)
	return true

func can_afford(amount: int) -> bool:
	return money >= amount

func _ledger(amount: int, category: String, label: String) -> void:
	ledger.append({"day": day, "amount": amount, "category": category, "label": label})
	if ledger.size() > 300:
		ledger.pop_front()

func change_reputation(delta: float) -> void:
	reputation = GeoMath.clampf(reputation + delta, 0.0, 100.0)
	EventBus.reputation_changed.emit(reputation)

# ================= 教程/目标（生涯模式）=================

var objectives := [
	"obj.buy_vehicle",
	"obj.build_hub",
	"obj.build_station",
	"obj.first_delivery",
	"obj.unlock_tech",
]
var objective_done := [false, false, false, false, false]

func mark_objective(text: String) -> void:
	if mode != "career":
		return
	for i in objectives.size():
		if not objective_done[i] and objectives[i] == text:
			objective_done[i] = true
			EventBus.toast.emit(Localization.t("toast.obj_done") % Localization.t(text))
			return

# ================= 存档序列化（委托 GameSave） =================

## 序列化逻辑集中在 src/save/GameSave.gd，本单例仅做转发，保持精简。

func to_dict() -> Dictionary:
	return GameSave.to_dict(self)

func from_dict(d: Dictionary) -> void:
	GameSave.from_dict(self, d)
