#!/usr/bin/env python3
"""PR0 — compare a Dart DevTools performance export against Kerosene DoD.

Usage:
  python3 tool/analyze_devtools_performance.py path/to/dart_devtools_....json
  python3 tool/analyze_devtools_performance.py a.json b.json   # side-by-side

Exit code 0 if all soft targets pass; 1 if any fail (still prints full report).
"""

from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path


def pct(sorted_vals: list[float], p: float) -> float:
    if not sorted_vals:
        return 0.0
    i = min(len(sorted_vals) - 1, max(0, int(len(sorted_vals) * p)))
    return sorted_vals[i]


def analyze(path: Path) -> dict:
    with path.open() as f:
        data = json.load(f)

    app = data.get("connectedApp") or {}
    frames = data["performance"]["flutterFrames"]
    if not frames:
        raise SystemExit(f"{path}: no flutterFrames")

    build = [f["build"] / 1000 for f in frames]
    raster = [f["raster"] / 1000 for f in frames]
    elapsed = [f["elapsed"] / 1000 for f in frames]
    starts = [f["startTime"] for f in frames]
    wall_s = (starts[-1] - starts[0]) / 1e6
    naive_fps = (len(frames) - 1) / wall_s if wall_s > 0 else 0

    rb = sum(1 for f in frames if f["raster"] > f["build"] and f["raster"] > 8000)
    bb = sum(1 for f in frames if f["build"] > f["raster"] and f["build"] > 8000)

    tb = b""
    raw = data["performance"].get("traceBinary")
    if isinstance(raw, list):
        tb = bytes(raw)

    paint_n = max(1, tb.count(b"LayerTree::Paint") or tb.count(b"GPURasterizer::Draw") or 1)
    save_layers = tb.count(b"Canvas::saveLayer")
    scene_lag = tb.count(b"SceneDisplayLag")
    pipeline_full = tb.count(b"PipelineFull")

    r_sorted = sorted(raster)
    e_sorted = sorted(elapsed)
    b_sorted = sorted(build)

    return {
        "path": str(path),
        "app": app,
        "n_frames": len(frames),
        "wall_s": wall_s,
        "naive_fps": naive_fps,
        "build_p50": statistics.median(build),
        "build_p90": pct(b_sorted, 0.9),
        "raster_p50": statistics.median(raster),
        "raster_p90": pct(r_sorted, 0.9),
        "raster_avg": statistics.mean(raster),
        "elapsed_p50": statistics.median(elapsed),
        "elapsed_gt_16_7_pct": 100 * sum(1 for x in elapsed if x > 16.67) / len(elapsed),
        "raster_gt_16_7_pct": 100 * sum(1 for x in raster if x > 16.67) / len(raster),
        "raster_bound": rb,
        "build_bound": bb,
        "save_layer": save_layers,
        "save_layer_per_paint": save_layers / paint_n,
        "scene_display_lag": scene_lag,
        "scene_lag_per_frame_pct": 100 * scene_lag / len(frames),
        "pipeline_full": pipeline_full,
    }


# Soft targets from plan DoD (profile multi-tela / home)
TARGETS = [
    ("raster_p50", "<=", 10.0, "ms"),
    ("raster_p90", "<=", 14.0, "ms"),
    ("elapsed_gt_16_7_pct", "<=", 25.0, "%"),
    ("save_layer_per_paint", "<=", 1.0, "/paint"),
    ("scene_lag_per_frame_pct", "<=", 5.0, "%"),
]


def evaluate(m: dict) -> list[tuple[str, bool, str]]:
    rows = []
    for key, op, limit, unit in TARGETS:
        val = m[key]
        ok = val <= limit if op == "<=" else val >= limit
        rows.append((key, ok, f"{val:.2f}{unit}  (target {op} {limit}{unit})"))
    return rows


def print_report(m: dict) -> bool:
    print(f"\n=== {m['path']} ===")
    app = m["app"]
    print(
        f"Flutter {app.get('flutterVersion')}  "
        f"profile={app.get('isProfileBuild')}  os={app.get('operatingSystem')}"
    )
    print(
        f"frames={m['n_frames']}  wall={m['wall_s']:.1f}s  "
        f"naiveFPS={m['naive_fps']:.1f}"
    )
    print(
        f"build  p50={m['build_p50']:.2f}ms  p90={m['build_p90']:.2f}ms"
    )
    print(
        f"raster p50={m['raster_p50']:.2f}ms  p90={m['raster_p90']:.2f}ms  "
        f"avg={m['raster_avg']:.2f}ms  >16.7ms={m['raster_gt_16_7_pct']:.1f}%"
    )
    print(
        f"elapsed p50={m['elapsed_p50']:.2f}ms  "
        f">16.7ms={m['elapsed_gt_16_7_pct']:.1f}%"
    )
    print(
        f"bottleneck >8ms: raster={m['raster_bound']}  build={m['build_bound']}"
    )
    print(
        f"saveLayer={m['save_layer']}  "
        f"per_paint≈{m['save_layer_per_paint']:.2f}  "
        f"SceneDisplayLag={m['scene_display_lag']} "
        f"({m['scene_lag_per_frame_pct']:.1f}% frames)  "
        f"PipelineFull={m['pipeline_full']}"
    )
    print("--- DoD ---")
    all_ok = True
    for key, ok, detail in evaluate(m):
        mark = "PASS" if ok else "FAIL"
        if not ok:
            all_ok = False
        print(f"  [{mark}] {key}: {detail}")
    return all_ok


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    paths = [Path(a) for a in argv[1:]]
    ok_all = True
    metrics = []
    for p in paths:
        if not p.is_file():
            print(f"missing: {p}", file=sys.stderr)
            return 2
        m = analyze(p)
        metrics.append(m)
        if not print_report(m):
            ok_all = False

    if len(metrics) == 2:
        a, b = metrics
        print("\n=== Delta (B - A) ===")
        for key in (
            "raster_p50",
            "raster_p90",
            "elapsed_gt_16_7_pct",
            "save_layer_per_paint",
            "scene_lag_per_frame_pct",
            "naive_fps",
        ):
            da = b[key] - a[key]
            print(f"  {key}: {da:+.2f}")

    return 0 if ok_all else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
