#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_strings_v6.py — 追加 v0.9 新键（公司总览/成就横幅），中英同步。"""
import json

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

NEW = {
    "zh_CN": {
        "tip.tab_overview": "总览 — 公司概况与经营数据",
        "ov.title": "公司总览",
        "ov.stats": "关键经营数据",
        "ov.assets": "总资产 %d",
        "ov.share": "市占率 %d%%",
        "ov.delivered": "累计配送 %d",
        "ov.days": "经营 %d 天",
        "ov.fleet": "车队 %d 辆",
        "ov.network": "网络 %d 仓 / %d 站",
        "ov.staff": "员工 %d 人",
        "ov.share_title": "市场份额对比",
        "ov.region_features": "区域特色",
        "ov.region_demand": "本地需求加成 %d%%",
        "ov.region_demand_desc": "该区域整体订单需求高于基准（数据驱动）",
        "ov.no_features": "当前区域暂无特色内容",
        "ov.ach_progress": "成就进度",
        "ov.ach_hint": "更多成就见「设置 → 成就」",
        "toast.ach_banner": "🏅 成就解锁！",
        "mode_name.career": "生涯模式",
        "mode_name.sandbox": "沙盒模式",
    },
    "en_US": {
        "tip.tab_overview": "Overview — company summary & KPIs",
        "ov.title": "Company Overview",
        "ov.stats": "Key Metrics",
        "ov.assets": "Total assets %d",
        "ov.share": "Market share %d%%",
        "ov.delivered": "Deliveries %d",
        "ov.days": "Days %d",
        "ov.fleet": "Fleet %d",
        "ov.network": "Network %d hubs / %d stations",
        "ov.staff": "Staff %d",
        "ov.share_title": "Market Share",
        "ov.region_features": "Region Features",
        "ov.region_demand": "Local demand bonus %d%%",
        "ov.region_demand_desc": "This region has higher baseline demand (data-driven)",
        "ov.no_features": "No region features yet",
        "ov.ach_progress": "Achievements",
        "ov.ach_hint": "More in Settings -> Achievements",
        "toast.ach_banner": "🏅 Achievement unlocked!",
        "mode_name.career": "Career Mode",
        "mode_name.sandbox": "Sandbox Mode",
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