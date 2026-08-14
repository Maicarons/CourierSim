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
	# 营销加成：站点营销等级越高，全网生单量越多（营销升级的真实价值）
	var marketing_bonus := 1.0
	for s in game.stations:
		marketing_bonus += s.marketing_mult() - 1.0
	if game.stations.is_empty():
		marketing_bonus = 1.0
	var mult: float = (0.6 + demand * 0.5) / float(diff) * region_bonus * marketing_bonus
	var n := int(round(base * mult * (0.6 + game.rng.randf() * 0.6)))
	# 吞吐上限：全网站点/仓库的处理能力决定日接单上限（扩网络/升仓/营销可突破）
	return max(1, mini(n, network_throughput(game)))

## 全网吞吐：Σ 站点吞吐（8 + 营销×4）+ Σ 仓容量/20。
## 站点与仓库的处理能力决定网络能承接的日均订单量。
func network_throughput(game: GameManager) -> int:
	var cap := 0
	for s in game.stations:
		cap += 8 + s.marketing_level * 4
	for h in game.hubs:
		cap += int(h.capacity() / 20.0)
	return max(1, cap)

## 生单城市池：只从「已建站（station）或已建仓（hub）」的城市中选。
## 未建任何设施的城市不产生订单（玩家必须建设网络才能接单）。
func served_cities(game: GameManager) -> Array[City]:
	var region: Region = RegionManager.current
	var ids: Dictionary = {}
	for s in game.stations:
		ids[s.city_id] = true
	for h in game.hubs:
		ids[h.city_id] = true
	var out: Array[City] = []
	for c in region.cities:
		if ids.has(c.id):
			out.append(c)
	return out

func weighted_city(game: GameManager) -> City:
	var region: Region = RegionManager.current
	var pool: Array[City] = []
	var served := served_cities(game)
	if served.is_empty():
		# 网络为空：退化为按需求选（教程前期首府建仓后可避免）
		var best: City = region.cities[0]
		for c in region.cities:
			if c.base_demand > best.base_demand:
				best = c
		return best
	for c in served:
		var w := int(max(1, c.base_demand * 10))
		# 有站点的城市权重更高
		for s in game.stations:
			if s.city_id == c.id:
				w += 8 * (s.marketing_level + 1)
		for i in w:
			pool.append(c)
	return pool[game.rng.randi() % pool.size()]

func spawn_one(game: GameManager) -> void:
	var region: Region = RegionManager.current
	var served := served_cities(game)
	if served.size() < 2:
		return   # 至少要 2 个已建站城市才能产生跨城订单
	var origin := weighted_city(game)
	var dest := origin
	var guard := 0
	while dest == origin and guard < 30:
		dest = served[game.rng.randi() % served.size()]
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
	# 订单重量：真实快递整车量级（kg）。
	# 30% 概率生成「快件」（5~28kg，无人机 30kg 载重可运，按件计价）；
	# 其余为整车货：标准 50~450（面包车 500kg 可运），
	# 特殊货更重（危险品 200~1500 需货车，国际 300~3000 需飞机/货轮），
	# 冷链/医药 100~800（冷藏车 2000kg 可运）。整车重量直接决定吨·公里收益。
	var weight := 50.0 + game.rng.randf() * 400.0
	# 15% 概率生成「快件」（5~28kg，无人机 30kg 载重可运，按件计价）——
	# 快件是无人机专属市场，量少但单价尚可，不挤占整车收益
	var is_parcel := game.rng.randf() < 0.15
	if is_parcel:
		# 快件：轻型小包，无人机专属市场，标准货种（无需特殊能力）
		cargo = CargoType.Type.STANDARD
		weight = 5.0 + game.rng.randf() * 23.0
	else:
		match cargo:
			CargoType.Type.COLDCHAIN:
				weight = 100.0 + game.rng.randf() * 700.0
			CargoType.Type.PHARMA:
				weight = 100.0 + game.rng.randf() * 700.0
			CargoType.Type.HAZMAT:
				weight = 200.0 + game.rng.randf() * 1300.0
			CargoType.Type.INTERNATIONAL:
				weight = 300.0 + game.rng.randf() * 2700.0
	var o := Order.new(game.uid("ord"), origin.id, dest.id, cargo, weight)
	# 真实里程优先（OSRM），无烘焙数据回退 Haversine×绕路
	var dist := RegionManager.current.real_distance_m(origin.id, dest.id)
	o.distance_m = dist
	var dur_h := RegionManager.current.real_duration_h(origin.id, dest.id, 80.0)
	o.distance_days = dur_h / 24.0
	o.reward = reward_for(game, dist, cargo, weight)
	o.created_day = game.day
	# 时限：行驶天数 + 站点处理缓冲（小时制更精确）
	var buffer_h := 24.0   # 基础 1 天处理时间
	if cargo == CargoType.Type.INTERNATIONAL:
		buffer_h = 36.0
	o.deadline_day = game.day + int(ceil(o.distance_days + buffer_h / 24.0))
	o.status = Order.Status.PENDING
	game.orders.append(o)

func reward_for(game: GameManager, distance_m: float, cargo: int, weight: float) -> int:
	var km := distance_m / 1000.0
	# 快件（≤28kg，无人机市场）：按件计价，收益与距离挂钩但量级小
	if weight <= 28.0:
		var parcel := 500.0 + km * 2.5
		var rp: int = int(parcel * CargoType.reward_mult(cargo) * game.modifiers.get("reward_mult", 1.0))
		return max(500, rp)
	# 整车货：按「吨·公里」计价（参考 TransRoute rate.costPerTonKm 量级）：
	# 基础费率 50 元/吨·km，叠加重量（吨参与加成）与货种倍率。
	# 站点 20 万 / 仓 60 万造价下，收益需匹配回本周期：
	#   标准 250kg · 200km ≈ 0.25t×200×50×(1+0.25×4) = 5000 元 → 约 40 单回本一个站点
	var tons := weight / 1000.0
	var base := km * tons * 50.0 * (1.0 + tons * 4.0)
	var r: int = int(base * CargoType.reward_mult(cargo) * game.modifiers.get("reward_mult", 1.0))
	return max(1500, r)

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

## 手动派单候选：可承运 + 空闲 + 载重足够的车辆。
## 快件按载重升序（无人机优先），整车按距 origin 距离升序。
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
		if o.weight_kg <= 28.0:
			score = float(v.capacity_kg)
		elif oc != null:
			var home: City = RegionManager.current.get_city(v.home_city_id)
			if home != null:
				score = GeoMath.city_distance(home, oc) / 1000.0
		list.append({"vehicle": v, "dist_km": score})
	list.sort_custom(func(a, b): return a["dist_km"] < b["dist_km"])
	return list

func find_assignable_vehicle(game: GameManager, o: Order) -> Vehicle:
	var best: Vehicle = null
	var best_score := INF
	var oc: City = RegionManager.current.get_city(o.origin_id)
	for v in game.vehicles:
		if v.is_busy():
			continue
		if not v.can_carry(o.cargo_type):
			continue
		if o.weight_kg > v.capacity_kg:
			continue
		# 快件（轻货）优先小载重车辆（如无人机 30kg），避免面包车抢单浪费运力
		var score := 0.0
		if o.weight_kg <= 28.0:
			score = float(v.capacity_kg)
		else:
			# 整车优先 home_city 接近 origin 的车辆
			var home: City = RegionManager.current.get_city(v.home_city_id)
			if home != null and oc != null:
				score = GeoMath.city_distance(home, oc) / 1000.0
			else:
				score = float(v.capacity_kg) * 0.01   # 无 home 信息时按载重小者优先
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
	# 空驶段：车辆从当前位置出发到发货城市（直线，避免瞬移）
	var start_m := v.map_pos
	var oc_local := RegionManager.local(oc)
	var deadhead_km := start_m.distance_to(oc_local) / 1000.0
	var deadhead_days := GeoMath.travel_days(deadhead_km * 1000.0, v.speed_kmh)
	# 干线段：发货→收货（真实 OSRM 折线）
	var r := RegionManager.current.route_between(oc.id, dc.id)
	var path_m: PackedVector2Array = r.get("path_m", PackedVector2Array()) if not r.is_empty() else PackedVector2Array()
	if path_m.size() < 2:
		# 无烘焙数据：退化为直线（仍按真实里程算耗时）
		var to: Vector2 = RegionManager.local(dc)
		v.start_trip(start_m, to, deadhead_days + GeoMath.travel_days(RegionManager.current.real_distance_m(oc.id, dc.id), v.speed_kmh))
	else:
		var dist_m: float = float(r.get("dist_km", 0.0)) * 1000.0
		var main_days := GeoMath.travel_days(dist_m, v.speed_kmh)
		# 拼接：空驶起点 + 干线折线（折线首点是发货城市，弧长比例取点自然衔接）
		var full_path := PackedVector2Array([start_m])
		full_path.append_array(path_m)
		v.start_trip_path(full_path, deadhead_days + main_days)
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
