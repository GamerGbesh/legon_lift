#!/usr/bin/env python3
"""Download every exercise image listed in assets/data/exercises.json and store a
compressed copy at the path given in each exercise's `localImages`.

  python3 -I tool/fetch_images.py [--force] [--width 560] [--quality 70]

Images come from yuhonas/free-exercise-db (Unlicense). Downloads land in a fresh
temporary directory and are only ever read by ImageMagick (`magick`), which
re-encodes them as baseline JPEG (resized, metadata stripped) into assets/exercises/.
Needs network once; after that the app is fully offline.
"""
import argparse
import concurrent.futures as cf
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EX_JSON = os.path.join(ROOT, "assets", "data", "exercises.json")
ALLOWED_PREFIX = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"


def fetch(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "legon-lift-asset-fetch"})
    with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)
    with open(dest, "rb") as f:
        if f.read(3) != b"\xff\xd8\xff":
            raise ValueError(f"not a JPEG: {url}")


def convert(src, dst, width, quality):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["magick", src, "-resize", f"{width}x{width}>", "-strip", "-interlace", "none",
                    "-sampling-factor", "4:2:0", "-quality", str(quality), dst], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--width", type=int, default=560)
    ap.add_argument("--quality", type=int, default=70)
    args = ap.parse_args()
    if not shutil.which("magick"):
        sys.exit("ImageMagick 7 ('magick') is required")
    with open(EX_JSON, encoding="utf-8") as f:
        exercises = json.load(f)
    jobs = []
    for e in exercises:
        for url, local in zip(e["images"], e["localImages"]):
            if not url.startswith(ALLOWED_PREFIX):
                sys.exit(f"{e['id']}: unexpected image host {url}")
            dst = os.path.join(ROOT, local)
            if args.force or not os.path.exists(dst):
                jobs.append((url, dst))
    tmp = tempfile.mkdtemp(prefix="legon_img_")
    try:
        def work(job):
            url, dst = job
            raw = os.path.join(tmp, os.path.basename(dst) + ".src")
            fetch(url, raw)
            convert(raw, dst, args.width, args.quality)
            return dst
        failures = []
        with cf.ThreadPoolExecutor(max_workers=8) as pool:
            futs = {pool.submit(work, j): j for j in jobs}
            for fut in cf.as_completed(futs):
                try:
                    fut.result()
                except Exception as exc:  # noqa: BLE001
                    failures.append((futs[fut][0], str(exc)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    total = 0
    count = 0
    for e in exercises:
        for local in e["localImages"]:
            p = os.path.join(ROOT, local)
            if os.path.exists(p):
                total += os.path.getsize(p)
                count += 1
    print(f"downloaded {len(jobs) - len(failures)} new, {count} images on disk, {total / 1e6:.2f} MB total")
    for url, err in failures:
        print("FAILED", url, err)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
