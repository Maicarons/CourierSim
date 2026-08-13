#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_strings_v5.py — 追加 v0.8 新键（沙盒参数/区域特色），中英同步。"""
import json

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

NEW = {
    "zh_CN": {
        "menu.sandbox_opts": "沙盒参数",
        "menu.funds": "起点资金",
        "menu.competition": "竞争强度",
        "menu.comp_off": "无竞争",
        "menu.comp_normal": "标准",
        "menu.comp_hard": "高强度",
        "menu.events": "随机事件",
    },
    "en_US": {
        "menu.sandbox_opts": "Sandbox Options",
        "menu.funds": "Starting Funds",
        "menu.competition": "Competition",
        "menu.comp_off": "None",
        "menu.comp_normal": "Standard",
        "menu.comp_hard": "High",
        "menu.events": "Random Events",
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