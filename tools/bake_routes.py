#!/usr/bin/env python3
"""bake_routes.py — 用 OSRM（OpenStreetMap 路网）烘焙区域城市对真实路径。

为每个区域生成 <region_id>_routes.json：
  {
    "origin_id": "korea",
    "generated": "2026-08-14",
    "routes": [
      {"a": "seoul", "b": "busan",
       "dist_km": 392.6, "dur_h": 4.85,
       "path": [[lng, lat], ...]},   # 简化折线（WGS84）
      ...
    ]
  }

用法: python tools/bake_routes.py [region_id ...]   # 默认全部
依赖: requests（如无则用 urllib 兜底）
"""
import json
import math
import os
import sys
import time
import urllib.request

BASE = "https://router.project-osrm.org/route/v1/driving"
REGION_DIR = os.path.join(os.path.dirname(__file__), "..", "src", "map", "data", "regions")
DEFAULT_REGIONS = ["korea", "hainan", "vietnam", "malaysia"]

# 折线简化容差（度，约 0.004° ≈ 400m）：太长路径点压下来，游戏运行时逐段移动足够平滑
TOLERANCE_DEG = 0.004
# 每请求间隔（秒）：公共 OSRM 有速率限制，保守一点
REQUEST_DELAY = 0.35
MAX_RETRY = 4


def fetch_route(a_lng, a_lat, b_lng, b_lat):
    """请求 OSRM，返回 (dist_m, dur_s, coords) 或 None。"""
    url = f"{BASE}/{a_lng},{a_lat};{b_lng},{b_lat}?overview=full&geometries=geojson"
    for attempt in range(MAX_RETRY):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "CourierSim-baker/1.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            if data.get("code") == "Ok" and data.get("routes"):
                r = data["routes"][0]
                coords = r.get("geometry", {}).get("coordinates", [])
                return r.get("distance", 0.0), r.get("duration", 0.0), coords
            print(f"  ! code={data.get('code')}")
        except Exception as e:
            print(f"  ! attempt {attempt+1} fail: {e}")
        time.sleep(REQUEST_DELAY * (attempt + 1))
    return None


def douglas_peucker(points, tol):
    """折线简化（Ramer–Douglas–Peucker）。points: [(x,y),...]"""
    if len(points) <= 2:
        return points

    def seg_dist(p, a, b):
        ax, ay = a
        bx, by = b
        px, py = p
        dx, dy = bx - ax, by - ay
        if dx == 0 and dy == 0:
            return math.hypot(px - ax, py - ay)
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        cx, cy = ax + t * dx, ay + t * dy
        return math.hypot(px - cx, py - cy)

    def rec(pts):
        if len(pts) <= 2:
            return pts
        dmax, idx = 0.0, 0
        a, b = pts[0], pts[-1]
        for i in range(1, len(pts) - 1):
            d = seg_dist(pts[i], a, b)
            if d > dmax:
                dmax, idx = d, i
        if dmax > tol:
            left = rec(pts[: idx + 1])
            right = rec(pts[idx:])
            return left[:-1] + right
        return [a, b]

    return rec(points)


def bake_region(region_id, cities):
    routes = []
    n = len(cities)
    total = n * (n - 1) // 2
    done = 0
    for i in range(n):
        for j in range(i + 1, n):
            a, b = cities[i], cities[j]
            res = fetch_route(a["lon"], a["lat"], b["lon"], b["lat"])
            done += 1
            if res is None:
                print(f"[{region_id}] {a['id']}-{b['id']} FAIL (skip)")
                continue
            dist_m, dur_s, coords = res
            if not coords:
                print(f"[{region_id}] {a['id']}-{b['id']} no coords (skip)")
                continue
            pts = [(c[0], c[1]) for c in coords]
            simplified = douglas_peucker(pts, TOLERANCE_DEG)
            routes.append({
                "a": a["id"], "b": b["id"],
                "dist_km": round(dist_m / 1000.0, 1),
                "dur_h": round(dur_s / 3600.0, 2),
                "path": [[round(x, 5), round(y, 5)] for x, y in simplified],
            })
            print(f"[{region_id}] {done}/{total} {a['id']}-{b['id']} "
                  f"{routes[-1]['dist_km']}km {routes[-1]['dur_h']}h pts={len(simplified)}")
            time.sleep(REQUEST_DELAY)
    return routes


def main():
    targets = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_REGIONS
    for rid in targets:
        region_path = os.path.join(REGION_DIR, f"{rid}.json")
        if not os.path.exists(region_path):
            print(f"!! 区域文件缺失: {region_path}")
            continue
        reg = json.load(open(region_path, encoding="utf-8"))
        cities = reg.get("cities", [])
        print(f"=== {rid}: {len(cities)} cities ===")
        routes = bake_region(rid, cities)
        out = {
            "origin_id": rid,
            "generated": time.strftime("%Y-%m-%d"),
            "source": "OSRM public (OpenStreetMap road network)",
            "routes": routes,
        }
        out_path = os.path.join(REGION_DIR, f"{rid}_routes.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
        print(f"[{rid}] 完成 {len(routes)} 条 -> {out_path}")


if __name__ == "__main__":
    main()
