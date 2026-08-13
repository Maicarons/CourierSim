#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
merge_strings_v3.py — 追加 v0.5 新增键（结算面板/存档槽位/竞争事件），中英同步。
"""
import json

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

NEW = {
    "zh_CN": {
        "menu.saves_title": "存档槽位",
        "menu.back": "返回",
        "menu.no_company": "（未命名公司）",
        "save.autosave": "自动存档",
        "save.slot": "存档 %s",
        "toast.comp_new": "新竞争对手进入市场：%s",
        "toast.comp_promo": "%s 正在大促销，你的市场份额被抢走了！",
        "finance.no_comp": "暂无竞争对手",
        "finance.comp_share": "市占 %d%%",
        "gameover.title_victory": "🏆 快递王国称霸！",
        "gameover.title_defeat": "💔 经营失败",
        "gameover.rating": "生涯评级：%s",
        "gameover.days": "经营天数",
        "gameover.money": "现金",
        "gameover.assets": "总资产",
        "gameover.share": "市场占有率",
        "gameover.reputation": "声誉",
        "gameover.delivered": "累计配送",
        "gameover.vehicles": "车队规模",
        "gameover.network": "网络规模",
        "gameover.to_menu": "返回主菜单",
        "gameover.play_again": "再来一局",
        "game.over.victory": "达成 S/A 评级，你的快递帝国称霸了该区域！",
    },
    "en_US": {
        "menu.saves_title": "Save Slots",
        "menu.back": "Back",
        "menu.no_company": "(unnamed)",
        "save.autosave": "Autosave",
        "save.slot": "Slot %s",
        "toast.comp_new": "A new competitor enters the market: %s",
        "toast.comp_promo": "%s is running a big promotion — your share drops!",
        "finance.no_comp": "No competitors yet",
        "finance.comp_share": "Share %d%%",
        "gameover.title_victory": "🏆 Courier Empire!",
        "gameover.title_defeat": "💔 Business Failed",
        "gameover.rating": "Career Rating: %s",
        "gameover.days": "Days in business",
        "gameover.money": "Cash",
        "gameover.assets": "Total assets",
        "gameover.share": "Market share",
        "gameover.reputation": "Reputation",
        "gameover.delivered": "Deliveries",
        "gameover.vehicles": "Fleet size",
        "gameover.network": "Network size",
        "gameover.to_menu": "Main Menu",
        "gameover.play_again": "Play Again",
        "game.over.victory": "Reached S/A rating — your courier empire dominates the region!",
    },
}


def main():
    with open(PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    added = 0
    for locale in NEW:
        table = data.setdefault(locale, {})
        for k, v in NEW[locale].items():
            if k not in table:
                table[k] = v
                added += 1
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    with open(PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("merged %d new keys" % added)


if __name__ == "__main__":
    main()