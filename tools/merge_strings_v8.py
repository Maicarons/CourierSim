#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""v0.11 手动派单 + 地图订单路线：合并新 i18n 键（中英），保留已有键。"""
import json, io

P = r"G:\GitHub\CourierSim\src\i18n\strings.json"
NEW = {
    "zh_CN": {
        "picker.hint": "点击车辆立即派单（按距发货城市排序）",
        "picker.empty": "没有可用的空闲车辆\n请先购买能承运该货种的车辆，或等待在途车辆返回",
        "picker.assign": "派单",
        "order.dispatch": "派单",
        "order.auto_assign": "自动派单",
        "tip.auto_assign": "自动把待分配订单派给空闲车辆；关闭后手动派单",
        "toast.auto_assign": "自动派单：%s",
        "order.auto_on": "开启",
        "order.auto_off": "关闭",
        "toast.dispatch_ok": "%s 已接单 %s",
        "order.id": "订单",
    },
    "en_US": {
        "picker.hint": "Click a vehicle to dispatch (sorted by distance)",
        "picker.empty": "No idle vehicle available\nBuy a capable vehicle or wait for en-route vehicles to return",
        "picker.assign": "Dispatch",
        "order.dispatch": "Dispatch",
        "order.auto_assign": "Auto-assign",
        "tip.auto_assign": "Automatically assign pending orders to idle vehicles; turn off for manual dispatch",
        "toast.auto_assign": "Auto-assign: %s",
        "order.auto_on": "ON",
        "order.auto_off": "OFF",
        "toast.dispatch_ok": "%s accepted %s",
        "order.id": "Order",
    },
}

def main():
    d = json.load(open(P, encoding="utf-8"))
    added = 0
    for loc, kv in NEW.items():
        for k, v in kv.items():
            if k not in d[loc]:
                d[loc][k] = v
                added += 1
    with io.open(P, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
    print("merged: +%d keys" % added)
    for loc in d:
        print(loc, len(d[loc]))

if __name__ == "__main__":
    main()
