#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Resize -> optional mirror along long axis -> pixel format convert -> dump 1 value/line.

Supported pixel formats:
- RGB565 : 16 bits  (bin: 16 chars; hex: 4 digits)
- RGB332 : 8  bits  (bin: 8  chars; hex: 2 digits)
- GREY4  : 4  bits  (bin: 4  chars; hex: 1 digit)
- BIN1   : 1  bit   (bin: 1   char ; hex: 1 digit)  <-- NEW (binarized by threshold)

Default:
- width x height = 20 x 10
- flip = none (choose h/v/none)
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

def bin1_from_rgb888(r: int, g: int, b: int, thresh: int) -> int:
    # BT.601 luma; return 1 if >= thresh else 0
    y = int(0.299 * r + 0.587 * g + 0.114 * b + 0.5)
    return 1 if y >= thresh else 0

def fmt_value(val: int, bits: int, outfmt: str) -> str:
    if outfmt == "bin":
        return f"{val:0{bits}b}"
    elif outfmt == "hex":
        # ensure at least 1 hex digit (works even for bits=1)
        digits = max(1, (bits + 3) // 4)
        return f"{val:0{digits}X}"
    else:
        raise ValueError("out format must be 'bin' or 'hex'")

def convert(input_path: str, output_path: str,
            width: int, height: int,
            pixfmt: str, outfmt: str,
            flip_mode: str, resample=Image.NEAREST,
            thresh: int = 128) -> None:

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

    pf = pixfmt.upper()
    if pf == "RGB565":
        bits = 16
        def conv(r,g,b): return rgb565_from_rgb888(r,g,b)
    elif pf == "RGB332":
        bits = 8
        def conv(r,g,b): return rgb332_from_rgb888(r,g,b)
    elif pf == "GREY4":
        bits = 4
        def conv(r,g,b): return grey4_from_rgb888(r,g,b)
    elif pf == "BIN1":
        bits = 1
        def conv(r,g,b): return bin1_from_rgb888(r,g,b, thresh)
    else:
        raise ValueError("pixfmt must be one of: RGB565, RGB332, GREY4, BIN1")

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
    ap.add_argument("--pixfmt", choices=["RGB565", "RGB332", "GREY4", "BIN1"], default="RGB332",
                    help="Pixel format (default: RGB332)")
    ap.add_argument("--out", choices=["bin", "hex"], default="bin",
                    help="Line format for file: bin for $readmemb, hex for $readmemh (default: bin)")
    ap.add_argument("--flip", choices=["none", "h", "v"], default="none",
                    help="Flip specify none/h/v (default: none)")
    ap.add_argument("--thresh", type=int, default=128,
                    help="Threshold for BIN1 (0..255, default: 128)")
    args = ap.parse_args()

    convert(args.input, args.output, args.width, args.height,
            args.pixfmt, args.out, args.flip, thresh=args.thresh)
    print(f"Done: {args.output}")
