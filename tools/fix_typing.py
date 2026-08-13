#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_typing.py — Godot 4.7.1 严格类型推断兼容：
对每个目标文件中已知问题行做子串替换（忽略前后空白），加显式类型标注。
"""
import os

ROOT = r"G:\GitHub\CourierSim\src"

PATCHES = {
    "systems/OrderSystem.gd": [
        ("var region := RegionManager.current", "var region: Region = RegionManager.current"),
        ("var home := RegionManager.current.get_city(v.home_city_id)",
         "var home: City = RegionManager.current.get_city(v.home_city_id)"),
        ("var oc := RegionManager.current.get_city(o.origin_id)",
         "var oc: City = RegionManager.current.get_city(o.origin_id)"),
        ("var dc := RegionManager.current.get_city(o.dest_id)",
         "var dc: City = RegionManager.current.get_city(o.dest_id)"),
        ("var from := RegionManager.local(oc)", "var from: Vector2 = RegionManager.local(oc)"),
        ("var to := RegionManager.local(dc)", "var to: Vector2 = RegionManager.local(dc)"),
    ],
    "systems/VehicleSystem.gd": [
        ("var home := RegionManager.current.get_city(v.home_city_id)",
         "var home: City = RegionManager.current.get_city(v.home_city_id)"),
    ],
    "systems/HubSystem.gd": [
        ("var c := RegionManager.current.get_city(city_id)",
         "var c: City = RegionManager.current.get_city(city_id)"),
        ("var name := \"中转库 \" + (c.name if c else city_id)",
         "var name: String = \"中转库 \" + (c.name if c else city_id)"),
    ],
    "systems/StationSystem.gd": [
        ("var c := RegionManager.current.get_city(city_id)",
         "var c: City = RegionManager.current.get_city(city_id)"),
        ("var name := \"站点 \" + (c.name if c else city_id)",
         "var name: String = \"站点 \" + (c.name if c else city_id)"),
    ],
    "systems/CompetitorSystem.gd": [
        ("var comp_base := competitor_demand *",
         "var comp_base: float = competitor_demand *"),
    ],
    "ui/MainMenu.gd": [
        ("var locked := r.unlock_cost > 0", "var locked: bool = r.unlock_cost > 0"),
        ("var reg := RegionManager.get_region(region_id)",
         "var reg: Region = RegionManager.get_region(region_id)"),
    ],
}


def fix_file(rel: str, content: str) -> tuple:
    n = 0
    for old, new in PATCHES.get(rel, []):
        if old in content:
            content = content.replace(old, new)
            n += 1
    return n, content


def fix_region_manager(content: str) -> tuple:
    n = 0
    bad2 = '\tif not fname.begins_with(".") and fname.ends_with(".json"):\nvar path'
    good2 = '\tif not fname.begins_with(".") and fname.ends_with(".json"):\n\tvar path'
    if bad2 in content:
        content = content.replace(bad2, good2, 1)
        n += 1
    return n, content


def main():
    for rel in PATCHES:
        p = os.path.join(ROOT, rel)
        with open(p, "r", encoding="utf-8", newline="") as f:
            content = f.read()
        n, content = fix_file(rel, content)
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print(f"[{rel}] {n} 替换")
    rm = os.path.join(ROOT, r"autoload\RegionManager.gd")
    with open(rm, "r", encoding="utf-8", newline="") as f:
        content = f.read()
    n, content = fix_region_manager(content)
    with open(rm, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"[RegionManager.gd] {n} 修复")


if __name__ == "__main__":
    main()