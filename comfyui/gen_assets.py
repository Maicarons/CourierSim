#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CourierSim asset generator.

Drives the local ComfyUI server (http://127.0.0.1:8188) to batch-generate
game assets using the workflows shipped in this folder:

  - graph_final.json        -> pixel-art images  (Ernie Image Turbo + BiRefNet)
  - sfx_generation.json      -> short SFX         (Stable Audio 3 small sfx)
  - audio_generation.json    -> BGM / music       (Stable Audio 3 small music)

Outputs are copied into  G:/GitHub/CourierSim/assets/{images,audio}/.

Usage:
  python gen_assets.py --test            # 2-job feasibility check
  python gen_assets.py --kinds image     # all images
  python gen_assets.py --kinds audio     # all audio
  python gen_assets.py                   # everything
  python gen_assets.py --limit 3         # first N jobs of each kind
  python gen_assets.py --title-bg        # generate 1920x1080 title background
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
import shutil
import uuid

COMFY = "http://127.0.0.1:8188"
COMFY_OUTPUT = r"G:/ComfyUI-aki-v2/ComfyUI/output"
PROJECT = r"G:/GitHub/CourierSim"
WF_DIR = os.path.join(PROJECT, "comfyui")
IMG_DIR = os.path.join(PROJECT, "assets", "images")
AUD_DIR = os.path.join(PROJECT, "assets", "audio")

STYLE = (", 2D pixel art, Nintendo 8-bit game asset, bold black outline, "
         "flat colors, minimal shading, simple, isolated on white background")

TITLE_BG_PROMPT = ("A cheerful 2D pixel art cityscape for a delivery company game title screen, "
                   "isometric neighborhoods, cute blue delivery vans on the road, small hubs and stations, "
                   "warm sunset sky with soft clouds, wide panorama, Nintendo 8-bit inspired, "
                   "bold shapes, flat colors, minimal shading, 1920x1080, dreamy and inviting mood")

# ---------------------------------------------------------------------------
# Image manifest  (id, subject prompt)
# ---------------------------------------------------------------------------
IMAGE_JOBS = [
    ("veh_van", "a small electric delivery van, white and blue, side view, two round headlights, boxy cargo body"),
    ("veh_truck", "a delivery box truck, side view, large cargo container, rolling shutter door, blue and white"),
    ("veh_refrigerated", "a refrigerated delivery truck with a snowflake emblem on the side, cold-chain, blue and white, side view"),
    ("veh_drone", "a delivery drone quadcopter carrying a small parcel underneath, front view"),
    ("veh_plane", "a cargo airplane, side view, with a shipping logo on the tail fin"),
    ("veh_ship", "a cargo container ship, side view, stacked colorful containers on deck"),
    ("bld_hq", "a modern company headquarters office tower, with a delivery logo on top, front view"),
    ("bld_hub", "a logistics distribution center warehouse, big rolling shutter doors, loading dock, front view"),
    ("bld_station", "a small neighborhood pickup station booth, storefront with striped awning and a parcel locker, front view"),
    ("char_courier", "a friendly delivery courier character, wearing a cap and uniform, holding a parcel, cartoon mascot, front view"),
    ("cargo_standard", "a cardboard shipping parcel box tied with tape, brown, front view"),
    ("cargo_coldchain", "a blue insulated cold-chain shipping box with a snowflake symbol, front view"),
    ("cargo_pharma", "a white medical supply box with a green cross symbol, front view"),
    ("cargo_hazmat", "an orange hazard material crate with a warning triangle symbol, front view"),
    ("cargo_international", "a wooden shipping crate with a globe emblem, front view"),
    ("logo", "a round game logo badge, a smiling delivery package with small wings, blue and white"),
]

# ---------------------------------------------------------------------------
# Audio manifest  (id, kind, seconds, raw SA3 prompt)
# kind: "music" -> audio_generation.json (stable_audio_3_small_music)
#       "sfx"   -> sfx_generation.json   (stable_audio_3_small_sfx)
# ---------------------------------------------------------------------------
AUDIO_JOBS = [
    ("bgm_menu", "music", 32,
     "Cheerful chiptune town theme, bouncy square-wave melody, light drums, friendly logistics company vibe, looping, upbeat. BPM: 120. Length: 32 seconds"),
    ("bgm_play", "music", 36,
     "Upbeat instrumental logistics work track, energetic plucky synth melody, steady four-on-the-floor beat, positive productive mood, looping. BPM: 128. Length: 36 seconds"),
    ("sfx_ui_click", "sfx", 1,
     "UI button click, short soft digital tick, clean, 1 second"),
    ("sfx_delivery_done", "sfx", 2,
     "Pleasant two-note doorbell ding-dong, package delivered confirmation, bright, 2 seconds"),
    ("sfx_new_order", "sfx", 2,
     "Notification chime, rising three-note arpeggio, friendly alert, 2 seconds"),
    ("sfx_cash", "sfx", 1,
     "Cash register ka-ching with a small coin jingle, 1 second"),
    ("sfx_error", "sfx", 1,
     "Short low error buzzer, digital UI warning, 1 second"),
    ("sfx_tech_unlock", "sfx", 2,
     "Bright rewarding level-up chime with a sparkle, fantasy RPG style, 2 seconds"),
    ("sfx_objective_done", "sfx", 2,
     "Short success fanfare, triumphant sting, 2 seconds"),
    ("sfx_game_over", "sfx", 2,
     "Descending sad trombone fail sound, game over, 2 seconds"),
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


def _wait(prompt_id, timeout=420):
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
    raise TimeoutError("prompt %s did not finish in %ss" % (prompt_id, timeout))


def _copy_out(node_outputs, target):
    """Copy a saved file from ComfyUI output into the project assets dir."""
    for kind in ("images", "audio"):
        items = node_outputs.get(kind)
        if not items:
            continue
        for it in items:
            sub = it.get("subfolder", "")
            fname = it.get("filename")
            src = os.path.join(COMFY_OUTPUT, sub, fname) if sub else os.path.join(COMFY_OUTPUT, fname)
            if not os.path.exists(src):
                # try with subfolder always
                src = os.path.join(COMFY_OUTPUT, sub or "", fname)
            shutil.copy(src, target)
            return True
    return False


def run_image(job, prefix="courier_sim"):
    jid, subject = job
    g = json.load(open(os.path.join(WF_DIR, "graph_final.json")))
    g["5"]["inputs"]["text"] = subject + STYLE
    g["18"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, jid)
    g["7"]["inputs"]["seed"] = (uuid.uuid4().int >> 16) % (2**32)
    pid = _post({"prompt": g, "client_id": "courier_sim"})["prompt_id"]
    out = _wait(pid)
    target = os.path.join(IMG_DIR, jid + ".png")
    ok = _copy_out(out.get("outputs", {}).get("18", {}), target)
    return ok, target


def run_audio(job, prefix="courier_sim"):
    jid, kind, seconds, prompt = job
    wf = "audio_generation.json" if kind == "music" else "sfx_generation.json"
    g = json.load(open(os.path.join(WF_DIR, wf)))
    # checkpoint
    ckpt = "stable_audio_3_small_music.safetensors" if kind == "music" else "stable_audio_3_small_sfx.safetensors"
    g["52:25"]["inputs"]["ckpt_name"] = ckpt
    # bypass LLM: use raw prompt directly
    g["52:35"]["inputs"]["value"] = False
    g["52:31"]["inputs"]["value"] = prompt
    g["52:36"]["inputs"]["value"] = float(seconds)
    g["19"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, jid)
    pid = _post({"prompt": g, "client_id": "courier_sim"})["prompt_id"]
    out = _wait(pid)
    target = os.path.join(AUD_DIR, jid + ".mp3")
    ok = _copy_out(out.get("outputs", {}).get("19", {}), target)
    return ok, target


def run_title_bg(prefix="courier_sim"):
    g = json.load(open(os.path.join(WF_DIR, "title_bg.json")))
    g["88:94"]["inputs"]["value"] = TITLE_BG_PROMPT
    g["88:70"]["inputs"]["seed"] = (uuid.uuid4().int >> 16) % (2**32)
    g["73"]["inputs"]["filename_prefix"] = "%s/%s" % (prefix, "title_bg")
    pid = _post({"prompt": g, "client_id": "courier_sim"})["prompt_id"]
    out = _wait(pid, timeout=600)
    target = os.path.join(IMG_DIR, "title_bg.png")
    ok = _copy_out(out.get("outputs", {}).get("73", {}), target)
    return ok, target


def main():
    args = sys.argv[1:]
    if "--title-bg" in args:
        os.makedirs(IMG_DIR, exist_ok=True)
        try:
            ok, target = run_title_bg()
            print("[OK] title_bg -> %s" % target if ok else "[NO-FILE] title_bg")
        except Exception as e:
            print("[FAIL] title_bg : %s" % e)
        return

    kinds = []
    limit = None
    test = "--test" in args
    if "--kinds" in args:
        i = args.index("--kinds")
        kinds = args[i + 1].split(",")
    if "--limit" in args:
        i = args.index("--limit")
        limit = int(args[i + 1])

    os.makedirs(IMG_DIR, exist_ok=True)
    os.makedirs(AUD_DIR, exist_ok=True)

    jobs = []
    if test:
        jobs = [("image", IMAGE_JOBS[0]), ("audio", AUDIO_JOBS[2])]
    else:
        if not kinds or "image" in kinds:
            for j in IMAGE_JOBS[:limit]:
                jobs.append(("image", j))
        if not kinds or "audio" in kinds:
            for j in AUDIO_JOBS[:limit]:
                jobs.append(("audio", j))

    print("TOTAL JOBS: %d" % len(jobs))
    done = 0
    for kind, job in jobs:
        t0 = time.time()
        try:
            if kind == "image":
                ok, target = run_image(job)
            else:
                ok, target = run_audio(job)
            dt = int(time.time() - t0)
            status = "OK" if ok else "NO-FILE"
            print("[%s] %s -> %s (%ds) %s" % (status, job[0], target, dt, "" if ok else "!!"))
            done += 1 if ok else 0
        except Exception as e:
            print("[FAIL] %s : %s" % (job[0], e))
    print("DONE: %d/%d successful" % (done, len(jobs)))


if __name__ == "__main__":
    main()
