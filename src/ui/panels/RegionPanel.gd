class_name RegionPanel
extends VBoxContainer

## 区域标签页：卡片行列出全部区域，已解锁可切换、未解锁可花钱解锁。
## 解锁/切换属于游戏流程逻辑，交给 GameScene 协调层处理（通过信号回传）。

signal unlock_requested(region: Region)
signal switch_requested(region_id: String)

func build() -> void:
	UI.header(self, Localization.t("panel.region.title"))
	for r in RegionManager.regions:
		var sub := "难度 %d · 城市 %d · 解锁 %d元" % [r.difficulty, r.cities.size(), r.unlock_cost]
		var actions := []
		if GameManager.unlocked_region_ids.has(r.id):
			if RegionManager.current != r:
				actions = [{text = Localization.t("btn.switch"), cb = _on_switch.bind(r.id), color = UI.BLUE}]
			else:
				sub += " · 当前区域"
		else:
			actions = [{text = Localization.t("btn.unlock_region") % r.unlock_cost, cb = _on_unlock.bind(r), color = UI.GREEN}]
		add_child(UI.info_row(Assets.get_image("bld_hq"), r.display_name(), sub, actions))

func _on_unlock(r: Region) -> void:
	unlock_requested.emit(r)

func _on_switch(id: String) -> void:
	switch_requested.emit(id)
