class_name VehiclePanel
extends VBoxContainer

## 车辆标签页：卡片行列出当前车队 + 可购置车型。操作经由 GameManager.vehicle_sys 触发。

func build() -> void:
	UI.header(self, Localization.t("panel.vehicles.title"))
	for v in GameManager.vehicles:
		var home: City = RegionManager.current.get_city(v.home_city_id) if RegionManager.current != null else null
		var hname := home.display_name() if home != null else "-"
		var lease_tag := Localization.t("veh.leased") if not v.owned else ""
		var sub := "%s · %s · 驻车 %s%s" % [v.type_name(), UI.veh_status_name(v.status), hname, lease_tag]
		var actions: Array = []
		if not v.owned:
			actions.append({text = Localization.t("btn.return_lease"), cb = _on_return_lease.bind(v), color = UI.ORANGE})
		actions.append({text = Localization.t("btn.sell"), cb = _on_sell.bind(v), color = UI.RED})
		add_child(UI.info_row(Assets.get_image("veh_van"), v.name, sub, actions))
	UI.header(self, Localization.t("panel.vehicles.buy"))
	for i in Vehicle.Type.size():
		var c := GameManager.vehicle_sys.spec(i)
		if c.is_empty():
			continue
		var vname: String = UI.vehicle_type_name(i)
		if vname == "":
			vname = c.get("label", "")
		var sub := "载重 %dkg · 时速 %d · 购 %d元 · 租 %d/天" % [
			c.get("capacity_kg"), c.get("speed_kmh"), c.get("cost"), c.get("lease_daily", 0)]
		add_child(UI.info_row(Assets.get_image("veh_van"), vname, sub,
			[{text = Localization.t("btn.buy"), cb = _on_buy.bind(i), color = UI.GREEN},
			 {text = Localization.t("btn.lease"), cb = _on_lease.bind(i), color = UI.BLUE}]))

func _on_buy(type: int) -> void:
	var cap := GameManager.capital_city()
	var home := cap.id if cap else ""
	GameManager.vehicle_sys.purchase(GameManager, type, home)

func _on_lease(type: int) -> void:
	var cap := GameManager.capital_city()
	var home := cap.id if cap else ""
	GameManager.vehicle_sys.lease(GameManager, type, home)

func _on_return_lease(v: Vehicle) -> void:
	GameManager.vehicle_sys.return_lease(GameManager, v)

func _on_sell(v: Vehicle) -> void:
	GameManager.vehicle_sys.sell(GameManager, v)
