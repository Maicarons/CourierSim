class_name OrderPanel
extends VBoxContainer

## 订单标签页（v0.11）：顶部状态概览 chips + 自动派单开关 + 按状态分组，
## 每单显示货种图标、路线、重量、距离、奖励、剩余时限（紧迫红字）、分配车辆。
## 待分配订单带「派单 ▸」按钮 → 手动选择车辆（VehiclePicker）。

var _picker: VehiclePicker


func build() -> void:
	UI.header(self, Localization.t("panel.orders.title"))
	_build_summary()
	_build_group(Order.Status.PENDING, Localization.t("order.group.pending"), UI.RED, Assets.get_image("ui_order"))
	_build_group(Order.Status.INTRANSIT, Localization.t("order.group.intransit"), UI.BLUE, Assets.get_image("veh_van"))
	_build_group(Order.Status.DELIVERED, Localization.t("order.group.delivered"), UI.GREEN, Assets.get_image("ui_flag"))
	_build_group(Order.Status.FAILED, Localization.t("order.group.failed"), Color(0.6, 0.58, 0.52), Assets.get_image("ui_trash"))
	# 手动派单弹窗挂在本面板内（随 tab 重建销毁）
	_picker = VehiclePicker.new()
	add_child(_picker)


func _build_summary() -> void:
	var counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	for o in GameManager.orders:
		counts[o.status] = counts.get(o.status, 0) + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_add_chip(row, Localization.t("order.group.pending"), counts[Order.Status.PENDING], UI.RED)
	_add_chip(row, Localization.t("order.group.intransit"), counts[Order.Status.INTRANSIT], UI.BLUE)
	_add_chip(row, Localization.t("order.group.delivered"), counts[Order.Status.DELIVERED], UI.GREEN)
	_add_chip(row, Localization.t("order.group.failed"), counts[Order.Status.FAILED], Color(0.6, 0.58, 0.52))
	var total := Label.new()
	total.text = Localization.t("panel.orders.summary") % [counts[Order.Status.PENDING], GameManager.orders.size()]
	total.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
	total.add_theme_font_size_override("font_size", 12)
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(total)
	# 自动派单开关（v0.11）：关闭后玩家手动派单
	var auto := CheckButton.new()
	auto.button_pressed = GameManager.order_sys.auto_assign_enabled
	auto.add_theme_color_override("font_color", UI.INK)
	auto.add_theme_font_size_override("font_size", 13)
	auto.text = Localization.t("order.auto_assign")
	Tooltips.register(auto, Localization.t("tip.auto_assign"))
	auto.toggled.connect(func(on: bool):
		GameManager.order_sys.auto_assign_enabled = on
		EventBus.toast.emit(Localization.t("toast.auto_assign") % (
			Localization.t("order.auto_on") if on else Localization.t("order.auto_off"))))
	row.add_child(auto)


func _add_chip(parent: Control, label: String, count: int, color: Color) -> void:
	var chip := UI.status_chip("%s %d" % [label, count], color)
	parent.add_child(chip)


func _build_group(status: int, group_title: String, accent: Color, icon: Texture2D) -> void:
	var items: Array = []
	for o in GameManager.orders:
		if o.status == status:
			items.append(o)
	if items.is_empty():
		return
	UI.header(self, group_title)
	for o in items:
		_build_order_row(o, accent)


func _build_order_row(o: Order, accent: Color) -> void:
	var oc := RegionManager.current.get_city(o.origin_id)
	var dc := RegionManager.current.get_city(o.dest_id)
	var oname := oc.display_name() if oc else "?"
	var dname := dc.display_name() if dc else "?"
	var cargo_icon := Assets.get_image(CargoType.icon_of(o.cargo_type))
	# 快件（≤28kg）加「快件」前缀，提示玩家可用无人机承运
	var title := ("%s → %s" % [oname, dname])
	var tag := ""
	if o.weight_kg <= 28.0:
		tag = Localization.t("order.parcel_tag") + " "
	title = tag + title

	var parts: Array[String] = []
	parts.append("%.0fkg" % o.weight_kg)
	if o.distance_m > 0.0:
		parts.append("%.0fkm" % (o.distance_m / 1000.0))
	parts.append(Localization.t("order.reward") % o.reward)
	match o.status:
		Order.Status.PENDING:
			var left: int = o.deadline_day - GameManager.day
			var urgent: bool = left <= 2
			parts.append("%s%d天" % ["⚠" if urgent else "", left])
		Order.Status.INTRANSIT:
			var v := _find_vehicle(o)
			if v != null:
				parts.append(v.name)
		Order.Status.DELIVERED:
			parts.append(Localization.t("order.done_day") % o.deadline_day)
		Order.Status.FAILED:
			parts.append(Localization.t("order.timeout_day") % o.deadline_day)
	var sub := "%s · %s" % [CargoType.name_of(o.cargo_type), " · ".join(parts)]

	var actions: Array = []
	if o.status == Order.Status.PENDING:
		actions.append({
			"text": Localization.t("order.dispatch") + " ▸",
			"color": UI.BLUE,
			"cb": func(): _open_picker(o),
		})
	var card := UI.info_row(cargo_icon if cargo_icon != null else Assets.get_image("ui_order"), title, sub, actions)
	# 紧迫高亮：待分配且剩余时限紧张 → 橙色描边
	if o.status == Order.Status.PENDING and o.deadline_day - GameManager.day <= 2:
		card.add_theme_stylebox_override("panel", UI._cartoon_style(Color(1.0, 0.93, 0.82), UI.ORANGE, 10, 8))
	add_child(card)


func _open_picker(o: Order) -> void:
	if _picker == null:
		_picker = VehiclePicker.new()
		add_child(_picker)
	_picker.pick(o, func(_v: Vehicle, ok: bool):
		EventBus.orders_changed.emit()
		EventBus.vehicles_changed.emit())


func _find_vehicle(o: Order) -> Vehicle:
	for v in GameManager.vehicles:
		if v.id == o.assigned_vehicle_id:
			return v
	return null
