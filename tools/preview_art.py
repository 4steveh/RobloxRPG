#!/usr/bin/env python3
"""DEV TOOL — offline preview renderer for Wild World's procedural art layer.

Why this exists: the art layer is PURE, so the exact part list the Roblox engine will build can be
produced headlessly (tools/dump_art.luau). That means silhouette and palette work does not have to
wait on a Studio session, which is the loop that has historically blocked this project.

What it is NOT: a substitute for a Studio playtest. There is no Roblox lighting model here, no
Atmosphere, no shadows, no terrain, no post-processing. It answers exactly one question —
"does this geometry read as the thing it is meant to be" — and nothing about how it will feel in game.

KNOWN LIMITATION — it reports FALSE defects on adjacent or coplanar surfaces. Faces are drawn with a
painter's algorithm sorted by centroid depth, which mis-orders geometry that meets at a shared plane. It
showed the Lodge's gable courses punching through the roof as a staircase; a raycast grid over the
built model in Studio proved the gable never rises above the slope at any point. So: trust this tool for
SILHOUETTE and PALETTE, and go to Studio for anything where two surfaces meet.

Usage:
    luau tools/dump_art.luau > /tmp/art.json
    python3 tools/preview_art.py /tmp/art.json out_dir
"""

import json
import math
import sys
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Light comes from the upper left and slightly front — the same direction the reference template's
# 14:00 sun does, so relative face values read comparably.
LIGHT = np.array([-0.45, 0.82, -0.35])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
AMBIENT = 0.42
DIFFUSE = 0.58
SKY_TOP = (150, 178, 205)
SKY_BOT = (206, 214, 214)
CYL_SIDES = 12


def box_faces(half):
    """Unit box faces as (vertex indices, outward normal) over the 8 corners."""
    hx, hy, hz = half
    v = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
        (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz),
    ]
    faces = [
        ([4, 5, 6, 7], (0, 1, 0)),    # top
        ([0, 3, 2, 1], (0, -1, 0)),   # bottom
        ([0, 1, 5, 4], (0, 0, -1)),   # -Z
        ([2, 3, 7, 6], (0, 0, 1)),    # +Z
        ([1, 2, 6, 5], (1, 0, 0)),    # +X
        ([3, 0, 4, 7], (-1, 0, 0)),   # -X
    ]
    return v, faces


def wedge_faces(half):
    """A WedgePart: ZERO height at local -Z, FULL height at local +Z.

    This is measured, not assumed — probed live in Studio with a raycast grid across a 4x8x12 wedge.
    The first version of this function had it backwards, which meant the offline preview agreed with a
    generator that was ALSO backwards, and the broken roof only showed up in Studio.
    """
    hx, hy, hz = half
    v = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),  # 0-3 base
        (-hx, hy, hz), (hx, hy, hz),                                      # 4-5 top edge, at +Z
    ]
    slope_n = np.array([0.0, hz, -hy])
    slope_n = slope_n / np.linalg.norm(slope_n)
    faces = [
        ([0, 3, 2, 1], (0, -1, 0)),        # bottom
        ([3, 2, 5, 4], (0, 0, 1)),         # vertical face at +Z
        ([0, 1, 5, 4], tuple(slope_n)),    # the slope, rising from -Z to +Z
        ([1, 2, 5], (1, 0, 0)),            # +X triangle
        ([3, 0, 4], (-1, 0, 0)),           # -X triangle
    ]
    return v, faces


def cylinder_faces(half, sides=CYL_SIDES):
    """Length along local X (matching the project's cylinder-axis convention)."""
    hx, hy, hz = half
    v = []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        v.append((-hx, math.sin(a) * hy, math.cos(a) * hz))
    for i in range(sides):
        a = 2 * math.pi * i / sides
        v.append((hx, math.sin(a) * hy, math.cos(a) * hz))
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        a = 2 * math.pi * (i + 0.5) / sides
        faces.append(([i, j, sides + j, sides + i], (0.0, math.sin(a), math.cos(a))))
    faces.append((list(range(sides - 1, -1, -1)), (-1, 0, 0)))
    faces.append((list(range(sides, 2 * sides)), (1, 0, 0)))
    return v, faces


def ball_faces(half, seg=8):
    """Low-res UV sphere; enough to read a rounded mass."""
    hx, hy, hz = half
    v, faces = [], []
    rings = seg
    for i in range(rings + 1):
        phi = math.pi * i / rings
        for j in range(seg):
            th = 2 * math.pi * j / seg
            v.append((math.sin(phi) * math.cos(th) * hx, math.cos(phi) * hy, math.sin(phi) * math.sin(th) * hz))
    for i in range(rings):
        for j in range(seg):
            a = i * seg + j
            b = i * seg + (j + 1) % seg
            c = (i + 1) * seg + (j + 1) % seg
            d = (i + 1) * seg + j
            nx = v[a][0] + v[b][0] + v[c][0] + v[d][0]
            ny = v[a][1] + v[b][1] + v[c][1] + v[d][1]
            nz = v[a][2] + v[b][2] + v[c][2] + v[d][2]
            n = np.array([nx, ny, nz])
            ln = np.linalg.norm(n)
            faces.append(([a, b, c, d], tuple(n / ln) if ln > 1e-9 else (0, 1, 0)))
    return v, faces


SHAPE_FN = {"block": box_faces, "wedge": wedge_faces, "cornerWedge": wedge_faces,
            "cylinder": cylinder_faces, "ball": ball_faces}


def collect(parts):
    """World-space polygons with shaded colours, ready for depth sorting."""
    polys = []
    for p in parts:
        half = (p["s"][0] / 2, p["s"][1] / 2, p["s"][2] / 2)
        r = np.array(p["r"]); u = np.array(p["u"]); f = np.array(p["f"])
        origin = np.array(p["p"])
        basis = np.stack([r, u, f], axis=1)  # local -> world
        verts, faces = SHAPE_FN.get(p["sh"], box_faces)(half)
        world = [origin + basis @ np.array(v) for v in verts]
        base = np.array(p["c"], dtype=float)
        alpha = 1.0 - float(p.get("t", 0.0))
        for idx, n_local in faces:
            n = basis @ np.array(n_local, dtype=float)
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            lam = max(0.0, float(np.dot(n, LIGHT)))
            shade = AMBIENT + DIFFUSE * lam
            col = np.clip(base * shade, 0, 255)
            polys.append(([world[i] for i in idx], col, alpha))
    return polys


def render(parts, size=(900, 700), yaw=0.62, pitch=0.30, label=""):
    if not parts:
        return Image.new("RGB", size, SKY_BOT)
    pts = np.array([p["p"] for p in parts])
    ext = np.array([p["s"] for p in parts])
    lo = (pts - ext / 2).min(axis=0)
    hi = (pts + ext / 2).max(axis=0)
    centre = (lo + hi) / 2
    radius = max(float(np.linalg.norm(hi - lo)) / 2, 1.0)

    # orbit camera framing the subject
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    fwd = np.array([sy * cp, -sp, cy * cp])
    eye = centre - fwd * (radius * 2.7)
    eye[1] = centre[1] + radius * 0.85
    fwd = centre - eye
    fwd = fwd / np.linalg.norm(fwd)
    right = np.cross(np.array([0.0, 1.0, 0.0]), fwd)
    right = right / np.linalg.norm(right)
    up = np.cross(fwd, right)

    W, H = size
    focal = W * 0.85

    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(H):
        t = y / max(H - 1, 1)
        d.line([(0, y), (W, y)], fill=tuple(int(SKY_TOP[i] + (SKY_BOT[i] - SKY_TOP[i]) * t) for i in range(3)))

    def project(v):
        rel = v - eye
        z = float(np.dot(rel, fwd))
        if z <= 0.05:
            return None
        x = float(np.dot(rel, right)) * focal / z + W / 2
        y = -float(np.dot(rel, up)) * focal / z + H / 2
        return (x, y, z)

    # ground plane for scale reference
    gy = lo[1]
    grid = []
    step = max(radius / 4, 1.0)
    for gx in np.arange(centre[0] - radius * 2, centre[0] + radius * 2 + step, step):
        grid.append((np.array([gx, gy, centre[2] - radius * 2]), np.array([gx, gy, centre[2] + radius * 2])))
    for gz in np.arange(centre[2] - radius * 2, centre[2] + radius * 2 + step, step):
        grid.append((np.array([centre[0] - radius * 2, gy, gz]), np.array([centre[0] + radius * 2, gy, gz])))
    for a, b in grid:
        pa, pb = project(a), project(b)
        if pa and pb:
            d.line([pa[:2], pb[:2]], fill=(168, 176, 168, 90), width=1)

    polys = collect(parts)
    drawn = []
    for verts, col, alpha in polys:
        proj = [project(v) for v in verts]
        if any(p is None for p in proj):
            continue
        depth = sum(p[2] for p in proj) / len(proj)
        drawn.append((depth, [p[:2] for p in proj], col, alpha))
    drawn.sort(key=lambda t: -t[0])
    for _, pts2, col, alpha in drawn:
        fill = (int(col[0]), int(col[1]), int(col[2]), int(255 * alpha))
        d.polygon(pts2, fill=fill)

    if label:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 17)
        except Exception:
            font = ImageFont.load_default()
        d.rectangle([0, 0, W, 26], fill=(20, 24, 28, 190))
        d.text((8, 4), f"{label}   ({len(parts)} parts)", fill=(238, 240, 236), font=font)
    return img


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/art.json"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/art_preview"
    os.makedirs(out, exist_ok=True)
    data = json.load(open(src))
    subjects = data["subjects"]

    thumbs = []
    for s in subjects:
        img = render(s["parts"], size=(760, 600), label=s["label"])
        name = s["label"].replace(":", "_")
        img.save(os.path.join(out, f"{name}.png"))
        thumbs.append((s["label"], img))
        print(f"  {s['label']:44s} {len(s['parts']):5d} parts")

    # contact sheet
    cols = 4
    tw, th = 380, 300
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * th), (24, 26, 28))
    for i, (_, img) in enumerate(thumbs):
        sheet.paste(img.resize((tw, th)), ((i % cols) * tw, (i // cols) * th))
    sheet.save(os.path.join(out, "_contact_sheet.png"))
    print(f"\nwrote {len(thumbs)} renders + _contact_sheet.png to {out}")


if __name__ == "__main__":
    main()
