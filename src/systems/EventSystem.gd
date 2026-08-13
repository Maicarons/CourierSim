extends Node
class_name EventSystem

## 突发事件系统：每日有概率触发区域事件，临时改变修正系数或直接影响资金/声誉。

const EVENTS := [
	{"name": "燃油价格上涨", "name_en": "Fuel Price Surge", "code": "fuel", "mult": 1.4, "desc": "国际油价波动，今日油费 +40%", "desc_en": "Int'l oil price swing, fuel cost +40% today"},
	{"name": "台风预警", "name_en": "Typhoon Warning", "code": "speed", "mult": 0.65, "desc": "恶劣天气，车辆速度 -35%", "desc_en": "Bad weather, vehicle speed -35%"},
	{"name": "电商大促", "name_en": "E-commerce Sale", "code": "demand", "mult": 1.6, "desc": "购物节来临，订单需求 +60%", "desc_en": "Shopping festival, order demand +60%"},
	{"name": "道路事故拥堵", "name_en": "Road Accident Jam", "code": "accident", "mult": 2.0, "desc": "主干道事故，事故风险翻倍", "desc_en": "Main road accident, accident risk doubled"},
	{"name": "经济回暖", "name_en": "Economic Recovery", "code": "reward", "mult": 1.25, "desc": "市场景气，配送收益 +25%", "desc_en": "Market upturn, delivery reward +25%"},
	{"name": "地方节日", "name_en": "Local Festival", "code": "satisfaction", "mult": 1.2, "desc": "节日氛围，客户满意度上升", "desc_en": "Festive mood, customer satisfaction up"},
	{"name": "新能源补贴", "name_en": "Green Energy Subsidy", "code": "fuel", "mult": 0.7, "desc": "政府发放绿色物流补贴，今日油费 -30%", "desc_en": "Gov green-logistics subsidy, fuel cost -30% today"},
	{"name": "港口罢工", "name_en": "Port Strike", "code": "speed", "mult": 0.55, "desc": "港口工人罢工，海运时效 -45%", "desc_en": "Port workers on strike, sea transit -45%"},
	{"name": "仓储爆仓", "name_en": "Warehouse Overload", "code": "satisfaction", "mult": 0.72, "desc": "仓库爆仓，客户满意度下降", "desc_en": "Warehouses overloaded, satisfaction drops"},
	{"name": "企业大客户签约", "name_en": "Corporate Deal", "code": "reward", "mult": 1.5, "desc": "签下企业大客户，配送收益 +50%", "desc_en": "Corporate contract signed, reward +50%"},
]

func process_day(game: GameManager) -> void:
	if game.rng.randf() > 0.35:
		return
	# 沙盒模式可关闭随机事件
	if not bool(game.sandbox_cfg.get("events", true)):
		return
	# 区域特色事件优先：40% 概率从当前区域事件池抽取（若有）
	var ev: Dictionary = {}
	var local_events: Array = []
	if RegionManager.current != null:
		local_events = RegionManager.current.features.get("events", [])
	if not local_events.is_empty() and game.rng.randf() < 0.4:
		ev = local_events[game.rng.randi() % local_events.size()]
	else:
		ev = EVENTS[game.rng.randi() % EVENTS.size()]
	match ev["code"]:
		"fuel": game.modifiers["fuel_price_mult"] *= float(ev["mult"])
		"speed": game.modifiers["speed_mult"] *= float(ev["mult"])
		"demand": game.modifiers["demand_mult"] *= float(ev["mult"])
		"accident": game.modifiers["accident_risk"] *= float(ev["mult"])
		"reward": game.modifiers["reward_mult"] *= float(ev["mult"])
		"satisfaction": game.modifiers["satisfaction_mult"] *= float(ev["mult"])
	var nm: String = ev["name_en"] if (Localization.is_en() and ev.has("name_en") and ev["name_en"] != "") else ev["name"]
	var ds: String = ev["desc_en"] if (Localization.is_en() and ev.has("desc_en") and ev["desc_en"] != "") else ev["desc"]
	EventBus.toast.emit(Localization.t("toast.event") % [nm, ds])
