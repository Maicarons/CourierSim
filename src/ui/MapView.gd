extends Control
class_name MapView

## 真实世界地图渲染器（v2 全面重做）：
##  - 陆地与海岸线来自 Natural Earth 50m 烘焙的多边形（PNG 贴图 + JSON 描边）
##  - 城市为真实经纬度（WGS84），等距圆柱投影到区域局部米制坐标
##  - 城市间绘制风格化陆路/海运航线（最近邻连接）
##  - 滚轮缩放、左键拖拽平移、悬停高亮、点击城市查看信息并建设设施
##  - 玩法整合：直接在地图上点选城市 → 建仓/建站/升级/宣传（Prison Architect/Two Point 范式）

var zoom := 1.0
var _map_center := Vector2.ZERO       # 区域局部米制坐标的地图中心（可被平移修改）
var _map_scale := 1.0                 # 米→屏幕像素的缩放因子
var _font: Font
var _dash := 0.0

# 区域切换时一次性加载的资源
var _region_id := ""
var _land_tex: Texture2D = null
var _land_bbox := Rect2()              # 贴图对应的经纬度 bbox（minx,miny,maxx,maxy）
var _coastlines: Array[PackedVector2Array] = []   # 多边形顶点（已投影到局部米制）
var _roads: Array[Dictionary] = []     # 陆路：{a,b,ctrl}
var _sea_routes: Array[Dictionary] = [] # 海运：{a,b}

# 交互
var _hovered: City = null
var _selected: City = null
var _dragging := false
var _drag_last := Vector2.ZERO

# 浮层控件
var _action_bar: HBoxContainer
var _info_card: PanelContainer
var _info_label: Label
var _legend: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	if _font == null:
		_font = get_theme_font("font")
	EventBus.region_changed.connect(_on_region_changed)
	resized.connect(queue_redraw)
	_build_overlays()
	_on_region_changed()


func _process(delta: float) -> void:
	_dash += delta * 0.35
	queue_redraw()


func _build_overlays() -> void:
	_info_card = PanelContainer.new()
	_info_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_info_card.position = Vector2(10, 10)
	_info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_card.add_theme_stylebox_override("panel", _card_style(UI.CREAM))
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", UI.INK)
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.custom_minimum_size = Vector2(220, 0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_card.add_child(_info_label)
	add_child(_info_card)
	_info_card.visible = false

	_action_bar = HBoxContainer.new()
	_action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_action_bar.offset_top = -52
	_action_bar.offset_left = 220
	_action_bar.offset_right = -220
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 6)
	add_child(_action_bar)
	_action_bar.visible = false

	_legend = Label.new()
	_legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_legend.position = Vector2(-10, 10)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.add_theme_color_override("font_color", UI.INK)
	_legend.add_theme_font_size_override("font_size", 12)
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_legend)
	_legend.visible = false


func _card_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = UI.INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	return sb


# ================= 区域加载 =================

func _on_region_changed() -> void:
	_region_id = ""
	_land_tex = null
	_coastlines.clear()
	_roads.clear()
	_sea_routes.clear()
	_selected = null
	_hovered = null
	if RegionManager.current == null:
		queue_redraw()
		return
	_region_id = RegionManager.current.id
	_load_land()
	_build_routes()
	_info_card.visible = false
	_action_bar.visible = false
	_legend.visible = true
	queue_redraw()


func _load_land() -> void:
	var land_path := "res://src/map/data/regions/%s_land.json" % _region_id
	var tex_path := "res://src/map/data/regions/%s_terrain.png" % _region_id
	if not ResourceLoader.exists(land_path) or not ResourceLoader.exists(tex_path):
		return
	_land_tex = load(tex_path) as Texture2D
	var d := JSON.parse_string(FileAccess.get_file_as_string(land_path))
	if typeof(d) != TYPE_DICTIONARY:
		return
	var bbox: Array = d.get("bbox", [])
	if bbox.size() == 4:
		_land_bbox = Rect2(bbox[0], bbox[1], bbox[2] - bbox[0], bbox[3] - bbox[1])
	var reg := RegionManager.current
	for poly in d.get("polys", []):
		var ring := PackedVector2Array()
		for p in poly:
			ring.append(GeoMath.to_local_meters(p[1], p[0], reg.origin_lat, reg.origin_lon))
		_coastlines.append(ring)


func _build_routes() -> void:
	var reg := RegionManager.current
	if reg == null:
		return
	var cities := reg.cities
	var max_road_km := 320.0
	# 陆路：每个城市连接最近 2 个非港口间距离 < 阈值的城市（构成链状网络）
	var used := {}
	for i in cities.size():
		var c := cities[i]
		var pairs := []
		for j in cities.size():
			if i == j:
				continue
			var d := GeoMath.haversine(c.lat, c.lon, cities[j].lat, cities[j].lon) / 1000.0
			pairs.append([j, d])
		pairs.sort_custom(func(a, b): return a[1] < b[1])
		var added := 0
		for p in pairs:
			if added >= 2:
				break
			var key := [min(i, p[0]), max(i, p[0])]
			if used.has(key):
				continue
			if p[1] > max_road_km:
				break
			used[key] = true
			var a := GeoMath.to_local_meters(c.lat, c.lon, reg.origin_lat, reg.origin_lon)
			var b := GeoMath.to_local_meters(cities[p[0]].lat, cities[p[0]].lon, reg.origin_lat, reg.origin_lon)
			var mid := (a + b) * 0.5
			var perp := Vector2(-(b - a).y, (b - a).x).normalized()
			var ctrl := mid + perp * (a.distance_to(b) * 0.08)
			_roads.append({"a": a, "b": b, "ctrl": ctrl})
			added += 1
	# 海运：有港口城市之间的近距离对
	var ports := []
	for c in cities:
		if c.has_port:
			ports.append(c)
	for i in ports.size():
		for j in range(i + 1, ports.size()):
			var d := GeoMath.haversine(ports[i].lat, ports[i].lon, ports[j].lat, ports[j].lon) / 1000.0
			if d > 520.0:
				continue
			var a := GeoMath.to_local_meters(ports[i].lat, ports[i].lon, reg.origin_lat, reg.origin_lon)
			var b := GeoMath.to_local_meters(ports[j].lat, ports[j].lon, reg.origin_lat, reg.origin_lon)
			_sea_routes.append({"a": a, "b": b})


# ================= 输入 =================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(zoom * 1.18, 8.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(zoom / 1.18, 0.5)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_last = mb.position
				_dragging = false
			else:
				if not _dragging:
					var hit := _hit_city(mb.position)
					if hit != null:
						_select_city(hit)
					else:
						_select_city(null)
				_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if (mm.position - _drag_last).length() > 5.0:
				_dragging = true
			if _dragging:
				var dx := (mm.position - _drag_last).x / _map_scale
				var dy := (mm.position - _drag_last).y / _map_scale
				_map_center += Vector2(dx, -dy) * Vector2(1, 1)
				_drag_last = mm.position
				queue_redraw()
		else:
			var new_h := _hit_city(mm.position)
			if (new_h != null) != (_hovered != null) or (new_h != null and _hovered != null and new_h.id != _hovered.id):
				_hovered = new_h
				queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_PLUS, KEY_EQUAL:
				zoom = min(zoom * 1.2, 8.0)
				queue_redraw()
			KEY_MINUS:
				zoom = max(zoom / 1.2, 0.5)
				queue_redraw()
			KEY_0:
				zoom = 1.0
				_map_center = RegionManager.bounds().get_center()
				queue_redraw()


# ================= 命中检测 =================

func _hit_city(sp: Vector2) -> City:
	if RegionManager.current == null:
		return null
	var best: City = null
	var best_d := 14.0
	for c in RegionManager.current.cities:
		var p := to_screen(RegionManager.local(c))
		var d := sp.distance_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best


# ================= 选中态 =================

func _select_city(c: City) -> void:
	_selected = c
	if c == null:
		_info_card.visible = false
		_action_bar.visible = false
	else:
		_info_card.visible = true
		_action_bar.visible = true
		_refresh_info()
		_rebuild_action_bar()
	queue_redraw()


func _refresh_info() -> void:
	if _selected == null:
		return
	var c := _selected
	var tier_name := ["都会", "大城市", "中型", "小城"][clampi(c.tier - 1, 0, 3)]
	var has_hub := false
	var has_station := false
	for h in GameManager.hubs:
		if h.city_id == c.id:
			has_hub = true
			break
	for s in GameManager.stations:
		if s.city_id == c.id:
			has_station = true
			break
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % c.display_name())
	lines.append("层级：T%d %s" % [c.tier, tier_name])
	if c.population > 0:
		lines.append("人口：%d" % c.population)
	lines.append("需求：%.1f / 天" % c.base_demand)
	if c.coastal:
		lines.append("沿海%s" % (" · 港口" if c.has_port else ""))
	if has_hub:
		lines.append("设施：中转仓库 ✓")
	if has_station:
		lines.append("设施：末端站点 ✓")
	if not has_hub and not has_station:
		lines.append("设施：（无）")
	_info_label.bbcode_enabled = true
	_info_label.text = "\n".join(lines)


func _rebuild_action_bar() -> void:
	for ch in _action_bar.get_children():
		ch.queue_free()
	if _selected == null:
		return
	var c := _selected
	var hub_existing: Hub = null
	var station_existing: Station = null
	for h in GameManager.hubs:
		if h.city_id == c.id:
			hub_existing = h
			break
	for s in GameManager.stations:
		if s.city_id == c.id:
			station_existing = s
			break
	if hub_existing != null:
		var cost := hub_existing.upgrade_cost()
		_action_bar.add_child(UI.icon_button(
			Localization.t("btn.upgrade") % cost,
			Assets.get_image("bld_hub"),
			_build_upgrade_hub.bind(hub_existing),
			Localization.t("tip.city_upgrade_hub") % cost))
	else:
		_action_bar.add_child(UI.icon_button(
			Localization.t("btn.build") % HubSystem.HUB_BASE_COST,
			Assets.get_image("bld_hub"),
			_build_new_hub.bind(c),
			Localization.t("tip.city_build_hub") % HubSystem.HUB_BASE_COST))
	if station_existing != null:
		var scost := station_existing.marketing_upgrade_cost()
		_action_bar.add_child(UI.icon_button(
			Localization.t("btn.promote") % scost,
			Assets.get_image("bld_station"),
			_build_promote_station.bind(station_existing),
			Localization.t("tip.city_promote") % scost))
	else:
		_action_bar.add_child(UI.icon_button(
			Localization.t("btn.build") % StationSystem.STATION_COST,
			Assets.get_image("bld_station"),
			_build_new_station.bind(c),
			Localization.t("tip.city_build_station") % StationSystem.STATION_COST))
	_action_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_back"), Localization.t("tip.close"),
		_build_close.bind(), 36))


func _build_new_hub(c: City) -> void:
	if GameManager.money < HubSystem.HUB_BASE_COST:
		EventBus.toast.emit(Localization.t("toast.insufficient") % HubSystem.HUB_BASE_COST)
		return
	GameManager.hub_sys.build(GameManager, c.id)


func _build_upgrade_hub(h: Hub) -> void:
	GameManager.hub_sys.upgrade(GameManager, h)


func _build_new_station(c: City) -> void:
	if GameManager.money < StationSystem.STATION_COST:
		EventBus.toast.emit(Localization.t("toast.insufficient") % StationSystem.STATION_COST)
		return
	GameManager.station_sys.build(GameManager, c.id)


func _build_promote_station(s: Station) -> void:
	GameManager.station_sys.upgrade_marketing(GameManager, s)


func _build_close() -> void:
	_select_city(null)


# ================= 渲染 =================

func _draw() -> void:
	if RegionManager.current == null:
		return
	var b := RegionManager.bounds()
	if b.size.x <= 0 or b.size.y <= 0:
		return
	# 自适应：首次按城市 bbox 居中，之后可拖拽/缩放
	if _map_center == Vector2.ZERO:
		_map_center = b.get_center()
	var margin := 60.0
	_map_scale = min((size.x - margin * 2) / max(b.size.x, 1.0),
		(size.y - margin * 2) / max(b.size.y, 1.0)) * zoom
	_map_scale = max(_map_scale, 0.0001)

	# 1. 海（蓝）
	draw_rect(Rect2(Vector2.ZERO, size), UI.SKY)

	# 2. 陆地（烘焙贴图，按 bbox 拉伸）
	if _land_tex != null:
		var tr := _screen_rect_of_bbox(_land_bbox)
		draw_texture_rect(_land_tex, tr, false)

	# 3. 海运虚线（先画于路下，避免遮挡陆地路线）
	for r in _sea_routes:
		_draw_sea_route(r)

	# 4. 陆路（带曲线控制点的二次贝塞尔）
	for r in _roads:
		_draw_road(r)

	# 5. 海岸描边（深色细线，叠在陆地边缘提升对比度）
	for ring in _coastlines:
		var pts := PackedVector2Array()
		for p in ring:
			pts.append(to_screen(p))
		pts.append(pts[0])
		draw_polyline(pts, UI.INK, 2.0, true)

	# 6. 城市节点 + 名称
	for c in RegionManager.current.cities:
		var p := to_screen(RegionManager.local(c))
		var rad := 7.0 + (4 - c.tier) * 2.5
		draw_circle(p, rad + 6.0, Color(1.0, 0.88, 0.35, 0.25))
		draw_circle(p, rad, UI.YELLOW)
		draw_circle(p, rad, UI.INK, false, 2.5)
		if _font != null:
			var nm := c.display_name()
			var tw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10
			var bb := Rect2(p.x - tw / 2.0, p.y - rad - 22.0, tw, 18)
			draw_rect(bb, UI.CREAM)
			draw_rect(bb, UI.INK, false, 1.5)
			draw_string(_font, bb.position + Vector2(5, 13), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)

	# 7. 仓库 / 站点 图标
	for h in GameManager.hubs:
		var city := RegionManager.current.get_city(h.city_id)
		if city == null:
			continue
		var p2 := to_screen(RegionManager.local(city))
		_draw_building_marker(p2, Assets.get_image("bld_hub"))
	for s in GameManager.stations:
		var city := RegionManager.current.get_city(s.city_id)
		if city == null:
			continue
		var p2 := to_screen(RegionManager.local(city))
		_draw_building_marker(p2, Assets.get_image("bld_station"))

	# 8. 订单流光线（仅进行中订单）
	for o in GameManager.orders:
		if o.status != Order.Status.INTRANSIT:
			continue
		var oc := RegionManager.current.get_city(o.origin_id)
		var dc := RegionManager.current.get_city(o.dest_id)
		if oc == null or dc == null:
			continue
		var a := to_screen(RegionManager.local(oc))
		var d := to_screen(RegionManager.local(dc))
		draw_line(a, d, Color(1.0, 1.0, 1.0, 0.45), 4.0)
		var len := a.distance_to(d)
		var segs: int = maxi(int(len / 18.0), 1)
		for i in segs:
			var t := fposmod(float(i) / float(segs) + _dash, 1.0)
			var pp := a.lerp(d, t)
			draw_circle(pp, 3.5, UI.ORANGE)

	# 9. 车辆
	for v in GameManager.vehicles:
		var local: Vector2 = v.map_pos
		if not v.is_busy():
			var hc := RegionManager.current.get_city(v.home_city_id)
			if hc != null:
				local = RegionManager.local(hc)
		var p3 := to_screen(local)
		var tex := Assets.get_image("veh_drone") if v.type_name() == "配送无人机" else Assets.get_image("veh_van")
		if tex == null:
			tex = Assets.get_image("char_courier")
		if tex != null:
			draw_texture_rect(tex, Rect2(p3 - Vector2(14, 14), Vector2(28, 28)), false)
		if v.is_busy() and _font != null:
			draw_string(_font, p3 + Vector2(10.0, 4.0), "%.0f%%" % (v.travel_progress * 100.0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK)

	# 10. 悬停/选中高亮
	if _hovered != null:
		_draw_highlight(_hovered, UI.BLUE, true)
	if _selected != null:
		_draw_highlight(_selected, UI.ORANGE, false)

	# 11. 图例
	_draw_legend()


func _draw_road(r: Dictionary) -> void:
	var a := to_screen(r["a"])
	var b := to_screen(r["b"])
	var ctrl := to_screen(r["ctrl"])
	# 阴影底（深棕描边）
	draw_polyline(PackedVector2Array([a, ctrl, b]), Color(0.18, 0.13, 0.10, 0.55), 6.0, true)
	# 路面（奶油白）
	draw_polyline(PackedVector2Array([a, ctrl, b]), Color(1.0, 0.95, 0.85, 0.95), 3.0, true)


func _draw_sea_route(r: Dictionary) -> void:
	var a := to_screen(r["a"])
	var b := to_screen(r["b"])
	draw_line(a, b, Color(1.0, 1.0, 1.0, 0.55), 2.5)
	# 流动虚线点
	var len := a.distance_to(b)
	var segs: int = maxi(int(len / 24.0), 1)
	for i in segs:
		var t := fposmod(float(i) / float(segs) + _dash, 1.0)
		var pp := a.lerp(b, t)
		draw_circle(pp, 2.5, Color(1.0, 1.0, 1.0, 0.85))


func _draw_building_marker(p: Vector2, tex: Texture2D) -> void:
	if tex == null:
		return
	draw_rect(Rect2(p + Vector2(8, -8), Vector2(20, 20)), UI.INK, false, 1.5)
	draw_texture_rect(tex, Rect2(p + Vector2(9, -7), Vector2(18, 18)), false)


func _draw_highlight(c: City, color: Color, dashed: bool) -> void:
	var p := to_screen(RegionManager.local(c))
	var rad := 14.0
	if dashed:
		# 用虚线圆近似（每隔 6px 描一段）
		var steps := 24
		var on := true
		for i in steps:
			var a := TAU * float(i) / float(steps)
			var n := TAU * float(i + 1) / float(steps)
			if on:
				draw_line(p + Vector2(cos(a), sin(a)) * rad,
					p + Vector2(cos(n), sin(n)) * rad, color, 3.0)
			on = not on
	else:
		draw_arc(p, rad, 0.0, TAU, 32, color, 3.0)


func _draw_legend() -> void:
	if _font == null or RegionManager.current == null:
		return
	var reg_name := RegionManager.current.display_name()
	var txt := "%s  ·  %d 城市  ·  %.1fx  ·  滚轮缩放 / 拖拽平移 / 点击城市建设" % [
		reg_name, RegionManager.current.cities.size(), zoom]
	var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12).x + 16
	var bb := Rect2(size.x - tw - 16, 12, tw, 22)
	draw_rect(bb, UI.CREAM)
	draw_rect(bb, UI.INK, false, 1.5)
	draw_string(_font, bb.position + Vector2(8, 16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK)


func _screen_rect_of_bbox(bbox: Rect2) -> Rect2:
	var reg := RegionManager.current
	if reg == null:
		return Rect2()
	var a := GeoMath.to_local_meters(bbox.position.y, bbox.position.x, reg.origin_lat, reg.origin_lon)
	var b := GeoMath.to_local_meters(bbox.position.y + bbox.size.y, bbox.position.x + bbox.size.x, reg.origin_lat, reg.origin_lon)
	var sa := to_screen(a)
	var sb := to_screen(b)
	var r := Rect2(sa, sb - sa)
	if r.size.x < 0:
		r.position.x += r.size.x
		r.size.x = -r.size.x
	if r.size.y < 0:
		r.position.y += r.size.y
		r.size.y = -r.size.y
	return r


## 局部米制坐标 → 屏幕像素（y 轴翻转）
func to_screen(local: Vector2) -> Vector2:
	return Vector2(size.x / 2.0 + (local.x - _map_center.x) * _map_scale,
		size.y / 2.0 - (local.y - _map_center.y) * _map_scale)