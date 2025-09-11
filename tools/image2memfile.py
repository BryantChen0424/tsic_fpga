#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Resize -> optional mirror along long axis -> pixel format convert -> dump 1 value/line.

Supported pixel formats:
- RGB565 : 16 bits  (bin: 16 chars; hex: 4 digits)
- RGB332 : 8  bits  (bin: 8  chars; hex: 2 digits)
- GREY4  : 4  bits  (bin: 4  chars; hex: 1 digit)

Default:
- width x height = 80 x 40
- flip = auto (width>=height -> horizontal; else vertical)
- out = bin (use hex for $readmemh)
"""

import argparse
from PIL import Image, ImageOps

def rgb565_from_rgb888(r: int, g: int, b: int) -> int:
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)

def rgb332_from_rgb888(r: int, g: int, b: int) -> int:
    r3 = r >> 5
    g3 = g >> 5
    b2 = b >> 6
    return (r3 << 5) | (g3 << 2) | b2

def grey4_from_rgb888(r: int, g: int, b: int) -> int:
    # ITU-R BT.601 luma, round to nearest, then quantize to 4 bits (0..15)
    y = int(0.299 * r + 0.587 * g + 0.114 * b + 0.5)
    return (y >> 4)  # 0..15

def fmt_value(val: int, bits: int, outfmt: str) -> str:
    if outfmt == "bin":
        return f"{val:0{bits}b}"
    elif outfmt == "hex":
        # 4 bits -> 1 hex, 8 bits -> 2 hex, 16 bits -> 4 hex
        return f"{val:0{bits//4}X}"
    else:
        raise ValueError("out format must be 'bin' or 'hex'")

def convert(input_path: str, output_path: str,
            width: int, height: int,
            pixfmt: str, outfmt: str,
            flip_mode: str, resample=Image.NEAREST) -> None:

    img = Image.open(input_path).convert("RGB").resize((width, height), resample=resample)

    # Flip
    if flip_mode == "h":
        img = ImageOps.mirror(img)
    elif flip_mode == "v":
        img = ImageOps.flip(img)
    elif flip_mode == "none":
        pass
    else:
        raise ValueError("flip must be one of: auto, none, h, v")

    if pixfmt.upper() == "RGB565":
        bits = 16
        conv = rgb565_from_rgb888
    elif pixfmt.upper() == "RGB332":
        bits = 8
        conv = rgb332_from_rgb888
    elif pixfmt.upper() == "GREY4":
        bits = 4
        conv = grey4_from_rgb888
    else:
        raise ValueError("pixfmt must be one of: RGB565, RGB332, GREY4")

    px = img.load()
    with open(output_path, "w", encoding="utf-8") as f:
        for y in range(height):
            for x in range(width):
                r, g, b = px[x, y]
                v = conv(r, g, b)
                f.write(fmt_value(v, bits, outfmt) + "\n")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Export pixels per-line for $readmemb/$readmemh.")
    ap.add_argument("input", help="Input image (jpg/png/...)")
    ap.add_argument("output", help="Output text file")
    ap.add_argument("--width", type=int, default=20, help="Target width (default: 20)")
    ap.add_argument("--height", type=int, default=10, help="Target height (default: 10)")
    ap.add_argument("--pixfmt", choices=["RGB565", "RGB332", "GREY4"], default="RGB332",
                    help="Pixel format (default: RGB332)")
    ap.add_argument("--out", choices=["bin", "hex"], default="bin",
                    help="Line format for file: bin for $readmemb, hex for $readmemh (default: bin)")
    ap.add_argument("--flip", choices=["none", "h", "v"], default="auto",
                    help="Flip specify none/h/v (default: none)")
    args = ap.parse_args()

    convert(args.input, args.output, args.width, args.height,
            args.pixfmt, args.out, args.flip)
    print(f"Done: {args.output}")
