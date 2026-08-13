class_name StaffPanel
extends VBoxContainer

## 员工标签页：卡片行列出在职员工 + 按角色招聘按钮。

func build() -> void:
	UI.header(self, Localization.t("panel.staff.title"))
	for s in GameManager.staff:
		var sub := "%s · 技能 %.0f%% · 日薪 %d" % [s.role_name(), s.skill * 100.0, int(s.salary_per_day)]
		add_child(UI.info_row(Assets.get_image("char_courier"), s.name, sub, []))
	UI.header(self, Localization.t("panel.staff.hire"))
	var row := HBoxContainer.new()
	for i in Staff.Role.size():
		row.add_child(UI.button(Localization.t("staff." + Staff.Role.keys()[i]), _on_hire.bind(i)))
	add_child(row)

func _on_hire(role: int) -> void:
	GameManager.staff_sys.hire(GameManager, role)
