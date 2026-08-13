#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate achievement-specific pixel icons via local ComfyUI.
Outputs -> G:/GitHub/CourierSim/assets/images/ach_*.png
"""
import json
import os
import sys
import time
import urllib.request
import shutil
import uuid

COMFY = "http://127.0.0.1:8188"
COMFY_OUTPUT = r"G:/ComfyUI-aki-v2/ComfyUI/output"
PROJECT = r"G:/GitHub/CourierSim"
WF_DIR = os.path.join(PROJECT, "comfyui")
IMG_DIR = os.path.join(PROJECT, "assets", "images")
WF = os.path.join(WF_DIR, "graph_final.json")

STYLE = (", 2D pixel art, Nintendo 8-bit game achievement icon, bold black outline, "
         "flat colors, minimal shading, simple, solid centered icon, "
         "isolated on white background, transparent background")

ACH_JOBS = [
    ("ach_first_vehicle", "a small delivery van with a key in front, achievement icon"),
    ("ach_fleet_five", "five delivery vans lined up in a row, achievement icon"),
    ("ach_first_delivery", "an opened cardboard box with a letter flying out, achievement icon"),
    ("ach_deliver_50", "a tall pile of cardboard parcels, achievement icon"),
    ("ach_network_hubs", "three warehouse buildings with a connected line, achievement icon"),
    ("ach_network_stations", "a map with three location pin markers, achievement icon"),
    ("ach_staff_team", "three worker people standing together, achievement icon"),
    ("ach_tech_research", "a glowing light bulb with a gear, achievement icon"),
    ("ach_millionaire", "a gold coin pile with a dollar coin on top, achievement icon"),
    ("ach_share_30", "a rising bar chart with a small crown on top, achievement icon"),
    ("ach_day_30", "a calendar with a large 30 on it, achievement icon"),
    ("ach_world_traveler", "a globe with a plane flying around it, achievement icon"),
]


def _post(payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(COMFY + "/prompt", data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def _get(path):
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def _wait(prompt_id, timeout=600):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            hist = _get("/history/" + prompt_id)
        except Exception:
            time.sleep(3)
            continue
        if prompt_id in hist:
            return hist[prompt_id]
        time.sleep(2)
    raise TimeoutError("prompt %s timed out" % prompt_id)


def _copy_out(node_outputs, target):
    items = node_outputs.get("images")
    if not items:
        return False
    for it in items:
        sub = it.get("subfolder", "")
        fname = it.get("filename")
        src = os.path.join(COMFY_OUTPUT, sub, fname) if sub else os.path.join(COMFY_OUTPUT, fname)
        if os.path.exists(src):
            shutil.copy(src, target)
            return True
    return False


def run_one(jid, subject, prefix="courier_sim_ach"):
    g = json.load(open(WF, encoding="utf-8"))
    g["5"]["inputs"]["text"] = subject + STYLE
    g["18"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, jid)
    g["7"]["inputs"]["seed"] = (uuid.uuid4().int >> 16) % (2 ** 32)
    pid = _post({"prompt": g, "client_id": "courier_sim_ach"})["prompt_id"]
    out = _wait(pid)
    target = os.path.join(IMG_DIR, jid + ".png")
    ok = _copy_out(out.get("outputs", {}).get("18", {}), target)
    return ok, target


def main():
    os.makedirs(IMG_DIR, exist_ok=True)
    print("TOTAL ACH JOBS: %d" % len(ACH_JOBS))
    done = 0
    for jid, subject in ACH_JOBS:
        target = os.path.join(IMG_DIR, jid + ".png")
        if os.path.exists(target):
            print("[SKIP] %s exists" % jid)
            done += 1
            continue
        t0 = time.time()
        try:
            ok, target = run_one(jid, subject)
            print("[%s] %s (%ds)" % ("OK" if ok else "NO-FILE", jid, int(time.time() - t0)))
            done += 1 if ok else 0
        except Exception as e:
            print("[FAIL] %s : %s" % (jid, e))
    print("DONE: %d/%d" % (done, len(ACH_JOBS)))


if __name__ == "__main__":
    main()
