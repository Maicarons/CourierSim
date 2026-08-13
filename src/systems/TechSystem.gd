extends Node
class_name TechSystem

## 科技树系统：加载科技定义，解锁并永久应用效果到基线修正。

func load_tree() -> void:
	GameManager.techs.clear()
	var path := "res://src/data/tech.json"
	if not FileAccess.file_exists(path):
		push_error("缺少科技树数据：" + path)
		return
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		for td in parsed:
			var t := TechNode.new(
				td.get("id", ""), td.get("name", ""),
				int(td.get("category", 0)), int(td.get("cost", 0)),
				td.get("description", ""), td.get("prerequisite", []),
				td.get("effect_code", ""), float(td.get("effect_value", 0.0)),
				td.get("name_en", ""), td.get("desc_en", ""))
			GameManager.techs.append(t)

## 把已解锁科技的效果叠加进基线修正
func contribute(game: GameManager, base: Dictionary) -> void:
	for t in game.techs:
		if not t.unlocked:
			continue
		_apply(game, t, base)

func _apply(game: GameManager, t: TechNode, base: Dictionary) -> void:
	match t.effect_code:
		"speed":
			base["speed_mult"] *= (1.0 + t.effect_value)
		"fuel":
			base["fuel_price_mult"] *= (1.0 - t.effect_value)
		"demand":
			base["demand_mult"] *= (1.0 + t.effect_value)
		"reward":
			base["reward_mult"] *= (1.0 + t.effect_value)
		"hubcap":
			for h in game.hubs:
				h.throughput_bonus += t.effect_value
		"satisfaction":
			base["satisfaction_mult"] *= (1.0 + t.effect_value)
		"accident":
			base["accident_risk"] *= (1.0 - t.effect_value)

func can_unlock(game: GameManager, t: TechNode) -> bool:
	return t.can_unlock(game.techs.map(func(x): return x.id if x.unlocked else ""))

func unlock(game: GameManager, t: TechNode) -> void:
	if t.unlocked:
		return
	if not can_unlock(game, t):
		EventBus.toast.emit(Localization.t("toast.tech_prereq"))
		return
	if not game.spend(t.cost, "tech", "研发 " + t.tech_name):
		return
	t.unlocked = true
	game.recompute_baseline()
	game.mark_objective("obj.unlock_tech")
	EventBus.toast.emit(Localization.t("toast.tech_unlocked") % t.display_name())
