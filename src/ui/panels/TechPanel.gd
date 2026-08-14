class_name TechPanel
extends VBoxContainer

## 科技标签页：卡片行列出科技树节点，未解锁且满足前置条件者可点击解锁。

func build() -> void:
	UI.header(self, Localization.t("panel.tech.title"))
	for t in GameManager.techs:
		var cat := Localization.t("tech.cat." + TechNode.Category.keys()[t.category])
		var sub := t.display_desc()
		var actions: Array = []
		if not t.unlocked:
			if GameManager.tech_sys.can_unlock(GameManager, t):
				actions = [{text = Localization.t("tech.cost") % t.cost, cb = _on_unlock.bind(t), color = UI.GREEN}]
			else:
				sub += " · 需前置科技"
		else:
			sub += " · 已解锁"
		add_child(UI.info_row(Assets.get_image("ui_tech"), "[%s] %s" % [cat, t.display_name()], sub, actions))

func _on_unlock(t: TechNode) -> void:
	GameManager.tech_sys.unlock(GameManager, t)
