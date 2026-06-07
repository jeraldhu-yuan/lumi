#!/usr/bin/env python3
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
IN_PATH = ROOT / "Assets" / "ChibiAssistant" / "generated" / "supplemental-sheet-transparent.png"
PRIMARY_PATH = ROOT / "Assets" / "ChibiAssistant" / "sprite-sheet.png"
OUT_DIR = ROOT / "Assets" / "ChibiAssistant" / "generated"
OUT_SHEET = OUT_DIR / "supplemental-sheet.png"
OUT_PREVIEW = OUT_DIR / "supplemental-sheet-preview.png"
OUT_METADATA = OUT_DIR / "supplemental-sheet.json"

COLS = 4
ROWS = 4
FRAME = 256
PADDING = 24

FRAME_ROLES = [
    "neutral_standing_open_eyes",
    "blink",
    "look_left_curious",
    "look_right_curious",
    "sleepy_half_open",
    "rubbing_eyes",
    "yawn",
    "awake_smile",
    "fly_right_flap_a",
    "fly_right_flap_b",
    "fly_left_flap_a",
    "fly_left_flap_b",
    "question_mark_notice",
    "point_investigate",
    "working_focus",
    "happy_wave",
]


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    left, top, right, bottom = bbox
    return (
        max(0, left - 2),
        max(0, top - 2),
        min(image.width, right + 2),
        min(image.height, bottom + 2),
    )


def fit_sprite(sprite: Image.Image) -> Image.Image:
    max_size = FRAME - PADDING * 2
    scale = min(1.0, max_size / max(sprite.width, sprite.height))
    new_size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    return sprite.resize(new_size, Image.Resampling.LANCZOS)


def paste_clean(base: Image.Image, sprite: Image.Image, xy: tuple[int, int]) -> None:
    canvas = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    canvas.paste(sprite, (0, 0), sprite.getchannel("A"))
    base.alpha_composite(canvas, xy)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = Image.open(IN_PATH).convert("RGBA")
    primary = Image.open(PRIMARY_PATH).convert("RGBA")
    sheet = Image.new("RGBA", (COLS * FRAME, ROWS * FRAME), (0, 0, 0, 0))
    frames = []

    for row in range(ROWS):
        for col in range(COLS):
            index = row * COLS + col
            x0 = round(col * source.width / COLS)
            x1 = round((col + 1) * source.width / COLS)
            y0 = round(row * source.height / ROWS)
            y1 = round((row + 1) * source.height / ROWS)

            cell = source.crop((x0, y0, x1, y1))
            if row == 2:
                red, green, blue, alpha = cell.split()
                alpha_pixels = alpha.load()
                for y in range(max(0, alpha.height - 64), alpha.height):
                    for x in range(alpha.width):
                        alpha_pixels[x, y] = 0
                cell.putalpha(alpha)

            if row == 3:
                primary_indices = [4, 5, 6, 11]
                primary_index = primary_indices[col]
                primary_col = primary_index % COLS
                primary_row = primary_index // COLS
                sprite = primary.crop((
                    primary_col * FRAME,
                    primary_row * FRAME,
                    (primary_col + 1) * FRAME,
                    (primary_row + 1) * FRAME,
                ))
                bbox = (0, 0, cell.width, cell.height)
                dest_x = col * FRAME
                dest_y = row * FRAME
            else:
                bbox = alpha_bbox(cell)
                sprite = cell.crop(bbox)
                sprite = fit_sprite(sprite)
                dest_x = col * FRAME + (FRAME - sprite.width) // 2
                dest_y = row * FRAME + (FRAME - sprite.height) // 2

            paste_clean(sheet, sprite, (dest_x, dest_y))

            frames.append({
                "index": index,
                "row": row,
                "column": col,
                "sourceCell": [x0, y0, x1 - x0, y1 - y0],
                "sourceCrop": [x0 + bbox[0], y0 + bbox[1], bbox[2] - bbox[0], bbox[3] - bbox[1]],
                "frame": [col * FRAME, row * FRAME, FRAME, FRAME],
                "placed": [dest_x, dest_y, sprite.width, sprite.height],
                "role": FRAME_ROLES[index],
            })

    sheet.save(OUT_SHEET)

    checker = Image.new("RGBA", sheet.size, (0, 0, 0, 255))
    draw = ImageDraw.Draw(checker)
    tile = 16
    for y in range(0, checker.height, tile):
        for x in range(0, checker.width, tile):
            shade = 38 if ((x // tile) + (y // tile)) % 2 == 0 else 56
            draw.rectangle([x, y, x + tile - 1, y + tile - 1], fill=(shade, shade, shade, 255))
    checker.alpha_composite(sheet)
    checker.save(OUT_PREVIEW)

    OUT_METADATA.write_text(json.dumps({
        "image": OUT_SHEET.name,
        "columns": COLS,
        "rows": ROWS,
        "frameWidth": FRAME,
        "frameHeight": FRAME,
        "frameRoles": FRAME_ROLES,
        "frames": frames,
    }, indent=2) + "\n")

    print(OUT_SHEET)
    print(OUT_PREVIEW)
    print(OUT_METADATA)


if __name__ == "__main__":
    main()
