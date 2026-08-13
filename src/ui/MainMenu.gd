extends Control
class_name MainMenu

## 全屏沉浸式主菜单（v2 重做）：
##  - 整屏覆盖：背景铺满 + 动画浮动物流元素 + 品牌强化的左半区
##  - 图标化大按钮：开始/继续/设置/关于/退出；悬停 tooltip
##  - 「开始游戏」展开为内联子面板：公司名 + 模式卡片 + 区域选择 + 确认
##  - 顶栏语言切换图标按钮，右下版本/许可脚注
##  - 与 Settings/About 各自为独立全屏场景（change_scene_to_file）

var _config_panel: PanelContainer
var _saves_panel: PanelContainer
var _company_edit: LineEdit
var _region_opt: OptionButton
var _mode := "career"
var _mode_buttons: Array[Button] = []
var _new_game_btn: Button
var _continue_btn: Button
var _floating: Array[Dictionary] = []   # {tex, x, y, vx, vy, rot, rot_v}
var _bg_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	AudioManager.play_bgm("menu")
	_build()


func _process(delta: float) -> void:
	_bg_time += delta
	# 让浮动元素有动画 — 自己队列重绘
	queue_redraw()


# ================= 构建 =================

func _build() -> void:
	for ch in get_children():
		ch.free()

	# 整屏背景贴图（STRETCH_KEEP_ASPECT_COVERED，铺满不留黑边）
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = Assets.get_image("title_bg")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 暗化蒙版（让前景更可读）
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.03, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# 动画浮层（物流元素），用主场景的 _draw 渲染
	_init_floating()

	# 顶部条：语言切换
	var top_strip := HBoxContainer.new()
	top_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_left = 16
	top_strip.offset_top = 12
	top_strip.offset_right = -16
	top_strip.offset_bottom = 56
	add_child(top_strip)
	top_strip.add_child(UI.spacer())
	top_strip.add_child(UI.icon_only_button(
		Assets.get_image("ui_globe"),
		Localization.t("tip.lang") + " " + _lang_label(),
		_on_toggle_lang))

	# 左侧：品牌区
	var brand := VBoxContainer.new()
	brand.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	brand.offset_left = 60
	brand.offset_top = 90
	brand.offset_right = 640
	brand.offset_bottom = -100
	brand.add_theme_constant_override("separation", 12)
	add_child(brand)
	var logo := Assets.get_image("logo")
	if logo != null:
		var lr := TextureRect.new()
		lr.texture = logo
		lr.custom_minimum_size = Vector2(140, 140)
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		brand.add_child(lr)
	var title := Label.new()
	title.text = Localization.t("menu.title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UI.YELLOW)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", UI.INK)
	brand.add_child(title)
	var sub := Label.new()
	sub.text = Localization.t("menu.subtitle")
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	sub.add_theme_constant_override("outline_size", 2)
	sub.add_theme_color_override("font_outline_color", UI.INK)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brand.add_child(sub)
	brand.add_child(UI.spacer())
	var hint := Label.new()
	hint.text = Localization.t("menu.hint_v2")
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(560, 0)
	brand.add_child(hint)

	# 右侧：菜单按钮 + 内联新游戏配置子面板
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -480
	right.offset_top = 110
	right.offset_right = -60
	right.offset_bottom = -100
	right.add_theme_constant_override("separation", 12)
	add_child(right)

	_new_game_btn = _big_menu_button(Localization.t("menu.new_game"),
		Assets.get_image("ui_play"), UI.GREEN, Localization.t("tip.new_game"), _toggle_config_panel)
	right.add_child(_new_game_btn)
	_continue_btn = _big_menu_button(Localization.t("menu.continue"),
		Assets.get_image("ui_save"), UI.BLUE, Localization.t("tip.continue"), _on_continue)
	right.add_child(_continue_btn)
	right.add_child(_big_menu_button(Localization.t("menu.settings"),
		Assets.get_image("ui_settings"), UI.PURPLE, Localization.t("tip.settings"), _on_settings))
	right.add_child(_big_menu_button(Localization.t("menu.about"),
		Assets.get_image("ui_about"), UI.ORANGE, Localization.t("tip.about"), _on_about))
	right.add_child(_big_menu_button(Localization.t("menu.quit"),
		Assets.get_image("ui_quit"), UI.RED, Localization.t("tip.quit"), _on_quit))

	_config_panel = _build_config_panel()
	add_child(_config_panel)
	_config_panel.visible = false

	_saves_panel = _build_saves_panel()
	add_child(_saves_panel)
	_saves_panel.visible = false

	# 右下角脚注：版本与许可
	var footer := VBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -360
	footer.offset_top = -54
	footer.offset_right = -20
	footer.offset_bottom = -12
	footer.alignment = BoxContainer.ALIGNMENT_END
	add_child(footer)
	var ver := Label.new()
	ver.text = "v%s  ·  AGPL-3.0" % ProjectSettings.get_setting("application/config/version", "0.4.0")
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(ver)

	_refresh_continue()


## 图标化大按钮（图标 + 文本）+ tooltip。不会自动加入 parent，
## 调用方需自行 parent.add_child(b)。
func _big_menu_button(text: String, icon: Texture2D, color: Color,
		tooltip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.add_theme_font_size_override("font_size", 18)
	if icon != null:
		b.icon = UI._scaled_icon(icon, 32)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", UI._cartoon_style(color, UI.INK, 12, 16))
	b.add_theme_stylebox_override("hover", UI._cartoon_style(color.lightened(0.12), UI.INK, 12, 16))
	b.add_theme_stylebox_override("pressed", UI._cartoon_style(color.darkened(0.18), UI.INK, 12, 16))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	AudioManager.attach_click(b)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	hb.add_child(UI.spacer())
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	l.add_theme_font_size_override("font_size", 18)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	hb.add_child(UI.spacer())
	Tooltips.register(b, tooltip)
	return b


func _build_config_panel() -> PanelContainer:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -480
	card.offset_top = 110
	card.offset_right = -60
	card.offset_bottom = -100
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 16, 22))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var hdr := Label.new()
	hdr.text = Localization.t("menu.new_game")
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", UI.ORANGE)
	vbox.add_child(hdr)

	# 公司名
	UI.header(vbox, Localization.t("menu.company"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	row.add_child(UI.tex_rect(Assets.get_image("bld_hq"), 28))
	_company_edit = LineEdit.new()
	_company_edit.text = Localization.t("menu.default_company")
	_company_edit.placeholder_text = Localization.t("menu.company_ph")
	_company_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_company_edit)

	# 模式选择
	UI.header(vbox, Localization.t("menu.mode"))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	vbox.add_child(mrow)
	var b_career := UI.mode_card(Assets.get_image("char_courier"),
		Localization.t("menu.mode_career"), Localization.t("menu.mode_career_desc"),
		_set_mode.bind("career"))
	var b_sandbox := UI.mode_card(Assets.get_image("veh_van"),
		Localization.t("menu.mode_sandbox"), Localization.t("menu.mode_sandbox_desc"),
		_set_mode.bind("sandbox"))
	b_career.set_meta("mode", "career")
	b_sandbox.set_meta("mode", "sandbox")
	_mode_buttons = [b_career, b_sandbox]
	mrow.add_child(b_career)
	mrow.add_child(b_sandbox)

	# 区域
	UI.header(vbox, Localization.t("menu.region"))
	_region_opt = OptionButton.new()
	_region_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in RegionManager.regions:
		var locked: bool = r.unlock_cost > 0
		var suffix := Localization.t("menu.region_locked") % r.unlock_cost if locked else Localization.t("menu.region_free")
		_region_opt.add_item(r.display_name() + suffix)
		_region_opt.set_item_metadata(_region_opt.item_count - 1, r.id)
		if locked:
			_region_opt.set_item_disabled(_region_opt.item_count - 1, true)
	vbox.add_child(_region_opt)

	# 确认 / 取消
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	vbox.add_child(brow)
	var cancel := UI.icon_button(Localization.t("menu.cancel"),
		Assets.get_image("ui_back"), _close_config_panel, Localization.t("tip.cancel"))
	cancel.custom_minimum_size = Vector2(0, 42)
	brow.add_child(cancel)
	brow.add_child(UI.spacer())
	var start := UI.primary_button(Localization.t("menu.start"), UI.GREEN, _on_start)
	start.custom_minimum_size = Vector2(0, 44)
	brow.add_child(start)

	_set_mode("career")
	return card


# ================= 浮层动画 =================

func _init_floating() -> void:
	_floating.clear()
	var candidates := ["veh_van", "cargo_standard", "cargo_pharma", "veh_truck", "cargo_international"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 16:
		var id: String = candidates[i % candidates.size()]
		var tex := Assets.get_image(id)
		if tex == null:
			continue
		_floating.append({
			"tex": tex,
			"x": rng.randf_range(-100, 1380.0),
			"y": rng.randf_range(-100, 820.0),
			"vx": rng.randf_range(-8.0, 8.0),
			"vy": rng.randf_range(-4.0, 4.0),
			"rot": rng.randf_range(-0.2, 0.2),
			"rot_v": rng.randf_range(-0.2, 0.2),
		})


func _draw() -> void:
	# 更新浮层位置（drift）
	var d := get_process_delta_time()
	for f in _floating:
		f["x"] = wrapf(f["x"] + f["vx"] * d * 10.0, -120.0, 1400.0)
		f["y"] = wrapf(f["y"] + f["vy"] * d * 10.0, -120.0, 840.0)
		f["rot"] += f["rot_v"] * d * 0.6
	# 渲染（_draw 上下文允许 draw_* 调用）
	for f in _floating:
		var p := Vector2(f["x"], f["y"])
		var tex: Texture2D = f["tex"]
		draw_set_transform(p, f["rot"])
		draw_texture_rect(tex, Rect2(-22, -22, 44, 44), false)
	draw_set_transform(Vector2.ZERO, 0.0)


# ================= 操作 =================

func _toggle_config_panel() -> void:
	_config_panel.visible = not _config_panel.visible


func _close_config_panel() -> void:
	_config_panel.visible = false


func _build_saves_panel() -> PanelContainer:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -480
	card.offset_top = 110
	card.offset_right = -60
	card.offset_bottom = -100
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 16, 22))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var hdr := Label.new()
	hdr.text = Localization.t("menu.saves_title")
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", UI.ORANGE)
	vb.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	list.name = "list"

	var back := UI.icon_button(Localization.t("menu.back"),
		Assets.get_image("ui_back"), _close_saves_panel, Localization.t("tip.cancel"))
	back.custom_minimum_size = Vector2(0, 40)
	vb.add_child(back)

	card.set_meta("list", list)
	return card


func _open_saves_panel() -> void:
	_refresh_saves_list()
	_config_panel.visible = false
	_saves_panel.visible = true


func _close_saves_panel() -> void:
	_saves_panel.visible = false


func _refresh_saves_list() -> void:
	var list: VBoxContainer = _saves_panel.get_meta("list") if _saves_panel.has_meta("list") else null
	if list == null:
		return
	for ch in list.get_children():
		ch.queue_free()
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		var empty := Label.new()
		empty.text = Localization.t("set.saves.empty")
		empty.add_theme_color_override("font_color", Color(0.5, 0.45, 0.38))
		empty.add_theme_font_size_override("font_size", 13)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty)
		return
	for s in slots:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM_2, UI.INK, 8, 8))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)
		hb.add_child(UI.tex_rect(Assets.get_image("ui_save"), 22))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		var t := Label.new()
		var slot: String = s.get("slot", "")
		var company: String = s.get("company", "")
		t.text = "%s  ·  %s" % [SaveManager.slot_label(slot), company if company != "" else Localization.t("menu.no_company")]
		t.add_theme_color_override("font_color", UI.INK)
		t.add_theme_font_size_override("font_size", 13)
		col.add_child(t)
		var t2 := Label.new()
		t2.text = "Day %d · %s · %s" % [s.get("day", 0), s.get("region", ""), s.get("saved_at", "")]
		t2.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
		t2.add_theme_font_size_override("font_size", 11)
		col.add_child(t2)
		hb.add_child(UI.icon_button(Localization.t("set.saves.load"),
			Assets.get_image("ui_play"), _on_load_slot.bind(slot), Localization.t("set.saves.load")))
		hb.add_child(UI.icon_button(Localization.t("set.saves.delete"),
			Assets.get_image("ui_trash"), _on_delete_slot.bind(slot), Localization.t("set.saves.delete")))
		list.add_child(row)


func _on_load_slot(slot: String) -> void:
	if SaveManager.load_slot(slot):
		get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")


func _on_delete_slot(slot: String) -> void:
	SaveManager.delete_slot(slot)
	_refresh_saves_list()
	_refresh_continue()


func _refresh_continue() -> void:
	if _continue_btn == null:
		return
	var slots := SaveManager.list_slots()
	var has := false
	for s in slots:
		if s["slot"] == "autosave":
			has = true
			break
	_continue_btn.disabled = not has


func _set_mode(m: String) -> void:
	_mode = m
	for b in _mode_buttons:
		b.button_pressed = (b.get_meta("mode") == m)


func _on_continue() -> void:
	# 打开存档槽位面板（多槽位选择）
	if SaveManager.list_slots().is_empty():
		EventBus.toast.emit(Localization.t("toast.no_save"))
		return
	_open_saves_panel()


func _on_start() -> void:
	var region_id: String = _region_opt.get_item_metadata(_region_opt.selected) if _region_opt.item_count > 0 else ""
	if region_id == "":
		EventBus.toast.emit(Localization.t("toast.select_region"))
		return
	var reg: Region = RegionManager.get_region(region_id)
	if reg != null and reg.unlock_cost > 0 and not GameManager.unlocked_region_ids.has(region_id):
		if not GameManager.can_afford(reg.unlock_cost):
			EventBus.toast.emit(Localization.t("toast.insufficient_unlock") % reg.display_name())
			return
		GameManager.add_money(-reg.unlock_cost, "region", "解锁 " + reg.region_name)
		GameManager.unlocked_region_ids.append(region_id)
	var name := _company_edit.text.strip_edges()
	if name == "":
		name = Localization.t("menu.default_company")
	GameManager.new_game(_mode, name, region_id)
	# 新游戏写入空闲槽位（不覆盖已有存档），并绑定为活跃槽位
	var slot := SaveManager.next_free_slot()
	GameManager.active_slot = slot
	SaveManager.save_slot(slot)
	get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://src/scenes/Settings.tscn")


func _on_about() -> void:
	get_tree().change_scene_to_file("res://src/scenes/About.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _lang_label() -> String:
	return "EN" if Localization.get_locale() == "zh_CN" else "中"


func _on_toggle_lang() -> void:
	Localization.set_locale("en_US" if Localization.get_locale() == "zh_CN" else "zh_CN")


func _on_locale_changed(_l: String) -> void:
	_refresh_continue()
	_build()
