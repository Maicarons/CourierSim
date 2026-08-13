#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate small pixel-art UI chrome icons for CourierSim via the local ComfyUI
server, reusing graph_final.json (Ernie Image Turbo + BiRefNet, transparent bg).

Outputs -> G:/GitHub/CourierSim/assets/images/ui_*.png
"""

import json
import os
import time
import urllib.request
import shutil
import uuid

COMFY = "http://127.0.0.1:8188"
COMFY_OUTPUT = r"G:/ComfyUI-aki-v2/ComfyUI/output"
PROJECT = r"G:/GitHub/CourierSim"
WF_DIR = os.path.join(PROJECT, "comfyui")
IMG_DIR = os.path.join(PROJECT, "assets", "images")

STYLE = (", 2D pixel art, Nintendo 8-bit game UI icon, bold black outline, "
         "flat colors, minimal shading, simple, solid centered icon, "
         "isolated on white background, transparent background")

UI_JOBS = [
    ("ui_coin", "a simple round gold coin with a currency symbol in the center"),
    ("ui_star", "a simple five-pointed yellow star"),
    ("ui_calendar", "a simple wall calendar with a grid of squares and a top binding"),
    ("ui_play", "a simple green right-pointing triangle play button"),
    ("ui_pause", "a simple pair of two vertical yellow bars pause button"),
    ("ui_save", "a simple blue floppy disk save icon"),
    ("ui_home", "a simple red and brown house home icon with a door"),
    ("ui_globe", "a simple blue and green earth globe with continents, language icon"),
    ("ui_marketing", "a simple orange megaphone loudspeaker, advertising icon"),
    ("ui_tech", "a simple glowing yellow light bulb idea icon, technology"),
    ("ui_finance", "a simple gold money bag with a coin, finance icon"),
    ("ui_order", "a simple brown cardboard parcel box with a shipping label, order icon"),
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


def _wait(prompt_id, timeout=300):
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


def run_one(jid, subject, prefix="courier_sim"):
    g = json.load(open(os.path.join(WF_DIR, "graph_final.json")))
    g["5"]["inputs"]["text"] = subject + STYLE
    g["18"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, jid)
    g["7"]["inputs"]["seed"] = (uuid.uuid4().int >> 16) % (2 ** 32)
    pid = _post({"prompt": g, "client_id": "courier_sim"})["prompt_id"]
    out = _wait(pid)
    target = os.path.join(IMG_DIR, jid + ".png")
    ok = _copy_out(out.get("outputs", {}).get("18", {}), target)
    return ok, target


def main():
    os.makedirs(IMG_DIR, exist_ok=True)
    print("TOTAL UI ICON JOBS: %d" % len(UI_JOBS))
    done = 0
    for jid, subject in UI_JOBS:
        t0 = time.time()
        try:
            ok, target = run_one(jid, subject)
            dt = int(time.time() - t0)
            print("[%s] %s -> %s (%ds)" % ("OK" if ok else "NO-FILE", jid, target, dt))
            done += 1 if ok else 0
        except Exception as e:
            print("[FAIL] %s : %s" % (jid, e))
    print("DONE: %d/%d successful" % (done, len(UI_JOBS)))


if __name__ == "__main__":
    main()
