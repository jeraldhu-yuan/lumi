#!/usr/bin/env python3
import json
import sys
from collections import deque
from pathlib import Path

import cv2
import numpy as np


DEFAULT_SOURCE = Path("~/Downloads/codex-sprite-sheet-source.png").expanduser()
SOURCE = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_SOURCE
OUT_DIR = Path(__file__).resolve().parents[1] / "Assets" / "ChibiAssistant"
OUT_SHEET = OUT_DIR / "sprite-sheet.png"
OUT_DEBUG = OUT_DIR / "sprite-sheet-debug.png"
OUT_PREVIEW = OUT_DIR / "sprite-sheet-preview.png"
OUT_METADATA = OUT_DIR / "sprite-sheet.json"

COLS = 4
ROWS = 4
FRAME = 256
PADDING = 16


ANIMATIONS = {
    "idle": [0, 1],
    "happy": [2, 11],
    "listening": [3],
    "thinking": [4],
    "working": [6, 10],
    "active": [7, 8],
    "sitting": [9],
    "error": [13],
    "calm": [14],
    "sleep": [15],
}


def background_candidate(rgb: np.ndarray) -> np.ndarray:
    # White/off-white paper background is low-saturation and very bright.
    rgb_i = rgb.astype(np.int16)
    max_channel = rgb_i.max(axis=2)
    min_channel = rgb_i.min(axis=2)
    return (min_channel >= 236) & ((max_channel - min_channel) <= 18)


def flood_border_background(candidate: np.ndarray) -> np.ndarray:
    h, w = candidate.shape
    visited = np.zeros((h, w), dtype=bool)
    queue = deque()

    def push(y: int, x: int) -> None:
        if 0 <= y < h and 0 <= x < w and candidate[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((y, x))

    for x in range(w):
        push(0, x)
        push(h - 1, x)
    for y in range(h):
        push(y, 0)
        push(y, w - 1)

    while queue:
        y, x = queue.popleft()
        push(y - 1, x)
        push(y + 1, x)
        push(y, x - 1)
        push(y, x + 1)

    return visited


def bounds_for_alpha(alpha: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0 or len(ys) == 0:
        return 0, 0, alpha.shape[1], alpha.shape[0]
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def detected_edges(foreground: np.ndarray, axis: int, parts: int) -> list[int]:
    length = foreground.shape[1] if axis == 0 else foreground.shape[0]
    projection = foreground.sum(axis=axis)
    edges = [0]

    for split in range(1, parts):
        expected = round(length * split / parts)
        search_radius = max(48, round(length / parts * 0.28))
        start = max(edges[-1] + 24, expected - search_radius)
        end = min(length - 24, expected + search_radius)
        window = projection[start:end]
        zeroes = np.where(window == 0)[0]

        if len(zeroes) > 0:
            runs = []
            run_start = zeroes[0]
            previous = zeroes[0]
            for value in zeroes[1:]:
                if value == previous + 1:
                    previous = value
                else:
                    runs.append((run_start, previous))
                    run_start = value
                    previous = value
            runs.append((run_start, previous))
            best = max(runs, key=lambda item: item[1] - item[0])
            edge = start + (best[0] + best[1]) // 2
        else:
            edge = start + int(np.argmin(window))

        edges.append(int(edge))

    edges.append(length)
    return edges


def resize_to_fit(sprite: np.ndarray) -> np.ndarray:
    h, w = sprite.shape[:2]
    limit = FRAME - PADDING * 2
    scale = min(1.0, limit / max(w, h))
    if scale >= 1.0:
        return sprite

    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    return cv2.resize(sprite, (new_w, new_h), interpolation=cv2.INTER_NEAREST)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bgr = cv2.imread(str(SOURCE), cv2.IMREAD_COLOR)
    if bgr is None:
        raise SystemExit(f"Could not read {SOURCE}")

    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    source_h, source_w = rgb.shape[:2]

    source_i = rgb.astype(np.int16)
    max_channel = source_i.max(axis=2)
    min_channel = source_i.min(axis=2)
    foreground = ~((min_channel >= 236) & ((max_channel - min_channel) <= 18))

    x_edges = detected_edges(foreground, axis=0, parts=COLS)
    y_edges = detected_edges(foreground, axis=1, parts=ROWS)

    sheet = np.zeros((ROWS * FRAME, COLS * FRAME, 4), dtype=np.uint8)
    debug = np.zeros_like(sheet)
    frames = []

    for row in range(ROWS):
        for col in range(COLS):
            index = row * COLS + col
            x0, x1 = x_edges[col], x_edges[col + 1]
            y0, y1 = y_edges[row], y_edges[row + 1]
            cell = rgb[y0:y1, x0:x1]

            background = flood_border_background(background_candidate(cell))
            alpha = np.where(background, 0, 255).astype(np.uint8)

            # Trim isolated edge speckles while preserving the main sprite/effects.
            foreground = (alpha > 0).astype(np.uint8)
            count, labels, stats, _ = cv2.connectedComponentsWithStats(foreground, connectivity=8)
            keep = np.zeros_like(alpha)
            for component in range(1, count):
                area = stats[component, cv2.CC_STAT_AREA]
                if area >= 8:
                    keep[labels == component] = 255
            alpha = keep

            bx0, by0, bx1, by1 = bounds_for_alpha(alpha)
            bx0 = max(0, bx0 - 2)
            by0 = max(0, by0 - 2)
            bx1 = min(alpha.shape[1], bx1 + 2)
            by1 = min(alpha.shape[0], by1 + 2)

            sprite_rgb = cell[by0:by1, bx0:bx1]
            sprite_alpha = alpha[by0:by1, bx0:bx1]
            sprite = np.dstack([sprite_rgb, sprite_alpha])
            sprite = resize_to_fit(sprite)

            sh, sw = sprite.shape[:2]
            dest_x = col * FRAME + (FRAME - sw) // 2
            dest_y = row * FRAME + (FRAME - sh) // 2
            sheet[dest_y:dest_y + sh, dest_x:dest_x + sw] = sprite

            frames.append({
                "index": index,
                "row": row,
                "column": col,
                "sourceCell": [x0, y0, x1 - x0, y1 - y0],
                "sourceCrop": [int(x0 + bx0), int(y0 + by0), int(bx1 - bx0), int(by1 - by0)],
                "frame": [col * FRAME, row * FRAME, FRAME, FRAME],
                "placed": [int(dest_x), int(dest_y), int(sw), int(sh)],
            })

    sheet[sheet[:, :, 3] == 0, :3] = 0

    debug[:] = sheet
    for row in range(ROWS):
        for col in range(COLS):
            x = col * FRAME
            y = row * FRAME
            cv2.rectangle(debug, (x, y), (x + FRAME - 1, y + FRAME - 1), (255, 0, 255, 255), 1)

    checker = np.zeros_like(sheet)
    tile = 16
    for y in range(checker.shape[0]):
        for x in range(checker.shape[1]):
            shade = 38 if ((x // tile) + (y // tile)) % 2 == 0 else 56
            checker[y, x] = [shade, shade, shade, 255]

    alpha = sheet[:, :, 3:4].astype(np.float32) / 255.0
    preview_rgb = (sheet[:, :, :3].astype(np.float32) * alpha + checker[:, :, :3].astype(np.float32) * (1.0 - alpha)).astype(np.uint8)
    preview = np.dstack([preview_rgb, np.full(sheet.shape[:2], 255, dtype=np.uint8)])

    cv2.imwrite(str(OUT_SHEET), cv2.cvtColor(sheet, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(OUT_DEBUG), cv2.cvtColor(debug, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(OUT_PREVIEW), cv2.cvtColor(preview, cv2.COLOR_RGBA2BGRA))
    OUT_METADATA.write_text(json.dumps({
        "image": OUT_SHEET.name,
        "columns": COLS,
        "rows": ROWS,
        "frameWidth": FRAME,
        "frameHeight": FRAME,
        "animations": ANIMATIONS,
        "frames": frames,
    }, indent=2) + "\n")

    print(OUT_SHEET)
    print(OUT_DEBUG)
    print(OUT_PREVIEW)
    print(OUT_METADATA)


if __name__ == "__main__":
    main()
