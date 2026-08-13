class_name MarketingPanel
extends VBoxContainer

## 市场标签页：展示知名度卡片 + 三档宣传投放按钮。

func build() -> void:
	UI.header(self, Localization.t("panel.marketing.title"))
	var aw := int(GameManager.marketing_sys.awareness * 100.0)
	add_child(UI.info_row(Assets.get_image("ui_marketing"), Localization.t("panel.marketing.awareness") % aw, "", []))
	var row := HBoxContainer.new()
	row.add_child(UI.button(Localization.t("btn.invest") % 5000, _on_campaign.bind(5000)))
	row.add_child(UI.button(Localization.t("btn.invest") % 20000, _on_campaign.bind(20000)))
	row.add_child(UI.button(Localization.t("btn.invest") % 50000, _on_campaign.bind(50000)))
	add_child(row)

func _on_campaign(budget: int) -> void:
	GameManager.marketing_sys.run_campaign(GameManager, budget)
