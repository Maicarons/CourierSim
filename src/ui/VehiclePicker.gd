extends Control
class_name VehiclePicker

## 手动派单弹窗（v0.11）：列出可承运 + 空闲 + 载重足够的车辆，按距发货城市距离排序，
## 点击车辆即派单。无可用车辆时给出提示（含"去买一辆"引导）。

var _title_label: Label
var _list_box: VBoxContainer
var _empty_label: Label
var _order: Order
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 16, 22))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", UI.ORANGE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_title_label)

	var hint := Label.new()
	hint.text = Localization.t("picker.hint")
	hint.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	_empty_label = Label.new()
	_empty_label.text = Localization.t("picker.empty")
	_empty_label.add_theme_color_override("font_color", UI.RED)
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list_box.add_child(_empty_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	var cancel := UI.icon_button(Localization.t("dlg.cancel"),
		Assets.get_image("ui_back"), _close, Localization.t("dlg.cancel"))
	cancel.custom_minimum_size = Vector2(140, 40)
	row.add_child(cancel)


## 弹出车辆选择。order 为目标订单，on_assigned(vehicle) 派单成功后回调。
func pick(order: Order, on_assigned: Callable = Callable()) -> void:
	_order = order
	_on_assigned = on_assigned
	var oc := RegionManager.current.get_city(order.origin_id)
	var dc := RegionManager.current.get_city(order.dest_id)
	_title_label.text = "%s → %s" % [
		oc.display_name() if oc else "?",
		dc.display_name() if dc else "?"]
	_refresh_list()
	visible = true
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)


var _on_assigned: Callable = Callable()


func _refresh_list() -> void:
	# 清空旧条目（保留空提示标签）
	for ch in _list_box.get_children():
		if ch != _empty_label:
			ch.queue_free()
	var cands: Array = GameManager.order_sys.assignable_vehicles(GameManager, _order)
	_empty_label.visible = cands.is_empty()
	if cands.is_empty():
		return
	for cand in cands:
		var v: Vehicle = cand["vehicle"]
		var row := _veh_row(v, cand["dist_km"])
		_list_box.add_child(row)


func _veh_row(v: Vehicle, dist_km: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UI.INK)
	b.add_theme_stylebox_override("normal", UI._cartoon_style(Color(1.0, 0.98, 0.93), UI.INK, 10, 10))
	b.add_theme_stylebox_override("hover", UI._cartoon_style(Color(1.0, 0.95, 0.85), UI.ORANGE, 10, 10))
	b.add_theme_stylebox_override("pressed", UI._cartoon_style(UI.CREAM_2, UI.INK, 10, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	hb.offset_left = 12
	b.add_child(hb)

	var type_icon := Assets.get_image(Vehicle.Type.keys()[v.type].to_lower())
	if type_icon == null:
		type_icon = Assets.get_image("veh_van")
	var icon := TextureRect.new()
	icon.texture = type_icon
	icon.custom_minimum_size = Vector2(26, 26)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)

	var name_l := Label.new()
	name_l.text = v.name
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", UI.INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(name_l)

	var info := Label.new()
	info.text = "%s · %.0fkm · %dkg" % [
		UI.vehicle_type_name(v.type), dist_km, v.capacity_kg]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(info)

	var go := Label.new()
	go.text = Localization.t("picker.assign") + " ▸"
	go.add_theme_font_size_override("font_size", 14)
	go.add_theme_color_override("font_color", UI.BLUE)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(go)

	b.pressed.connect(func():
		_assign(v))
	AudioManager.attach_click(b)
	return b


func _assign(v: Vehicle) -> void:
	var ok: bool = GameManager.order_sys.assign_order(GameManager, v, _order)
	if ok:
		EventBus.toast.emit(Localization.t("toast.dispatch_ok") % [v.name, Localization.t("order.id") % _order.id])
	var cb := _on_assigned
	_on_assigned = Callable()
	visible = false
	if cb.is_valid():
		cb.call(v, ok)


func _close() -> void:
	_on_assigned = Callable()
	visible = false


func is_open() -> bool:
	return visible
