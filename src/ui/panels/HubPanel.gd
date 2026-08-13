class_name HubPanel
extends VBoxContainer

## 中转仓库标签页：卡片行列出已有仓库（可升级）+ 在新城市新建仓库。

var _city_opt: OptionButton = null

func build() -> void:
	UI.header(self, Localization.t("panel.hubs.title"))
	_city_opt = UI.city_option()
	for h in GameManager.hubs:
		var sub := "Lv.%d · 吞吐 %d/%d" % [h.level, h.used_today, h.capacity()]
		add_child(UI.info_row(Assets.get_image("bld_hub"), h.name, sub,
			[{text = Localization.t("btn.upgrade") % h.upgrade_cost(), cb = _on_upgrade.bind(h), color = UI.BLUE}]))
	UI.header(self, Localization.t("panel.hubs.new"))
	var brow := HBoxContainer.new()
	brow.add_child(_city_opt)
	brow.add_child(UI.button(Localization.t("btn.build") % 8000, _on_build))
	add_child(brow)

func _on_build() -> void:
	if _city_opt == null:
		return
	var id: String = _city_opt.get_item_metadata(_city_opt.selected) if _city_opt.item_count > 0 else ""
	if id == "":
		EventBus.toast.emit(Localization.t("toast.select_city"))
		return
	GameManager.hub_sys.build(GameManager, id)

func _on_upgrade(h: Hub) -> void:
	GameManager.hub_sys.upgrade(GameManager, h)
