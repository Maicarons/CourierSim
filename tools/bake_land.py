#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bake_land.py — 从 Natural Earth 50m 陆地矢量数据烘焙各区域的陆地多边形。

数据源: Natural Earth (https://www.naturalearthdata.com/) — Public Domain
下载: https://cdn.jsdelivr.net/gh/nvkelso/natural-earth-vector@master/geojson/ne_50m_land.geojson

流程:
  1. 读取区域 JSON（src/map/data/regions/<id>.json）得到城市包围盒
  2. 对每个陆地 polygon 与包围盒做 Sutherland-Hodgman 裁剪
  3. 滤除面积过小的碎片，输出 <id>_land.json（经纬度环，WGS84）

输出: src/map/data/regions/<id>_land.json
"""

import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NE = os.path.join(ROOT, "tools", "data", "ne_50m_land.geojson")
REG_DIR = os.path.join(ROOT, "src", "map", "data", "regions")

MARGIN = {  # 每区域包围盒外扩的经纬度数
    "korea": 1.6,
    "hainan": 1.2,
    "vietnam": 1.3,
    "malaysia": 1.6,
}
MIN_AREA = 0.02  # 经纬度平方度，滤除极小微岛


def clip_poly(ring, bbox):
    """Sutherland-Hodgman: 用 bbox (minx,miny,maxx,maxy) 裁剪多边形环。"""
    minx, miny, maxx, maxy = bbox
    output = ring
    for edge in range(4):
        input_ = output
        if not input_:
            return []
        output = []
        n = len(input_)
        for i in range(n):
            cur = input_[i]
            nxt = input_[(i + 1) % n]
            cur_in = _inside(cur, edge, minx, miny, maxx, maxy)
            nxt_in = _inside(nxt, edge, minx, miny, maxx, maxy)
            if cur_in and nxt_in:
                output.append(nxt)
            elif cur_in and not nxt_in:
                output.append(_inter(cur, nxt, edge, minx, miny, maxx, maxy))
            elif not cur_in and nxt_in:
                output.append(_inter(cur, nxt, edge, minx, miny, maxx, maxy))
                output.append(nxt)
    return output


def _inside(p, edge, minx, miny, maxx, maxy):
    x, y = p
    if edge == 0: return x >= minx   # left
    if edge == 1: return x <= maxx   # right
    if edge == 2: return y >= miny   # bottom
    return y <= maxy                  # top


def _inter(a, b, edge, minx, miny, maxx, maxy):
    """线段 ab 与边界 edge 的交点。"""
    ax, ay = a
    bx, by = b
    if edge == 0 and bx != ax:
        t = (minx - ax) / (bx - ax)
        return (minx, ay + t * (by - ay))
    if edge == 1 and bx != ax:
        t = (maxx - ax) / (bx - ax)
        return (maxx, ay + t * (by - ay))
    if edge == 2 and by != ay:
        t = (miny - ay) / (by - ay)
        return (ax + t * (bx - ax), miny)
    if edge == 3 and by != ay:
        t = (maxy - ay) / (by - ay)
        return (ax + t * (bx - ax), maxy)
    return a


def ring_area(ring):
    """鞋带公式（经纬度平方度近似）。"""
    s = 0.0
    n = len(ring)
    for i in range(n):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return abs(s) * 0.5


def simplify(ring, tol=0.008):
    """Douglas-Peucker 简化，控制点数（50m 数据本身已较稀疏）。"""
    if len(ring) <= 4:
        return ring
    keep = [0, len(ring) - 1]
    stack = [(0, len(ring) - 1)]
    while stack:
        a, b = stack.pop()
        if b - a < 2:
            continue
        ax, ay = ring[a]
        bx, by = ring[b]
        dx, dy = bx - ax, by - ay
        ln = math.hypot(dx, dy)
        maxd = 0.0
        idx = -1
        for i in range(a + 1, b):
            px, py = ring[i]
            if ln < 1e-9:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs(dy * px - dx * py - (dy * ax - dx * ay)) / ln
            if d > maxd:
                maxd = d
                idx = i
        if maxd > tol and idx != -1:
            keep.append(idx)
            stack.append((a, idx))
            stack.append((idx, b))
    keep.sort()
    return [ring[i] for i in keep]


def bake(region_id):
    reg_path = os.path.join(REG_DIR, region_id + ".json")
    if not os.path.exists(reg_path):
        return None
    reg = json.load(open(reg_path, encoding="utf-8"))
    lats = [c["lat"] for c in reg["cities"]]
    lons = [c["lon"] for c in reg["cities"]]
    m = MARGIN.get(region_id, 1.2)
    bbox = (min(lons) - m, min(lats) - m, max(lons) + m, max(lats) + m)
    ne = json.load(open(NE, encoding="utf-8"))
    polys = []
    for f in ne["features"]:
        geom = f["geometry"]
        rings = []
        if geom["type"] == "Polygon":
            rings = geom["coordinates"]
        elif geom["type"] == "MultiPolygon":
            for r in geom["coordinates"]:
                rings.extend(r)
        for ring in rings:
            clipped = clip_poly(ring, bbox)
            if len(clipped) >= 3 and ring_area(clipped) >= MIN_AREA:
                clipped = simplify(clipped)
                if len(clipped) >= 3:
                    # 去掉首尾重复点，统一为闭合环
                    if clipped[0] == clipped[-1]:
                        clipped = clipped[:-1]
                    polys.append([[round(x, 4), round(y, 4)] for x, y in clipped])
    out = {"id": region_id, "source": "Natural Earth 50m (Public Domain)",
           "bbox": list(bbox), "polys": polys}
    out_path = os.path.join(REG_DIR, region_id + "_land.json")
    json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False)
    total_pts = sum(len(p) for p in polys)
    return {"id": region_id, "polys": len(polys), "pts": total_pts, "path": out_path}


def main():
    os.makedirs(REG_DIR, exist_ok=True)
    for rid in ["korea", "hainan", "vietnam", "malaysia"]:
        info = bake(rid)
        if info:
            print("[OK] %-10s polys=%-4d pts=%d -> %s" % (info["id"], info["polys"], info["pts"], info["path"]))
        else:
            print("[MISS] %s (no region json)" % rid)


if __name__ == "__main__":
    main()
