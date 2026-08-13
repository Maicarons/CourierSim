extends Node
class_name AchievementSystem

## 成就系统：数据驱动（src/data/achievements.json）。
## check() 遍历未解锁成就，条件满足 → 解锁（写入 GameManager.achievements）+ toast + SFX。
## 在每日结算与状态同步时自动调用（代价极小）。

var defs: Array[Dictionary] = []


func load_defs() -> void:
	defs.clear()
	var path := "res://src/data/achievements.json"
	if not FileAccess.file_exists(path):
		push_error("缺少成就数据：" + path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		for d in parsed:
			defs.append(d)


func check(game: GameManager) -> void:
	if defs.is_empty():
		load_defs()
	for d in defs:
		var id: String = d.get("id", "")
		if game.achievements.has(id):
			continue
		if _metric_value(game, d.get("metric", "")) >= float(d.get("count", 1)):
			game.achievements.append(id)
			EventBus.achievement_unlocked.emit(id)
			EventBus.toast.emit(Localization.t("toast.ach") % _display_name(d))


func _metric_value(game: GameManager, metric: String) -> float:
	match metric:
		"vehicles":
			return game.vehicles.size()
		"delivered":
			return game.delivered_count()
		"hubs":
			return game.hubs.size()
		"stations":
			return game.stations.size()
		"staff":
			return game.staff.size()
		"techs":
			var n := 0
			for t in game.techs:
				if t.unlocked:
					n += 1
			return n
		"assets":
			return game.total_assets()
		"share":
			return game.competitor_sys.player_share() * 100.0
		"days":
			return game.day
		"regions":
			return game.unlocked_region_ids.size()
	return 0.0


## 当前语言成就显示名
func display_name(d: Dictionary) -> String:
	return _display_name(d)


func _display_name(d: Dictionary) -> String:
	if Localization.is_en() and d.get("name_en", "") != "":
		return d["name_en"]
	return d.get("name", d.get("id", ""))
