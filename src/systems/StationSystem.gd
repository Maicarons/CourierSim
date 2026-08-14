extends Node
class_name StationSystem

## 末端站点系统：建设、宣传升级，统计订单量与满意度。

const STATION_COST := 200000    # 末端站点基础造价（参考 TransRoute 20 万级）
const STATION_UPGRADE_BASE := 60000   # 宣传升级基础价

func process_day(game: GameManager) -> void:
	for s in game.stations:
		var cnt := 0
		for o in game.orders:
			if o.origin_id == s.city_id and (o.status == Order.Status.DELIVERED or o.status == Order.Status.INTRANSIT):
				cnt += 1
		s.daily_orders = cnt
		# 满意度缓慢回归目标（由覆盖与时效决定）
		var target := GeoMath.clampf(0.6 + float(cnt) * 0.05, 0.0, 1.0)
		s.satisfaction = lerp(s.satisfaction, target, 0.3) * game.modifiers.get("satisfaction_mult", 1.0)
		s.satisfaction = GeoMath.clampf(s.satisfaction, 0.0, 1.0)
	EventBus.stations_changed.emit()

func build(game: GameManager, city_id: String) -> Station:
	if not game.spend(STATION_COST, "station", "建设末端站点"):
		return null
	var c: City = RegionManager.current.get_city(city_id)
	var name: String = "站点 " + (c.name if c else city_id)
	var s := Station.new(game.uid("st"), name, city_id, 8.0)
	game.stations.append(s)
	EventBus.stations_changed.emit()
	game.mark_objective("obj.build_station")
	EventBus.toast.emit(Localization.t("toast.station_built") % name)
	return s

func upgrade_marketing(game: GameManager, s: Station) -> void:
	var cost := s.marketing_upgrade_cost()
	if not game.spend(cost, "marketing", s.name + " 宣传升级"):
		return
	s.upgrade_marketing()
	EventBus.stations_changed.emit()
	EventBus.toast.emit(Localization.t("toast.station_promo") % [s.name, s.marketing_level])
