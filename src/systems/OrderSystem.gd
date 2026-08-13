extends Node
class_name OrderSystem

## 订单系统：每日按市场需求生成订单，自动/手动分配车辆，处理超时失败。
## 收益与时限基于真实城市距离计算（Haversine + 绕路系数）。

## 自动派单开关：开启时每日自动把待分配订单派给合适车辆；
## 关闭后玩家通过订单面板「派单」按钮手动控制（模拟经营标准操控）。
var auto_assign_enabled := true

func process_day(game: GameManager) -> void:
	if RegionManager.current == null:
		return
	var count := compute_spawn(game)
	for i in count:
		spawn_one(game)
	# 超时判定
	for o in game.orders:
		if o.status == Order.Status.PENDING or o.status == Order.Status.ASSIGNED or o.status == Order.Status.INTRANSIT:
			if o.is_overdue(game.day):
				fail_order(game, o)
	auto_assign(game)
	EventBus.orders_changed.emit()

## 生单量：受站点数量、城市需求、市场宣传与难度影响
func compute_spawn(game: GameManager) -> int:
	var base: int = max(1, int(float(game.stations.size()) * 0.8))
	var demand: float = game.modifiers["demand_mult"]
	var diff: int = RegionManager.current.difficulty
	# 区域特色：需求加成（如越南/马来西亚增速市场）
	var region_bonus: float = 1.0
	if RegionManager.current != null:
		region_bonus = float(RegionManager.current.features.get("demand_bonus", 1.0))
	var mult: float = (0.6 + demand * 0.5) / float(diff) * region_bonus
	var n := int(round(base * mult * (0.6 + game.rng.randf() * 0.6)))
	return max(1, n)

func weighted_city(game: GameManager) -> City:
	var region: Region = RegionManager.current
	var pool: Array[City] = []
	for c in region.cities:
		var w := int(max(1, c.base_demand * 10))
		# 有站点的城市权重更高
		for s in game.stations:
			if s.city_id == c.id:
				w += 8 * (s.marketing_level + 1)
		for i in w:
			pool.append(c)
	if pool.is_empty():
		# 退化为按需求选
		var best: City = region.cities[0]
		for c in region.cities:
			if c.base_demand > best.base_demand:
				best = c
		return best
	return pool[game.rng.randi() % pool.size()]

func spawn_one(game: GameManager) -> void:
	var region: Region = RegionManager.current
	var origin := weighted_city(game)
	var dest := origin
	var guard := 0
	while dest == origin and guard < 20:
		dest = region.cities[game.rng.randi() % region.cities.size()]
		guard += 1
	if dest == origin:
		return
	# 货种：以标准为主，少量特殊
	var cargo := CargoType.Type.STANDARD
	var roll := game.rng.randf()
	if roll > 0.85:
		cargo = CargoType.Type.COLDCHAIN
	elif roll > 0.78:
		cargo = CargoType.Type.PHARMA
	elif roll > 0.72:
		cargo = CargoType.Type.HAZMAT
	elif roll > 0.68:
		cargo = CargoType.Type.INTERNATIONAL
	# 降级保护：若当前车队没有能运该货种的车辆，降为标准货（避免无人接单卡死）
	if cargo != CargoType.Type.STANDARD and not _has_carrier(game, cargo):
		cargo = CargoType.Type.STANDARD
	var weight := 2.0 + game.rng.randf() * 28.0
	if cargo == CargoType.Type.HAZMAT:
		weight = 50.0 + game.rng.randf() * 200.0
	var o := Order.new(game.uid("ord"), origin.id, dest.id, cargo, weight)
	var dist := GeoMath.city_distance(origin, dest)
	o.distance_m = dist
	o.distance_days = GeoMath.travel_days(dist, 80.0)
	o.reward = reward_for(game, dist, cargo, weight)
	o.created_day = game.day
	var buffer := 4
	if cargo == CargoType.Type.INTERNATIONAL:
		buffer = 6
	o.deadline_day = game.day + int(ceil(o.distance_days)) + buffer
	o.status = Order.Status.PENDING
	game.orders.append(o)

func reward_for(game: GameManager, distance_m: float, cargo: int, weight: float) -> int:
	var km := distance_m / 1000.0
	var base := km * (2.2 + weight * 0.12)
	var r: int = int(base * CargoType.reward_mult(cargo) * game.modifiers.get("reward_mult", 1.0))
	return max(50, r)

## 车队中是否存在能运该货种的车辆
func _has_carrier(game: GameManager, cargo: int) -> bool:
	for v in game.vehicles:
		if v.can_carry(cargo):
			return true
	return false

## 自动分配：把待分配订单派给合适的空闲车辆（受 auto_assign_enabled 控制）
func auto_assign(game: GameManager) -> void:
	if not auto_assign_enabled:
		return
	for o in game.orders:
		if o.status != Order.Status.PENDING:
			continue
		var v := find_assignable_vehicle(game, o)
		if v != null:
			assign_order(game, v, o)

## 手动派单候选：可承运 + 空闲 + 载重足够的车辆，按距 origin 距离升序
func assignable_vehicles(game: GameManager, o: Order) -> Array:
	var list: Array = []
	var oc: City = RegionManager.current.get_city(o.origin_id)
	for v in game.vehicles:
		if v.is_busy():
			continue
		if not v.can_carry(o.cargo_type):
			continue
		if o.weight_kg > v.capacity_kg:
			continue
		var score := 0.0
		if oc != null:
			var home: City = RegionManager.current.get_city(v.home_city_id)
			if home != null:
				score = GeoMath.city_distance(home, oc) / 1000.0
		list.append({"vehicle": v, "dist_km": score})
	list.sort_custom(func(a, b): return a["dist_km"] < b["dist_km"])
	return list

func find_assignable_vehicle(game: GameManager, o: Order) -> Vehicle:
	var best: Vehicle = null
	var best_score := INF
	for v in game.vehicles:
		if v.is_busy():
			continue
		if not v.can_carry(o.cargo_type):
			continue
		if o.weight_kg > v.capacity_kg:
			continue
		# 优先 home_city 接近 origin 的车辆
		var home: City = RegionManager.current.get_city(v.home_city_id)
		var oc: City = RegionManager.current.get_city(o.origin_id)
		var score := 0.0
		if home != null and oc != null:
			score = GeoMath.city_distance(home, oc) / 1000.0
		if score < best_score:
			best_score = score
			best = v
	return best

func assign_order(game: GameManager, v: Vehicle, o: Order) -> bool:
	if v.is_busy() or not v.can_carry(o.cargo_type) or o.weight_kg > v.capacity_kg:
		return false
	var oc: City = RegionManager.current.get_city(o.origin_id)
	var dc: City = RegionManager.current.get_city(o.dest_id)
	if oc == null or dc == null:
		return false
	var from: Vector2 = RegionManager.local(oc)
	var to: Vector2 = RegionManager.local(dc)
	var dist := GeoMath.city_distance(oc, dc)
	var days := GeoMath.travel_days(dist, v.speed_kmh)
	v.start_trip(from, to, days)
	v.current_order_id = o.id
	o.assigned_vehicle_id = v.id
	o.status = Order.Status.INTRANSIT
	EventBus.vehicles_changed.emit()
	EventBus.orders_changed.emit()
	return true

func fail_order(game: GameManager, o: Order) -> void:
	o.status = Order.Status.FAILED
	game.change_reputation(-1.5 * CargoType.penalty_mult(o.cargo_type))
	EventBus.orders_changed.emit()
	EventBus.toast.emit(Localization.t("toast.order_timeout") % [
		RegionManager.current.get_city(o.origin_id).display_name() if RegionManager.current.get_city(o.origin_id) else "?",
		RegionManager.current.get_city(o.dest_id).display_name() if RegionManager.current.get_city(o.dest_id) else "?"])
