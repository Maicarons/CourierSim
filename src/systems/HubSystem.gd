extends Node
class_name HubSystem

## 中转仓库系统：建设、升级，每日重置吞吐计数。

const HUB_BASE_COST := 600000   # 中转仓库基础造价（参考 TransRoute 中转枢纽 250 万级，取其下级）
const HUB_BASE_CAP := 200

func process_day(game: GameManager) -> void:
	for h in game.hubs:
		h.used_today = 0

func build(game: GameManager, city_id: String) -> Hub:
	if not game.spend(HUB_BASE_COST, "hub", "建设中转仓库"):
		return null
	var c: City = RegionManager.current.get_city(city_id)
	var name: String = "中转库 " + (c.name if c else city_id)
	var h := Hub.new(game.uid("hub"), name, city_id, HUB_BASE_CAP, HUB_BASE_COST)
	game.hubs.append(h)
	EventBus.hubs_changed.emit()
	game.mark_objective("obj.build_hub")
	EventBus.toast.emit(Localization.t("toast.hub_built") % name)
	return h

func upgrade(game: GameManager, h: Hub) -> void:
	var cost := h.upgrade_cost()
	if not game.spend(cost, "hub", h.name + " 升级"):
		return
	h.upgrade()
	EventBus.hubs_changed.emit()
	EventBus.toast.emit(Localization.t("toast.hub_upgraded") % [h.name, h.level])
