class_name OverviewPanel
extends VBoxContainer

## 公司总览页签（Dashboard）：评级徽章 + 关键统计 + 市场份额对比 + 区域特色 + 成就进度。

func build() -> void:
	UI.header(self, Localization.t("ov.title"))

	# ---- 顶部：公司名 + 评级徽章 ----
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 14, 16))
	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 14)
	top.add_child(top_hb)
	add_child(top)

	var logo := Assets.get_image("logo")
	if logo != null:
		var lr := TextureRect.new()
		lr.texture = logo
		lr.custom_minimum_size = Vector2(56, 56)
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_hb.add_child(lr)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	top_hb.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = GameManager.company_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", UI.INK)
	col.add_child(name_lbl)
	var sub := Label.new()
	sub.text = "%s · Day %d" % [Localization.t("mode_name." + GameManager.mode), GameManager.day]
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.45, 0.40, 0.32))
	col.add_child(sub)

	var rating_card := PanelContainer.new()
	var rating := GameManager.rating()
	var rating_color := _rating_color(rating)
	rating_card.add_theme_stylebox_override("panel", UI._cartoon_style(rating_color, UI.INK, 12, 12))
	var rating_lbl := Label.new()
	rating_lbl.text = rating
	rating_lbl.add_theme_font_size_override("font_size", 34)
	rating_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	rating_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_lbl.custom_minimum_size = Vector2(72, 0)
	rating_card.add_child(rating_lbl)
	top_hb.add_child(rating_card)

	# ---- 关键统计 ----
	UI.header(self, Localization.t("ov.stats"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var s: Dictionary = GameManager.summary_dict()
	_add_stat_card(grid, Assets.get_image("ui_coin"), Localization.t("finance.funds") % s["money"])
	_add_stat_card(grid, Assets.get_image("ui_finance"), Localization.t("ov.assets") % s["assets"])
	_add_stat_card(grid, Assets.get_image("ui_star"), Localization.t("finance.rep") % s["reputation"])
	_add_stat_card(grid, Assets.get_image("ui_globe"), Localization.t("ov.share") % s["share"])
	_add_stat_card(grid, Assets.get_image("ui_order"), Localization.t("ov.delivered") % s["delivered"])
	_add_stat_card(grid, Assets.get_image("ui_calendar"), Localization.t("ov.days") % s["days"])
	_add_stat_card(grid, Assets.get_image("veh_van"), Localization.t("ov.fleet") % s["vehicles"])
	_add_stat_card(grid, Assets.get_image("bld_hub"), Localization.t("ov.network") % [s["hubs"], s["stations"]])
	_add_stat_card(grid, Assets.get_image("char_courier"), Localization.t("ov.staff") % s["staff"])

	# ---- 市场份额对比 ----
	UI.header(self, Localization.t("ov.share_title"))
	var share_box := PanelContainer.new()
	share_box.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM, UI.INK, 10, 12))
	add_child(share_box)
	var share_col := VBoxContainer.new()
	share_col.add_theme_constant_override("separation", 6)
	share_box.add_child(share_col)
	_add_share_bar(share_col, GameManager.company_name, GameManager.competitor_sys.player_share(), UI.GREEN)
	for c in GameManager.competitor_sys.competitors:
		_add_share_bar(share_col, GameManager.competitor_sys.comp_display(c), c["share"], UI.RED)

	# ---- 区域特色 ----
	UI.header(self, Localization.t("ov.region_features"))
	if RegionManager.current != null and not RegionManager.current.features.is_empty():
		var feats := RegionManager.current.features
		var bonus := float(feats.get("demand_bonus", 1.0))
		add_child(UI.info_row(Assets.get_image("bld_hq"),
			Localization.t("ov.region_demand") % int(bonus * 100.0),
			Localization.t("ov.region_demand_desc"), []))
		for ev in feats.get("events", []):
			var nm: String = ev.get("name_en", ev.get("name", "")) if Localization.is_en() else ev.get("name", "")
			var ds: String = ev.get("desc_en", ev.get("desc", "")) if Localization.is_en() else ev.get("desc", "")
			add_child(UI.info_row(Assets.get_image("ui_bell"), nm, ds, []))
	else:
		add_child(UI.label(Localization.t("ov.no_features"), 400))

	# ---- 成就进度 ----
	UI.header(self, Localization.t("ov.ach_progress"))
	var total := GameManager.ach_sys.defs.size() if GameManager.ach_sys != null else 0
	var unlocked := GameManager.achievements.size()
	add_child(UI.info_row(Assets.get_image("ui_flag"),
		Localization.t("ach.progress") % [unlocked, total],
		Localization.t("ov.ach_hint"), []))


func _add_stat_card(parent: Control, icon: Texture2D, text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI._cartoon_style(UI.CREAM_2, UI.INK, 8, 10))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	if icon != null:
		hb.add_child(UI.tex_rect(icon, 22))
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UI.INK)
	l.add_theme_font_size_override("font_size", 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	parent.add_child(card)


func _add_share_bar(parent: Control, name: String, value: float, color: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	parent.add_child(hb)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_color_override("font_color", UI.INK)
	name_lbl.add_theme_font_size_override("font_size", 13)
	hb.add_child(name_lbl)
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(220, 16)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.add_theme_stylebox_override("panel", UI._cartoon_style(Color(0.85, 0.82, 0.75), UI.INK, 6, 0))
	hb.add_child(bar_bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.custom_minimum_size = Vector2(maxf(6.0, 220.0 * clampf(value, 0.0, 1.0)), 16)
	bar_bg.add_child(fill)
	var pct := Label.new()
	pct.text = "%d%%" % int(value * 100.0)
	pct.custom_minimum_size = Vector2(46, 0)
	pct.add_theme_color_override("font_color", UI.INK)
	pct.add_theme_font_size_override("font_size", 13)
	hb.add_child(pct)


func _rating_color(r: String) -> Color:
	match r:
		"S": return Color(0.95, 0.72, 0.20)   # 金
		"A": return UI.PURPLE
		"B": return UI.BLUE
		_: return Color(0.55, 0.52, 0.48)      # C 灰
