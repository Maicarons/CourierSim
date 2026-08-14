class_name StationPanel
extends VBoxContainer

## 站点标签页：卡片行列出已有站点（可提升营销）+ 在新城市新建站点。

var _city_opt: OptionButton = null

func build() -> void:
	UI.header(self, Localization.t("panel.stations.title"))
	for s in GameManager.stations:
		var sub := "覆盖 %.0fkm · 宣传 Lv%d · 满意 %.0f%%" % [s.coverage_radius_km, s.marketing_level, s.satisfaction * 100.0]
		add_child(UI.info_row(Assets.get_image("bld_station"), s.name, sub,
			[{text = Localization.t("btn.promote") % s.marketing_upgrade_cost(), cb = _on_promote.bind(s), color = UI.ORANGE}]))
	UI.header(self, Localization.t("panel.stations.new"))
	_city_opt = UI.city_option()
	var brow := HBoxContainer.new()
	brow.add_child(_city_opt)
	brow.add_child(UI.button(Localization.t("btn.build") % StationSystem.STATION_COST, _on_build))
	add_child(brow)

func _on_build() -> void:
	if _city_opt == null:
		return
	var id: String = _city_opt.get_item_metadata(_city_opt.selected) if _city_opt.item_count > 0 else ""
	if id == "":
		EventBus.toast.emit(Localization.t("toast.select_city"))
		return
	GameManager.station_sys.build(GameManager, id)

func _on_promote(s: Station) -> void:
	GameManager.station_sys.upgrade_marketing(GameManager, s)
