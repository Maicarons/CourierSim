extends Control
class_name GameOver

## 结算面板（独立全屏）：胜利（评级 S/A）或失败（破产）。
## 汇总经营天数 / 总资产 / 市占 / 声誉 / 交付数 / 员工车辆规模，并给出评级。

var _reason := ""
static var last_reason := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reason = GameOver.last_reason
	TimeSystem.set_speed(0)   # 结算页静止
	Localization.locale_changed.connect(_on_locale_changed, CONNECT_DEFERRED)
	_build()


func _build() -> void:
	for ch in get_children():
		ch.free()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.10, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 18, 26))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var summary: Dictionary = GameManager.summary_dict()
	var victory: bool = _reason == "game.over.victory"

	# 标题
	var title := Label.new()
	title.text = Localization.t("gameover.title_victory") if victory else Localization.t("gameover.title_defeat")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UI.GREEN if victory else UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	# 失败原因 / 评级
	if victory:
		var rating := Label.new()
		rating.text = Localization.t("gameover.rating") % summary.get("rating", "C")
		rating.add_theme_font_size_override("font_size", 26)
		rating.add_theme_color_override("font_color", UI.ORANGE)
		rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(rating)
	else:
		var why := Label.new()
		why.text = Localization.t(_reason)
		why.add_theme_color_override("font_color", UI.INK)
		why.add_theme_font_size_override("font_size", 15)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(why)

	# 公司名
	var comp := Label.new()
	comp.text = GameManager.company_name
	comp.add_theme_color_override("font_color", UI.BLUE)
	comp.add_theme_font_size_override("font_size", 18)
	comp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(comp)

	var sep := HSeparator.new()
	vb.add_child(sep)

	# 统计网格（两列）
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 6)
	vb.add_child(stats)
	_add_stat(stats, Localization.t("gameover.days"), "%d" % summary.get("days", 1))
	_add_stat(stats, Localization.t("gameover.money"), "%d" % summary.get("money", 0))
	_add_stat(stats, Localization.t("gameover.assets"), "%d" % summary.get("assets", 0))
	_add_stat(stats, Localization.t("gameover.share"), "%d%%" % summary.get("share", 0))
	_add_stat(stats, Localization.t("gameover.reputation"), "%d / 100" % summary.get("reputation", 0))
	_add_stat(stats, Localization.t("gameover.delivered"), "%d" % summary.get("delivered", 0))
	_add_stat(stats, Localization.t("gameover.vehicles"), "%d" % summary.get("vehicles", 0))
	_add_stat(stats, Localization.t("gameover.network"), "%d 仓 / %d 站" % [summary.get("hubs", 0), summary.get("stations", 0)])

	var sep2 := HSeparator.new()
	vb.add_child(sep2)

	# 操作按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)
	var menu_btn := UI.primary_button(Localization.t("gameover.to_menu"), UI.BLUE, _on_to_menu)
	menu_btn.custom_minimum_size = Vector2(180, 44)
	btn_row.add_child(menu_btn)
	if victory:
		var again_btn := UI.primary_button(Localization.t("gameover.play_again"), UI.GREEN, _on_play_again)
		again_btn.custom_minimum_size = Vector2(180, 44)
		btn_row.add_child(again_btn)


func _add_stat(parent: Control, label: String, value: String) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
	l.add_theme_font_size_override("font_size", 14)
	l.custom_minimum_size = Vector2(160, 0)
	parent.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", UI.INK)
	v.add_theme_font_size_override("font_size", 14)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(v)


func _on_to_menu() -> void:
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")


func _on_play_again() -> void:
	GameManager.new_game("career", GameManager.company_name,
		RegionManager.current.id if RegionManager.current else "")
	get_tree().change_scene_to_file("res://src/scenes/GameScene.tscn")


func _on_locale_changed(_l: String) -> void:
	_build()