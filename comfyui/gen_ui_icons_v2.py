#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate ADDITIONAL pixel-art UI icons for CourierSim via the local ComfyUI
server (Ernie Image Turbo + PerfectPixel + BiRefNet, transparent bg).
Only generates the NEW icons (settings/about/help/objective/back/quit/...).
Outputs -> G:/GitHub/CourierSim/assets/images/ui_*.png
Usage: python gen_ui_icons_v2.py [--limit N] [--dry]
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

STYLE = (", 2D pixel art, Nintendo 8-bit game UI icon, bold black outline, "
         "flat colors, minimal shading, simple, solid centered icon, "
         "isolated on white background, transparent background")

UI_JOBS_V2 = [
    ("ui_settings", "a simple silver metal gear cogwheel with teeth around, settings icon"),
    ("ui_about", "a simple blue circle badge with a white lowercase i letter in the center, information icon"),
    ("ui_help", "a simple blue circle badge with a white question mark in the center, help icon"),
    ("ui_objective", "a simple orange pennant flag on a pole, mission objective icon"),
    ("ui_back", "a simple white left-pointing arrow on a round blue button, back icon"),
    ("ui_quit", "a simple red power button symbol circle with a vertical line on top, power off icon"),
    ("ui_trash", "a simple green trash bin with lid and handle, delete icon"),
    ("ui_sound", "a simple orange loudspeaker with three sound waves, volume icon"),
    ("ui_plus", "a simple green circle with a white thick plus sign, add icon"),
    ("ui_lock", "a simple golden padlock with keyhole, locked icon"),
    ("ui_arrow_right", "a simple white right-pointing arrow on a round green button, next icon"),
    ("ui_bell", "a simple red notification bell with a small clapper, alert icon"),
    ("ui_chart", "a simple orange rising bar chart with three bars, statistics icon"),
    ("ui_clock", "a simple yellow round wall clock with two hands, time icon"),
    ("ui_flag", "a simple green checkered racing flag on a pole, goal icon"),
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


def run_one(jid, subject, prefix="courier_sim"):
    g = json.load(open(WF, encoding="utf-8"))
    g["5"]["inputs"]["text"] = subject + STYLE
    g["18"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, jid)
    g["7"]["inputs"]["seed"] = (uuid.uuid4().int >> 16) % (2 ** 32)
    pid = _post({"prompt": g, "client_id": "courier_sim_v2"})["prompt_id"]
    out = _wait(pid)
    target = os.path.join(IMG_DIR, jid + ".png")
    ok = _copy_out(out.get("outputs", {}).get("18", {}), target)
    return ok, target


def main():
    limit = len(UI_JOBS_V2)
    dry = False
    args = sys.argv[1:]
    for a in args:
        if a.startswith("--limit"):
            limit = int(a.split("=")[1] if "=" in a else args[args.index(a) + 1])
        elif a == "--dry":
            dry = True
    os.makedirs(IMG_DIR, exist_ok=True)
    jobs = UI_JOBS_V2[:limit]
    print("TOTAL JOBS: %d (dry=%s)" % (len(jobs), dry))
    done = 0
    for jid, subject in jobs:
        if os.path.exists(os.path.join(IMG_DIR, jid + ".png")):
            print("[SKIP] %s already exists" % jid)
            done += 1
            continue
        if dry:
            print("[DRY] %s : %s" % (jid, subject))
            continue
        t0 = time.time()
        try:
            ok, target = run_one(jid, subject)
            dt = int(time.time() - t0)
            print("[%s] %s -> %s (%ds)" % ("OK" if ok else "NO-FILE", jid, target, dt))
            done += 1 if ok else 0
        except Exception as e:
            print("[FAIL] %s : %s" % (jid, e))
    print("DONE: %d/%d successful" % (done, len(jobs)))


if __name__ == "__main__":
    main()
