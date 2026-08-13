#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bake_terrain.py — 把各区域陆地多边形光栅化为卡通地形贴图（PNG）。

数据源: Natural Earth 50m (Public Domain)，多边形来自 bake_land.py 的产物。
输出:   src/map/data/regions/<id>_terrain.png（RGBA，海洋透明，陆地带噪声地形色）
MapView 运行时直接拉伸绘制，零计算成本。
"""

import json
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REG_DIR = os.path.join(ROOT, "src", "map", "data", "regions")
MAX_DIM = 768   # 贴图最大边长（像素）

# 与 MapView 一致的卡通地形色板
TERRAIN = {
    "grass": (143, 201, 117),
    "grass2": (158, 209, 122),
    "hill": (171, 130, 99),
    "hill2": (184, 144, 108),
    "sand": (237, 219, 143),
}
INK = (56, 43, 33)


def _hash2(x, y, seed=0.0):
    s = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453
    return s - math.floor(s)


def terrain_color(lon, lat):
    """确定性噪声：陆地 tile 的地形色（grass/hill/sand）。"""
    f1 = _hash2(lon * 0.55, lat * 0.55, 1.0)
    f2 = _hash2(lon * 1.9 + 100.0, lat * 1.9 + 100.0, 2.0)
    n = f1 * 0.7 + f2 * 0.3
    if n < 0.40:
        return TERRAIN["grass"]
    if n < 0.62:
        return TERRAIN["grass2"]
    if n < 0.84:
        return TERRAIN["hill"]
    return TERRAIN["hill2"]


def bake(region_id):
    land_path = os.path.join(REG_DIR, region_id + "_land.json")
    if not os.path.exists(land_path):
        print("[MISS] %s_land.json" % region_id)
        return
    land = json.load(open(land_path, encoding="utf-8"))
    minx, miny, maxx, maxy = land["bbox"]
    lonspan = maxx - minx
    latspan = maxy - miny
    # 等距圆柱：纬度方向 1° ≈ 111km，经度方向 ≈ 111*cos(mean_lat) km
    mean_lat = math.radians((miny + maxy) * 0.5)
    kx = math.cos(mean_lat)
    w = max(64, int(round(MAX_DIM * (lonspan * kx) / (max(lonspan * kx, latspan)))))
    h = max(64, int(round(MAX_DIM * latspan / (max(lonspan * kx, latspan)))))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for poly in land["polys"]:
        pts = [((p[0] - minx) / lonspan * w, (maxy - p[1]) / latspan * h) for p in poly]
        d.polygon(pts, fill=255)
    px = img.load()
    msk = mask.load()
    rnd = random.Random(region_id + "_grid")
    tile = 10  # 像素网格线间隔（模拟 tile 卡通风）
    for y in range(h):
        for x in range(w):
            if not msk[x, y]:
                continue
            lon = minx + (x + 0.5) / w * lonspan
            lat = maxy - (y + 0.5) / h * latspan
            base = terrain_color(lon, lat)
            v = rnd.randint(-7, 7)
            c = (max(0, min(255, base[0] + v)),
                 max(0, min(255, base[1] + v)),
                 max(0, min(255, base[2] + v)))
            # 网格线：暗色细线
            if x % tile == 0 or y % tile == 0:
                c = tuple(max(0, t - 26) for t in c)
            px[x, y] = c + (255,)
    # 陆地外围描边（海岸线高亮）
    outline = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(outline)
    for poly in land["polys"]:
        pts = [((p[0] - minx) / lonspan * w, (maxy - p[1]) / latspan * h) for p in poly]
        od.line(pts + [pts[0]], fill=INK + (255,), width=3, joint="curve")
    img = Image.alpha_composite(img, outline)
    out = os.path.join(REG_DIR, region_id + "_terrain.png")
    img.save(out)
    print("[OK] %-10s %dx%d -> %s" % (region_id, w, h, out))


def main():
    for rid in ["korea", "hainan", "vietnam", "malaysia"]:
        bake(rid)


if __name__ == "__main__":
    main()
