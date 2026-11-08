#!/usr/bin/env python3
"""Generate deterministic, tileable PBR maps for the player character.

The maps are authored from procedural noise and scratch patterns so the
character has no external texture or image license dependency.
"""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


MATERIALS = {
    "skin": ((150, 102, 79), 0.74, "soft"),
    "leather": ((62, 37, 27), 0.80, "grain"),
    "steel": ((112, 116, 115), 0.34, "brush"),
    "iron": ((39, 42, 44), 0.55, "brush"),
    "bronze": ((132, 77, 39), 0.57, "grain"),
    "cloth": ((117, 101, 82), 0.93, "weave"),
    "linen": ((181, 164, 137), 0.91, "weave"),
    "crimson": ((67, 22, 25), 0.88, "weave"),
    "hair": ((35, 24, 20), 0.72, "strand"),
}
ROOT = Path(__file__).resolve().parents[1]


def periodic_field(size: int, seed: int, detail: float = 1.0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    axis = np.linspace(0.0, 1.0, size, endpoint=False, dtype=np.float32)
    x, y = np.meshgrid(axis, axis)
    field = np.zeros((size, size), dtype=np.float32)
    for octave, frequency in enumerate((2, 4, 8, 16, 32, 64, 128)):
        phase_a, phase_b, phase_c = rng.random(3) * math.tau
        weight = (0.52 ** octave) * detail
        wave = (
            np.sin(math.tau * frequency * x + phase_a)
            * np.cos(math.tau * (frequency + 1) * y + phase_b)
            + 0.55 * np.sin(math.tau * (frequency // 2 + 1) * (x + y) + phase_c)
        )
        field += wave.astype(np.float32) * weight
    field -= field.mean()
    field /= max(float(field.std()) * 2.6, 1e-4)
    return np.clip(field, -1.0, 1.0)


def make_maps(name: str, base: tuple[int, int, int], rough: float, pattern: str, size: int, out: Path) -> None:
    seed = sum((i + 1) * ord(ch) for i, ch in enumerate(name)) + 19
    noise = periodic_field(size, seed)
    fine = periodic_field(size, seed + 91, 0.44)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    u = xx / size
    v = yy / size

    if pattern == "weave":
        grain = 0.13 * np.sin(math.tau * (u * 74 + 0.12 * np.sin(math.tau * v * 6)))
        grain += 0.11 * np.sin(math.tau * (v * 64 + 0.10 * np.sin(math.tau * u * 8)))
        grain += 0.07 * np.sin(math.tau * (u * 148 + v * 2.0))
    elif pattern == "brush":
        grain = 0.26 * np.sin(math.tau * (v * 96 + 0.07 * np.sin(math.tau * u * 5)))
        grain += 0.08 * np.sin(math.tau * (v * 192 + u * 3.0))
    elif pattern == "strand":
        grain = 0.28 * np.sin(math.tau * (v * 84 + 0.16 * np.sin(math.tau * u * 9)))
        grain += 0.11 * np.sin(math.tau * (v * 168 + u * 2.0))
    elif pattern == "grain":
        grain = 0.24 * np.sin(math.tau * (u * 42 + 0.10 * np.sin(math.tau * v * 5)))
        grain += 0.18 * np.cos(math.tau * (v * 46 + 0.08 * np.sin(math.tau * u * 4)))
    else:
        grain = 0.11 * np.sin(math.tau * u * 18) * np.cos(math.tau * v * 15)

    height = np.clip(0.42 * noise + 0.30 * fine + grain * 0.42, -1.0, 1.0)
    weather = np.clip(0.47 * noise + 0.24 * fine + grain * 0.25, -1.0, 1.0)
    color = np.zeros((size, size, 3), dtype=np.float32)
    for channel, component in enumerate(base):
        color[:, :, channel] = component * (1.0 + 0.105 * weather) + 8.0 * grain

    # Irregular edge wear: narrow diagonal cuts in metal and leather, and
    # small mottled abrasions in the cloth maps. Placement is deterministic.
    img = Image.fromarray(np.uint8(np.clip(color, 0, 255)), "RGB")
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed + 401)
    scratch_count = size // (36 if pattern in ("brush", "strand") else 42)
    for _ in range(scratch_count):
        length = int(rng.integers(max(4, size // 100), max(8, size // 24)))
        x0 = int(rng.integers(2, max(3, size - length - 2)))
        y0 = int(rng.integers(2, max(3, size - length - 2)))
        drift = int(rng.integers(-4, 5))
        x1 = x0 + drift + length
        y1 = y0 + length
        shade = int(rng.integers(12, 34))
        if rng.random() < 0.20:
            color_line = (min(255, base[0] + shade), min(255, base[1] + shade), min(255, base[2] + shade))
        else:
            color_line = (max(0, base[0] - shade), max(0, base[1] - shade), max(0, base[2] - shade))
        draw.line((x0, y0, x1, y1), fill=color_line, width=1 if size < 768 else 2)

    albedo_path = out / f"{name}_albedo.jpg"
    albedo_tmp = out / f".{name}_albedo.tmp.jpg"
    img.save(albedo_tmp, format="JPEG", quality=89, optimize=True, progressive=True)
    os.replace(albedo_tmp, albedo_path)

    dy, dx = np.gradient(height)
    nx = -dx * 3.8
    ny = -dy * 3.8
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack((nx / length, ny / length, nz / length), axis=-1)
    normal = np.uint8(np.clip((normal * 0.5 + 0.5) * 255.0, 0, 255))
    normal_path = out / f"{name}_normal.png"
    normal_tmp = out / f".{name}_normal.tmp.png"
    Image.fromarray(normal, "RGB").save(normal_tmp, format="PNG", optimize=True)
    with Image.open(normal_tmp) as check:
        check.verify()
    os.replace(normal_tmp, normal_path)

    roughness = np.uint8(np.clip((rough + 0.13 * noise + 0.05 * fine) * 255.0, 0, 255))
    rough_path = out / f"{name}_roughness.png"
    rough_tmp = out / f".{name}_roughness.tmp.png"
    Image.fromarray(roughness, "L").save(rough_tmp, format="PNG", optimize=True)
    with Image.open(rough_tmp) as check:
        check.verify()
    os.replace(rough_tmp, rough_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "art/characters/thornbound/textures/procedural")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for index, (name, (base, rough, pattern)) in enumerate(MATERIALS.items()):
        size = 1024 if name in {"skin", "hair", "linen"} else 512
        make_maps(name, base, rough, pattern, size, args.out)
        print(f"generated {name}: {size}x{size}")
    for stale in list(args.out.glob(".*.tmp.png")) + list(args.out.glob(".*.tmp.jpg")):
        stale.unlink()


if __name__ == "__main__":
    main()
