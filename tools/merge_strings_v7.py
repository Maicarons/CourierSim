#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_strings_v7.py — 追加 v0.10 新键（订单面板分组/奖励），中英同步。"""
import json

PATH = r"G:\GitHub\CourierSim\src\i18n\strings.json"

NEW = {
    "zh_CN": {
        "order.group.pending": "待分配",
        "order.group.intransit": "在途",
        "order.group.delivered": "已送达",
        "order.group.failed": "超时",
        "order.reward": "奖 %d",
        "order.done_day": "第 %d 天送达",
        "order.timeout_day": "第 %d 天超时",
    },
    "en_US": {
        "order.group.pending": "Pending",
        "order.group.intransit": "In Transit",
        "order.group.delivered": "Delivered",
        "order.group.failed": "Failed",
        "order.reward": "Rew %d",
        "order.done_day": "Delivered Day %d",
        "order.timeout_day": "Timed out Day %d",
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