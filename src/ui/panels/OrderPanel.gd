class_name OrderPanel
extends VBoxContainer

## 订单标签页：卡片行列出当前订单（含待处理计数汇总），只读展示。

func build() -> void:
	UI.header(self, Localization.t("panel.orders.title"))
	var pending := 0
	for o in GameManager.orders:
		var oc := RegionManager.current.get_city(o.origin_id)
		var dc := RegionManager.current.get_city(o.dest_id)
		var oname := oc.display_name() if oc else "?"
		var dname := dc.display_name() if dc else "?"
		var title := "%s → %s" % [oname, dname]
		var sub := "%s · %s · 奖 %d · 限 %d天" % [CargoType.name_of(o.cargo_type), UI.order_status_name(o.status), o.reward, o.deadline_day - GameManager.day]
		add_child(UI.info_row(Assets.get_image("ui_order"), title, sub, []))
		if o.status == Order.Status.PENDING:
			pending += 1
	UI.header(self, Localization.t("panel.orders.summary") % [pending, GameManager.orders.size()])
