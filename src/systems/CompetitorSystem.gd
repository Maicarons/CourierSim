extends Node
class_name CompetitorSystem

## 竞争对手系统（v2 深化）：
##  - 多对手：随游戏天数逐个出现（最多 3 家），各有名称、市场力、扩张资金
##  - 玩家完成配送 → 玩家份额上升；对手每日自然扩张
##  - 对手偶发「促销活动」：短期拉低玩家份额并产生事件提示
##  - 玩家市场占有率 = 1 - Σ对手份额

const POOL := [
	{"name": "环宇速运", "name_en": "HuanYu Express", "power": 12.0},
	{"name": "极速物流", "name_en": "SpeedGo Logistics", "power": 10.0},
	{"name": "顺风快达", "name_en": "ShunFeng Fast", "power": 9.0},
	{"name": "天舟速递", "name_en": "SkyBoat Courier", "power": 8.0},
]

## 单个对手运行态：{name, name_en, power, share}
var competitors: Array[Dictionary] = []
var comp_money: int = 50000

## 每 N 天解锁一个新对手
const SPAWN_DAY := 15
const MAX_COMPETITORS := 3
const PROMO_CHANCE := 0.12   # 每日对手促销概率


func process_day(game: GameManager) -> void:
	# 开局即有一家初始对手（避免玩家份额为 100% 的失真）
	if competitors.is_empty():
		_add_initial(game)
	# 按天数扩充对手池
	if game.day % SPAWN_DAY == 0 and competitors.size() < MAX_COMPETITORS \
			and competitors.size() < POOL.size() - 1:
		_add_competitor(game)
	# 对手每日扩张（玩家交付越多压制越强：每 50 单交付压制减半增速）
	var delivered := game.delivered_count()
	var pressure := 1.0 + float(delivered) * 0.02
	for c in competitors:
		c["share"] = GeoMath.clampf(c["share"] * (1.0 + 0.012 / pressure), 0.0, 0.6)
	# 玩家交付主动蚕食对手份额：累计交付越多，市占越高（每 10 单约抢 1%）
	var total := 0.0
	for c in competitors:
		total += c["share"]
	if total > 0.02:
		var steal := clampf(float(delivered) * 0.0003, 0.0, 0.02)
		for c in competitors:
			var share_of_total: float = c["share"] / total
			c["share"] = GeoMath.clampf(c["share"] - steal * share_of_total, 0.02, 0.6)
	comp_money += int(600.0 * (RegionManager.current.difficulty if RegionManager.current else 1) \
		* game.rng.randf_range(0.5, 1.5))
	# 对手促销事件：随机一家发起，拉低玩家份额
	if not competitors.is_empty() and game.rng.randf() < PROMO_CHANCE:
		var c: Dictionary = competitors[game.rng.randi() % competitors.size()]
		var cn: String = c["name_en"] if (Localization.is_en() and c.get("name_en", "") != "") else c["name"]
		var before: float = player_share()
		var dip: float = game.rng.randf_range(0.02, 0.05)
		c["share"] = GeoMath.clampf(c["share"] + dip, 0.0, 0.7)
		if player_share() < before - 0.01:
			EventBus.toast.emit(Localization.t("toast.comp_promo") % cn)
	# 总份额归一化到 <= 0.95
	_normalize_share()


## 开局初始对手：较强市场份额（0.5~0.6），让玩家从"挑战者"起步
func _add_initial(game: GameManager) -> void:
	var c := {
		"name": POOL[0]["name"], "name_en": POOL[0]["name_en"],
		"power": POOL[0]["power"], "idx": 0,
		"share": 0.5 + game.rng.randf_range(0.0, 0.08),
	}
	competitors.append(c)
	var cn: String = c["name_en"] if (Localization.is_en() and c.get("name_en", "") != "") else c["name"]
	EventBus.toast.emit(Localization.t("toast.comp_new") % cn)


func _add_competitor(game: GameManager) -> void:
	var taken := {}
	for c in competitors:
		taken[c.get("idx", -1)] = true
	var idx := -1
	for i in POOL.size():
		if not taken.has(i):
			idx = i
			break
	if idx < 0:
		return
	var p: Dictionary = POOL[idx]
	var c := {
		"name": p["name"], "name_en": p["name_en"],
		"power": p["power"], "idx": idx,
		"share": 0.06 + game.rng.randf_range(0.0, 0.05),
	}
	competitors.append(c)
	var cn: String = c["name_en"] if (Localization.is_en() and c.get("name_en", "") != "") else c["name"]
	EventBus.toast.emit(Localization.t("toast.comp_new") % cn)


func _normalize_share() -> void:
	var total := 0.0
	for c in competitors:
		total += c["share"]
	if total > 0.9:
		var scale := 0.9 / total
		for c in competitors:
			c["share"] *= scale


## 玩家市场占有率（用于 UI 展示与评级）
func player_share() -> float:
	var total := 0.0
	for c in competitors:
		total += c["share"]
	return GeoMath.clampf(1.0 - total, 0.0, 1.0)


## 对手显示名（按当前语言）
func comp_display(c: Dictionary) -> String:
	if Localization.is_en() and c.get("name_en", "") != "":
		return c["name_en"]
	return c["name"]
