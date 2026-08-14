extends Node
class_name VehicleSystem

## 车辆系统：购置/出售/调度车辆，每帧平滑推进行程，到达后结算配送与返程。

var catalog: Array = []   # 车辆规格目录（来自 vehicles.json）

func _ready() -> void:
	load_catalog()

func load_catalog() -> void:
	var path := "res://src/data/vehicles.json"
	if not FileAccess.file_exists(path):
		push_error("缺少车辆目录：" + path)
		return
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		catalog = parsed

## 按 Vehicle.Type 取规格
func spec(type: int) -> Dictionary:
	for c in catalog:
		if int(c.get("type", 0)) == type:
			return c
	return {}

func purchase(game: GameManager, type: int, home_city_id: String) -> Vehicle:
	var c := spec(type)
	if c.is_empty():
		EventBus.toast.emit(Localization.t("toast.unknown_vehicle"))
		return null
	var cost: int = int(c.get("cost", 0))
	if not game.spend(cost, "vehicle", "购置 " + str(c.get("label", "车辆"))):
		return null
	var v := Vehicle.new(game.uid("veh"), str(c.get("label", "车辆")), type,
		int(c.get("capacity_kg", 500)), float(c.get("speed_kmh", 70.0)), cost)
	v.km_per_day = float(c.get("km_per_day", 480.0))
	v.fuel_per_km = float(c.get("fuel_per_km", 0.0))
	v.maintenance_per_day = float(c.get("maintenance_per_day", 0.0))
	v.capabilities = int(c.get("cap", 0))
	v.home_city_id = home_city_id
	# 新车初始停驻 home 城市（地图坐标），避免显示在原点 (0,0)
	var home: City = RegionManager.current.get_city(home_city_id) if RegionManager.current != null else null
	if home != null:
		v.map_pos = RegionManager.local(home)
	game.vehicles.append(v)
	EventBus.vehicles_changed.emit()
	game.mark_objective("obj.buy_vehicle")
	return v

func sell(game: GameManager, v: Vehicle) -> void:
	if v.is_busy():
		EventBus.toast.emit(Localization.t("toast.vehicle_busy"))
		return
	if not v.owned:
		EventBus.toast.emit(Localization.t("toast.lease_cannot_sell"))
		return
	# 解除其订单
	for o in game.orders:
		if o.assigned_vehicle_id == v.id and o.status == Order.Status.INTRANSIT:
			o.status = Order.Status.PENDING
			o.assigned_vehicle_id = ""
	game.vehicles.erase(v)
	game.add_money(int(v.cost * 0.5), "vehicle", "出售 " + v.name)
	EventBus.vehicles_changed.emit()

## 租赁车辆：不扣全款，按日付租（车价 × 2%），可随时退租。
func lease(game: GameManager, type: int, home_city_id: String) -> Vehicle:
	var c := spec(type)
	if c.is_empty():
		EventBus.toast.emit(Localization.t("toast.unknown_vehicle"))
		return null
	var v := Vehicle.new(game.uid("veh"), str(c.get("label", "车辆")), type,
		int(c.get("capacity_kg", 500)), float(c.get("speed_kmh", 70.0)), int(c.get("cost", 0)))
	v.km_per_day = float(c.get("km_per_day", 480.0))
	v.fuel_per_km = float(c.get("fuel_per_km", 0.0))
	v.maintenance_per_day = float(c.get("maintenance_per_day", 0.0))
	v.capabilities = int(c.get("cap", 0))
	v.home_city_id = home_city_id
	# 租赁车同样初始停驻 home 城市
	var home_c: City = RegionManager.current.get_city(home_city_id) if RegionManager.current != null else null
	if home_c != null:
		v.map_pos = RegionManager.local(home_c)
	v.owned = false
	v.lease_daily = int(c.get("lease_daily", int(c.get("cost", 0)) * 2 / 100))
	game.vehicles.append(v)
	EventBus.toast.emit(Localization.t("toast.lease_ok") % [v.name, v.lease_daily])
	EventBus.vehicles_changed.emit()
	game.mark_objective("obj.buy_vehicle")
	return v

## 退租：仅空闲可退
func return_lease(game: GameManager, v: Vehicle) -> void:
	if v.owned:
		EventBus.toast.emit(Localization.t("toast.lease_owned"))
		return
	if v.is_busy():
		EventBus.toast.emit(Localization.t("toast.vehicle_busy"))
		return
	for o in game.orders:
		if o.assigned_vehicle_id == v.id and o.status == Order.Status.INTRANSIT:
			o.status = Order.Status.PENDING
			o.assigned_vehicle_id = ""
	game.vehicles.erase(v)
	EventBus.toast.emit(Localization.t("toast.lease_returned") % v.name)
	EventBus.vehicles_changed.emit()

## 每帧推进所有在途车辆（delta_hours 为游戏内小时）。车辆 24h 不间断运行。
func update_frame(delta_hours: float) -> void:
	if GameManager.company_name == "":
		return
	var delta_days := delta_hours / 24.0
	for v in GameManager.vehicles:
		if v.status != Vehicle.Status.ENROUTE and v.status != Vehicle.Status.RETURNING:
			continue
		var arrived := v.advance(delta_days * GameManager.modifiers.get("speed_mult", 1.0))
		if arrived:
			_handle_arrival(v)
	EventBus.map_updated.emit()

## 每小时结算（到达判定由 update_frame 平滑处理，此处仅触发 UI 刷新）
func process_hour(_game: GameManager) -> void:
	pass

## 车辆到达终点：结算油费，按当前阶段进入下一环（送达 / 返程结束）
func _handle_arrival(v: Vehicle) -> void:
	var seg_km := 0.0
	if v.route_path.size() >= 2:
		for i in range(1, v.route_path.size()):
			seg_km += v.route_path[i].distance_to(v.route_path[i - 1]) / 1000.0
	else:
		seg_km = v.route_from.distance_to(v.route_to) / 1000.0
	var fuel: int = int(seg_km * v.fuel_per_km * GameManager.modifiers.get("fuel_price_mult", 1.0))
	if fuel > 0:
		GameManager.add_money(-fuel, "fuel", v.name + " 油费")
	if v.status == Vehicle.Status.ENROUTE:
		_deliver(v)
	else:
		v.status = Vehicle.Status.IDLE
		v.current_order_id = ""
		v.assigned_hub_id = ""
		EventBus.map_updated.emit()

func _deliver(v: Vehicle) -> void:
	var order: Order = null
	for o in GameManager.orders:
		if o.id == v.current_order_id:
			order = o
			break
	if order != null:
		order.status = Order.Status.DELIVERED
		GameManager.add_money(order.reward, "delivery", "配送 %s" % order.id)
		GameManager.change_reputation(1.5)
		EventBus.orders_changed.emit()
		if not GameManager.objective_done[3]:
			GameManager.mark_objective("obj.first_delivery")
	# 返程到 home 城市（真实路线折线）
	var home: City = RegionManager.current.get_city(v.home_city_id) if v.home_city_id != "" else null
	if home != null:
		var from: Vector2 = v.map_pos
		var to: Vector2 = RegionManager.local(home)
		var dist := v.map_pos.distance_to(to)
		var days := GeoMath.travel_days(dist, v.speed_kmh)
		var path_m := _route_path_between_city(home.id)
		# 返程折线：若当前不在 home 且 home 与当前点间有烘焙路线则用之
		var home_pt: Vector2 = to
		var cur_city := _city_near(v.map_pos)
		if cur_city != null and cur_city.id != home.id:
			var r := RegionManager.current.route_between(cur_city.id, home.id)
			if not r.is_empty():
				path_m = r["path_m"]
				days = GeoMath.travel_days(float(r["dist_km"]) * 1000.0, v.speed_kmh)
		if path_m.size() >= 2:
			v.start_trip_path(path_m, days)
		else:
			v.start_trip(from, home_pt, days)
		v.status = Vehicle.Status.RETURNING
	else:
		v.status = Vehicle.Status.IDLE
		v.current_order_id = ""
	EventBus.vehicles_changed.emit()

## 取某城市到自身的折线（用于空驶到发货城市；无路线时返回空）
func _route_path_between_city(city_id: String) -> PackedVector2Array:
	var c: City = RegionManager.current.get_city(city_id)
	if c == null:
		return PackedVector2Array()
	return PackedVector2Array()

## 找离给定局部坐标最近的城市
func _city_near(pos: Vector2) -> City:
	var best: City = null
	var best_d := INF
	for c in RegionManager.current.cities:
		var d := pos.distance_to(RegionManager.local(c))
		if d < best_d:
			best_d = d
			best = c
	return best

## 每日结算（行程为每帧推进，此处仅占位）
func process_day(_game: GameManager) -> void:
	pass
