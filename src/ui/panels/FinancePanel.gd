class_name FinancePanel
extends VBoxContainer

## 财务标签页：卡片行展示资金/声誉/市占/竞争对手，以及近期账目流水（只读）。

func build() -> void:
	UI.header(self, Localization.t("panel.finance.title"))
	add_child(UI.info_row(Assets.get_image("ui_coin"), Localization.t("finance.funds") % GameManager.money, "", []))
	add_child(UI.info_row(Assets.get_image("ui_star"), Localization.t("finance.rep") % int(GameManager.reputation), "", []))
	add_child(UI.info_row(Assets.get_image("ui_finance"), Localization.t("finance.share") % int(GameManager.competitor_sys.player_share() * 100.0), "", []))
	# 借贷信息 + 操作
	add_child(UI.info_row(Assets.get_image("ui_coin"), Localization.t("finance.debt") % GameManager.debt,
		Localization.t("finance.loan_limit") % GameManager.max_loan(),
		[{text = Localization.t("btn.loan"), cb = _on_loan, color = UI.PURPLE},
		 {text = Localization.t("btn.repay"), cb = _on_repay, color = UI.BLUE}]))
	var cs := GameManager.competitor_sys
	if cs.competitors.is_empty():
		add_child(UI.info_row(Assets.get_image("bld_hq"), Localization.t("finance.no_comp"), "", []))
	else:
		for c in cs.competitors:
			var sub := Localization.t("finance.comp_share") % int(c["share"] * 100.0)
			add_child(UI.info_row(Assets.get_image("bld_hq"), cs.comp_display(c), sub, []))
	UI.header(self, Localization.t("panel.finance.recent"))
	var n: int = min(GameManager.ledger.size(), 12)
	for i in range(GameManager.ledger.size() - n, GameManager.ledger.size()):
		var e: Dictionary = GameManager.ledger[i]
		var title := Localization.t("row.ledger") % [e["day"], e["amount"]]
		var sub := "%s · %s" % [Localization.t("cat." + e["category"]), e["label"]]
		add_child(UI.info_row(null, title, sub, []))

## 借款：一次借入 max_loan 的 1/4（可重复）
func _on_loan() -> void:
	var amount: int = maxi(10000, int(GameManager.max_loan() * 0.25))
	GameManager.borrow(amount)

## 还款：一次偿还 25% 负债
func _on_repay() -> void:
	if GameManager.debt <= 0:
		EventBus.toast.emit(Localization.t("toast.no_debt"))
		return
	var amount: int = maxi(1000, int(GameManager.debt * 0.25))
	GameManager.repay(amount)
