extends Control
class_name GameScene

## 主玩法场景（UI/UX 重构版）：
## - 顶栏：状态 chips（天/资金/声誉/区域/市占）+ 图标化速度/保存/设置/菜单
## - 左侧：图标式分组 Tab 栏（运营/设施/发展/管理），悬停 tooltip
## - 中央：地图 / 列表面板（地图点击可建仓/建站）
## - 右上：生涯目标追踪 HUD
## - 底部：事件日志
## - 对白层：TutorialSystem 驱动 DialogueBox 渐进引导
##
## 本场景只做编排与事件接线；UI 组件由 UI / Tooltips / MapView / DialogueBox 提供，
## 文案由 Localization 提供（中英切换）。

const TAB_GROUPS := [
	["tab.group.ops", ["map", "orders", "vehicles"]],
	["tab.group.fac", ["hubs", "stations"]],
	["tab.group.dev", ["marketing", "tech", "staff"]],
	["tab.group.mng", ["finance", "region"]],
]

const TAB_ICONS := {
	"map": "ui_globe", "orders": "ui_order", "vehicles": "veh_van",
	"hubs": "bld_hub", "stations": "bld_station",
	"marketing": "ui_marketing", "tech": "ui_tech", "staff": "char_courier",
	"finance": "ui_finance", "region": "bld_hq",
}

const TABS_FLAT := ["map", "orders", "vehicles", "hubs", "stations",
	"marketing", "tech", "staff", "finance", "region"]

var top_bar: HBoxContainer
var lbl_day: Label
var lbl_money: Label
var lbl_rep: Label
var lbl_region: Label
var lbl_share: Label
var tab_col: VBoxContainer
var center: Control
var map_view: MapView
var list_panel: ScrollContainer
var bottom_log: Label
var objective_card: PanelContainer
var objective_label: Label
var dialogue: DialogueBox
var tutorial: TutorialSystem
var pause_layer: CanvasLayer
var pause_menu: PauseMenu
var current_tab := "map"
var log_lines: Array[String] = []
var _dlg_queue: Array[Dictionary] = []


func _ready() -> void:
	tutorial = TutorialSystem.new()
	add_child(tutorial)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 60
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_layer.add_child(pause_menu)
	pause_menu.settings_requested.connect(_on_settings)
	pause_menu.about_requested.connect(_on_about)
	pause_menu.menu_requested.connect(_on_to_menu)
	tutorial.beat_triggered.connect(_on_beat)
	tutorial.objective_changed.connect(_on_objective_changed)
	tutorial.tutorial_completed.connect(_on_tutorial_completed)
	_build_ui()
	EventBus.toast.connect(_on_toast)
	EventBus.game_over.connect(_on_game_over)
	EventBus.day_changed.connect(refresh_top)
	EventBus.money_changed.connect(refresh_top)
	EventBus.vehicles_changed.connect(_on_state_changed)
	EventBus.hubs_changed.connect(_on_state_changed)
	EventBus.stations_changed.connect(_on_state_changed)
	EventBus.orders_changed.connect(_on_state_changed)
	EventBus.reputation_changed.connect(refresh_top)
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	AudioManager.play_bgm("play")
	show_tab("map")
	refresh_top()
	tutorial.begin()


# ================= UI 构建 =================

func _build_ui() -> void:
	for ch in get_children():
		if ch == tutorial or ch == dialogue or ch == pause_layer:
			continue
		ch.queue_free()
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)

	_build_top_bar(main)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(mid)

	_build_left_tabs(mid)
	_build_center(mid)
	_build_objective_hud()
	_build_bottom_log(main)


func _build_top_bar(parent: Control) -> void:
	var top_panel := UI.card()
	top_panel.custom_minimum_size = Vector2(0, 56)
	parent.add_child(top_panel)
	top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 46)
	top_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_bar)

	lbl_day = _add_stat(top_bar, "1", Assets.get_image("ui_calendar"), UI.BLUE)
	lbl_money = _add_stat(top_bar, "0", Assets.get_image("ui_coin"), UI.GREEN)
	lbl_rep = _add_stat(top_bar, "0", Assets.get_image("ui_star"), UI.YELLOW)
	lbl_region = _add_stat(top_bar, "-", Assets.get_image("bld_hub"), UI.PURPLE)
	lbl_share = _add_stat(top_bar, "0%", Assets.get_image("ui_finance"), UI.ORANGE)
	top_bar.add_child(UI.spacer())

	# 图标化顶栏控件：纯图标 + tooltip
	var speed_paused := TimeSystem.SPEEDS[TimeSystem.speed_index] == 0
	top_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_pause" if speed_paused else "ui_play"),
		Localization.t("tip.speed_pause"),
		TimeSystem.toggle_pause))
	for s in [1, 2, 4]:
		top_bar.add_child(UI.icon_only_button(
			Assets.get_image("ui_play"),
			Localization.t("tip.speed_x") % s,
			TimeSystem.set_speed.bind(s)))
	top_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_save"),
		Localization.t("tip.save"), _on_save))
	top_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_settings"),
		Localization.t("tip.settings"), _on_settings))
	top_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_home"),
		Localization.t("tip.menu"), func(): pause_menu.open()))
	top_bar.add_child(UI.icon_only_button(
		Assets.get_image("ui_globe"),
		Localization.t("tip.lang") + " " + _lang_label(),
		_on_toggle_lang))


func _add_stat(parent: Control, text: String, icon: Texture2D, color: Color) -> Label:
	var t := UI.stat_tile(icon, color)
	var lbl: Label = t.find_child("lbl", true, false) as Label
	if lbl != null:
		lbl.text = text
	parent.add_child(t)
	return lbl


func _build_left_tabs(parent: Control) -> void:
	var tab_panel := UI.card()
	tab_panel.custom_minimum_size = Vector2(96, 0)
	tab_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(tab_panel)
	tab_col = VBoxContainer.new()
	tab_col.add_theme_constant_override("separation", 4)
	tab_panel.add_child(tab_col)
	# 顶部分隔：留白
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	tab_col.add_child(sp)
	for group in TAB_GROUPS:
		var gname := Localization.t(group[0])
		var l := Label.new()
		l.text = gname
		l.add_theme_color_override("font_color", UI.ORANGE)
		l.add_theme_font_size_override("font_size", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_col.add_child(l)
		for t in group[1]:
			var icon := Assets.get_image(TAB_ICONS.get(t, ""))
			var b := UI.icon_only_button(
				icon,
				"%s — %s" % [Localization.t("tab." + t), Localization.t("tip.tab_" + t)],
				show_tab.bind(t), 48)
			b.name = "tab_" + t
			b.toggle_mode = true
			tab_col.add_child(b)
		var sep := HBoxContainer.new()
		sep.add_theme_constant_override("separation", 0)
		sep.custom_minimum_size = Vector2(0, 6)
		tab_col.add_child(sep)


func _build_center(parent: Control) -> void:
	center = Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	map_view = MapView.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(map_view)

	list_panel = ScrollContainer.new()
	list_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(list_panel)


func _build_objective_hud() -> void:
	objective_card = PanelContainer.new()
	objective_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_card.position = Vector2(-300, 70)
	objective_card.custom_minimum_size = Vector2(280, 0)
	objective_card.add_theme_stylebox_override("panel", _obj_card_style())
	objective_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	objective_card.add_child(hb)
	hb.add_child(UI.tex_rect(Assets.get_image("ui_objective"), 22))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var hdr := Label.new()
	hdr.text = Localization.t("obj.hud")
	hdr.add_theme_color_override("font_color", UI.ORANGE)
	hdr.add_theme_font_size_override("font_size", 12)
	col.add_child(hdr)
	objective_label = Label.new()
	objective_label.add_theme_color_override("font_color", UI.INK)
	objective_label.add_theme_font_size_override("font_size", 13)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(0, 38)
	col.add_child(objective_label)
	# 点击卡片重看教程
	objective_card.gui_input.connect(_on_objective_card_input)
	add_child(objective_card)
	objective_card.visible = false


func _obj_card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.CREAM
	sb.border_color = UI.ORANGE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _on_objective_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_replay_current_beat()


func _replay_current_beat() -> void:
	if tutorial == null or tutorial._index <= 0 or tutorial._index > tutorial.beats.size():
		return
	var beat: Dictionary = tutorial.beats[tutorial._index - 1]
	_show_dialogue_for_beat(beat)


func _build_bottom_log(parent: Control) -> void:
	var log_panel := UI.card()
	log_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(log_panel)
	bottom_log = Label.new()
	bottom_log.custom_minimum_size = Vector2(0, 44)
	bottom_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_log.add_theme_font_size_override("font_size", 12)
	log_panel.add_child(bottom_log)


# ================= Tab 切换 =================

func show_tab(tab: String) -> void:
	current_tab = tab
	map_view.visible = (tab == "map")
	list_panel.visible = (tab != "map")
	for t in TABS_FLAT:
		var b := tab_col.get_node_or_null("tab_" + t)
		if b == null:
			continue
		var sel: bool = (t == tab)
		b.button_pressed = sel
		if sel:
			b.add_theme_stylebox_override("normal", UI._cartoon_style(UI.BLUE, UI.INK, 10, 4))
		else:
			b.add_theme_stylebox_override("normal", UI._cartoon_style(UI.CREAM, UI.INK, 10, 4))
	if tab != "map":
		rebuild_list(tab)


func refresh_top(_arg = null) -> void:
	lbl_day.text = "Day %d" % GameManager.day
	lbl_money.text = "%d" % GameManager.money
	lbl_rep.text = "%d" % int(GameManager.reputation)
	lbl_region.text = RegionManager.current.display_name() if RegionManager.current else "-"
	lbl_share.text = "%d%%" % int(GameManager.competitor_sys.player_share() * 100.0)
	tutorial.check()


func _on_state_changed() -> void:
	refresh_top()
	if current_tab != "map":
		rebuild_list(current_tab)
	map_view.queue_redraw()
	tutorial.check()


# ================= 列表面板（委托给各面板） =================

func rebuild_list(tab: String) -> void:
	for ch in list_panel.get_children():
		ch.queue_free()
	var p: VBoxContainer = null
	match tab:
		"vehicles": p = VehiclePanel.new()
		"hubs": p = HubPanel.new()
		"stations": p = StationPanel.new()
		"orders": p = OrderPanel.new()
		"marketing": p = MarketingPanel.new()
		"tech": p = TechPanel.new()
		"staff": p = StaffPanel.new()
		"finance": p = FinancePanel.new()
		"region": p = _new_region_panel()
	if p != null:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_panel.add_child(p)
		p.build()


func _new_region_panel() -> RegionPanel:
	var p := RegionPanel.new()
	p.unlock_requested.connect(_on_unlock_region)
	p.switch_requested.connect(_on_switch_region)
	return p


# ================= 教程对白驱动 =================

func _on_beat(beat: Dictionary) -> void:
	_show_dialogue_for_beat(beat)


func _show_dialogue_for_beat(beat: Dictionary) -> void:
	if dialogue.is_open():
		_dlg_queue.append(beat)
		return
	var text: String = Localization.t(beat.get("text_key", ""))
	if text == beat.get("text_key", "") or text.strip_edges() == "":
		return
	var lines := [text]
	var icon := Assets.get_image(beat.get("icon", ""))
	dialogue.show_dialogue(Localization.t(beat.get("speaker_key", "")), icon, lines,
		_on_dialogue_closed)


func _on_dialogue_closed() -> void:
	if _dlg_queue.is_empty():
		return
	var next: Dictionary = _dlg_queue.pop_front()
	_show_dialogue_for_beat(next)


func _on_objective_changed(text_key: String) -> void:
	if GameManager.mode != "career":
		objective_card.visible = false
		return
	objective_card.visible = true
	if text_key == "":
		objective_label.text = Localization.t("tut.obj.free")
	else:
		objective_label.text = Localization.t(text_key)


func _on_tutorial_completed() -> void:
	objective_card.visible = false


# ================= 操作处理 =================

func _on_unlock_region(r: Region) -> void:
	if not GameManager.can_afford(r.unlock_cost):
		EventBus.toast.emit(Localization.t("toast.region_insufficient") % r.display_name())
		return
	GameManager.spend(r.unlock_cost, "region", "解锁区域 " + r.region_name)
	GameManager.unlocked_region_ids.append(r.id)
	EventBus.toast.emit(Localization.t("toast.region_unlocked") % r.display_name())
	rebuild_list("region")


func _on_switch_region(id: String) -> void:
	if RegionManager.set_current(id):
		GameManager.orders.clear()
		GameManager.vehicles.clear()
		EventBus.toast.emit(Localization.t("toast.region_switched") % RegionManager.current.display_name())
		show_tab("map")
		refresh_top()
		map_view.queue_redraw()


func _on_save() -> void:
	SaveManager.save_slot(GameManager.active_slot)


func _on_settings() -> void:
	TimeSystem.set_speed(0)   # 进入设置时暂停，避免后台空跑
	get_tree().change_scene_to_file("res://src/scenes/Settings.tscn")


func _on_about() -> void:
	get_tree().change_scene_to_file("res://src/scenes/About.tscn")


func _on_to_menu() -> void:
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")


func _lang_label() -> String:
	return "EN" if Localization.get_locale() == "zh_CN" else "中"


func _on_toggle_lang() -> void:
	Localization.set_locale("en_US" if Localization.get_locale() == "zh_CN" else "zh_CN")


func _on_locale_changed(_l: String) -> void:
	_build_ui()
	show_tab(current_tab)
	refresh_top()


func _on_game_over(reason: String) -> void:
	GameOver.last_reason = reason
	TimeSystem.set_speed(0)   # 结算页静止，避免后台继续模拟
	get_tree().change_scene_to_file("res://src/scenes/GameOver.tscn")


func _on_toast(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 6:
		log_lines.pop_front()
	bottom_log.text = "\n".join(log_lines)