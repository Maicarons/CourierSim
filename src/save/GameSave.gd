class_name GameSave
extends RefCounted

## GameManager 的存档序列化助手（静态方法）。
## 把全部实体集合与全局状态收拢为 Dictionary、以及从 Dictionary 还原，
## 集中放置以避免 GameManager 单例过大、职责过多。
## GameManager 仅保留 to_dict()/from_dict() 两个转发入口。

static func to_dict(gm: GameManager) -> Dictionary:
	var d := {
		"version": GameManager.SAVE_VERSION,
		"mode": gm.mode,
		"day": gm.day,
		"hour_of_day": gm.hour_of_day,
		"money": gm.money,
		"debt": gm.debt,
		"reputation": gm.reputation,
		"company_name": gm.company_name,
		"region_id": RegionManager.current.id if RegionManager.current else "",
		"unlocked_regions": gm.unlocked_region_ids,
		"modifiers": gm.modifiers,
		"id_counter": gm.id_counter,
		"objective_done": gm.objective_done,
		"tutorial_step": gm.tutorial_step,
		"achievements": gm.achievements,
		"vehicles": gm.vehicles.map(func(v): return veh_dict(v)),
		"hubs": gm.hubs.map(func(h): return hub_dict(h)),
		"stations": gm.stations.map(func(s): return station_dict(s)),
		"orders": gm.orders.map(func(o): return order_dict(o)),
		"staff": gm.staff.map(func(s): return staff_dict(s)),
		"techs": gm.techs.map(func(t): return t.unlocked),
	}
	return d

static func from_dict(gm: GameManager, d: Dictionary) -> void:
	gm.mode = d.get("mode", "career")
	gm.day = int(d.get("day", 1))
	gm.hour_of_day = int(d.get("hour_of_day", 6))
	gm.money = int(d.get("money", 0))
	gm.debt = int(d.get("debt", 0))
	gm.reputation = float(d.get("reputation", 50.0))
	gm.company_name = d.get("company_name", "")
	gm.id_counter = int(d.get("id_counter", 0))
	gm.objectives = ["obj.buy_vehicle","obj.build_hub","obj.build_station","obj.first_delivery","obj.unlock_tech"]
	gm.objective_done = d.get("objective_done", [false,false,false,false,false])
	gm.tutorial_step = int(d.get("tutorial_step", 0))
	gm.game_over_emitted = false   # 读档后允许重新触发胜负判定
	gm.achievements.clear()
	for a in d.get("achievements", []):
		gm.achievements.append(String(a))
	gm.unlocked_region_ids = d.get("unlocked_regions", [])
	gm.modifiers = d.get("modifiers", _reset_modifiers_copy())
	RegionManager.set_current(d.get("region_id", ""))
	gm.vehicles = _arr(gm.vehicles, d.get("vehicles", []), veh_from)
	gm.hubs = _arr(gm.hubs, d.get("hubs", []), hub_from)
	gm.stations = _arr(gm.stations, d.get("stations", []), station_from)
	gm.orders = _arr(gm.orders, d.get("orders", []), order_from)
	gm.staff = _arr(gm.staff, d.get("staff", []), staff_from)
	gm.tech_sys.load_tree()
	var tflags: Array = d.get("techs", [])
	for i in gm.techs.size():
		if i < tflags.size():
			gm.techs[i].unlocked = bool(tflags[i])
	gm.recompute_baseline()
	gm._sync_all()

static func _reset_modifiers_copy() -> Dictionary:
	return {"fuel_price_mult":1.0,"speed_mult":1.0,"demand_mult":1.0,"satisfaction_mult":1.0,"accident_risk":1.0,"reward_mult":1.0}

static func _arr(target: Array, src: Array, fn: Callable) -> Array:
	target.clear()
	for item in src:
		target.append(fn.call(item))
	return target

# ---- 实体 → 字典 ----

static func veh_dict(v: Vehicle) -> Dictionary:
	return {"id":v.id,"name":v.name,"type":v.type,"capacity_kg":v.capacity_kg,
		"speed_kmh":v.speed_kmh,"km_per_day":v.km_per_day,"cost":v.cost,
		"fuel_per_km":v.fuel_per_km,"maintenance_per_day":v.maintenance_per_day,
		"capabilities":v.capabilities,"assigned_hub_id":v.assigned_hub_id,
		"home_city_id":v.home_city_id,"status":v.status,"current_order_id":v.current_order_id,
		"owned":v.owned,"lease_daily":v.lease_daily,
		"route_from":[v.route_from.x,v.route_from.y],"route_to":[v.route_to.x,v.route_to.y],
		"route_path": _veh_path(v.route_path),
		"travel_progress":v.travel_progress,"travel_total_days":v.travel_total_days,
		"travel_elapsed_days":v.travel_elapsed_days}

static func _veh_path(path_m: PackedVector2Array) -> Array:
	var out: Array = []
	for p in path_m:
		out.append([p.x, p.y])
	return out

static func hub_dict(h: Hub) -> Dictionary:
	return {"id":h.id,"name":h.name,"city_id":h.city_id,"level":h.level,
		"base_capacity":h.base_capacity,"used_today":h.used_today,
		"upgrade_base_cost":h.upgrade_base_cost,"throughput_bonus":h.throughput_bonus}

static func station_dict(s: Station) -> Dictionary:
	return {"id":s.id,"name":s.name,"city_id":s.city_id,
		"coverage_radius_km":s.coverage_radius_km,"marketing_level":s.marketing_level,
		"daily_orders":s.daily_orders,"satisfaction":s.satisfaction}

static func order_dict(o: Order) -> Dictionary:
	return {"id":o.id,"origin_id":o.origin_id,"dest_id":o.dest_id,"cargo_type":o.cargo_type,
		"weight_kg":o.weight_kg,"created_day":o.created_day,"deadline_day":o.deadline_day,
		"reward":o.reward,"status":o.status,"assigned_vehicle_id":o.assigned_vehicle_id,
		"distance_m":o.distance_m,"distance_days":o.distance_days}

static func staff_dict(s: Staff) -> Dictionary:
	return {"id":s.id,"name":s.name,"role":s.role,"skill":s.skill,
		"salary_per_day":s.salary_per_day,"efficiency":s.efficiency,"assigned_hub_id":s.assigned_hub_id}

# ---- 字典 → 实体 ----

static func veh_from(d: Dictionary) -> Vehicle:
	var v := Vehicle.new(d.get("id",""), d.get("name",""), int(d.get("type",0)),
		int(d.get("capacity_kg",500)), float(d.get("speed_kmh",70.0)), int(d.get("cost",0)))
	v.km_per_day = float(d.get("km_per_day",480.0))
	v.fuel_per_km = float(d.get("fuel_per_km",0.0))
	v.maintenance_per_day = float(d.get("maintenance_per_day",0.0))
	v.capabilities = int(d.get("capabilities",0))
	v.assigned_hub_id = d.get("assigned_hub_id","")
	v.home_city_id = d.get("home_city_id","")
	v.status = int(d.get("status",0))
	v.current_order_id = d.get("current_order_id","")
	v.owned = bool(d.get("owned", true))
	v.lease_daily = int(d.get("lease_daily",0))
	var rf: Array = d.get("route_from",[0,0]); v.route_from = Vector2(rf[0],rf[1])
	var rt: Array = d.get("route_to",[0,0]); v.route_to = Vector2(rt[0],rt[1])
	var rp: Array = d.get("route_path",[])
	var path_m := PackedVector2Array()
	for p in rp:
		path_m.append(Vector2(p[0], p[1]))
	v.route_path = path_m
	v.travel_progress = float(d.get("travel_progress",0.0))
	v.travel_total_days = float(d.get("travel_total_days",1.0))
	v.travel_elapsed_days = float(d.get("travel_elapsed_days",0.0))
	return v

static func hub_from(d: Dictionary) -> Hub:
	var h := Hub.new(d.get("id",""), d.get("name",""), d.get("city_id",""),
		int(d.get("base_capacity",200)), int(d.get("upgrade_base_cost",8000)))
	h.level = int(d.get("level",1))
	h.used_today = int(d.get("used_today",0))
	h.throughput_bonus = float(d.get("throughput_bonus",0.0))
	return h

static func station_from(d: Dictionary) -> Station:
	var s := Station.new(d.get("id",""), d.get("name",""), d.get("city_id",""),
		float(d.get("coverage_radius_km",8.0)))
	s.marketing_level = int(d.get("marketing_level",0))
	s.daily_orders = int(d.get("daily_orders",0))
	s.satisfaction = float(d.get("satisfaction",1.0))
	return s

static func order_from(d: Dictionary) -> Order:
	var o := Order.new(d.get("id",""), d.get("origin_id",""), d.get("dest_id",""),
		int(d.get("cargo_type",0)), float(d.get("weight_kg",5.0)))
	o.created_day = int(d.get("created_day",1))
	o.deadline_day = int(d.get("deadline_day",2))
	o.reward = int(d.get("reward",0))
	o.status = int(d.get("status",0))
	o.assigned_vehicle_id = d.get("assigned_vehicle_id","")
	o.distance_m = float(d.get("distance_m",0.0))
	o.distance_days = float(d.get("distance_days",1.0))
	return o

static func staff_from(d: Dictionary) -> Staff:
	var s := Staff.new(d.get("id",""), d.get("name",""), int(d.get("role",0)),
		float(d.get("skill",0.5)))
	s.salary_per_day = float(d.get("salary_per_day",100.0))
	s.efficiency = float(d.get("efficiency",1.0))
	s.assigned_hub_id = d.get("assigned_hub_id","")
	return s
