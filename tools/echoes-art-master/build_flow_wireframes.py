#!/usr/bin/env python3
"""Render the information-flow specification as editable SVG and preview PNG.

The JSON files are diagram data, never gameplay data. Requires Pillow and a CJK
font. Geometry and text are emitted to both formats from the same drawing calls.
"""
from __future__ import annotations

import argparse
import html
import io
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "docs/art/echoes-ui/flow-wireframes"
INK = "#283335"
MUTED = "#626c6d"
LINE = "#929c9d"
PALE = "#f2f4f3"
ACTION = "#dde6e5"
FONT_DEFAULT = "/System/Library/Fonts/Supplemental/Songti.ttc"


class Drawing:
    def __init__(self, width, height, font_path, font_index):
        self.width, self.height = width, height
        self.font_path, self.font_index = font_path, font_index
        self.fonts = {}
        self.image = Image.new("RGB", (width, height), "white")
        self.draw = ImageDraw.Draw(self.image)
        self.svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
                    '<rect width="100%" height="100%" fill="white"/>']

    def font(self, size):
        if size not in self.fonts:
            self.fonts[size] = ImageFont.truetype(self.font_path, size, index=self.font_index)
        return self.fonts[size]

    def rect(self, x, y, w, h, fill="white", stroke=LINE, width=2):
        self.draw.rectangle((x, y, x + w, y + h), fill=fill, outline=stroke, width=width)
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke or "none"}" stroke-width="{width}"/>')

    def line(self, points, color=LINE, width=2):
        self.draw.line(points, fill=color, width=width)
        p = " ".join(f"{x},{y}" for x, y in points)
        self.svg.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{width}"/>')

    def ellipse(self, x, y, w, h, fill="white", stroke=LINE):
        self.draw.ellipse((x, y, x+w, y+h), fill=fill, outline=stroke, width=2)
        self.svg.append(f'<ellipse cx="{x+w/2}" cy="{y+h/2}" rx="{w/2}" ry="{h/2}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')

    def text(self, x, y, value, size=24, color=INK):
        self.draw.text((x, y), value, font=self.font(size), fill=color, anchor="lt")
        self.svg.append(f'<text x="{x}" y="{y}" font-family="Songti SC, Noto Serif CJK SC, serif" font-size="{size}" dominant-baseline="text-before-edge" fill="{color}">{html.escape(value)}</text>')

    def wrap(self, value, size, width):
        result = []
        for para in value.split("\n"):
            line = ""
            for char in para:
                if line and self.draw.textlength(line + char, font=self.font(size)) > width:
                    result.append(line)
                    line = char
                else:
                    line += char
            result.append(line)
        return result

    def paragraph(self, x, y, value, width, size=24, color=INK, leading=None):
        leading = leading or size + 10
        for line in self.wrap(value, size, width):
            self.text(x, y, line, size, color)
            y += leading
        return y

    def arrow(self, x1, y, x2, label):
        self.line([(x1, y), (x2, y)], INK, 3)
        self.line([(x2-12, y-8), (x2, y), (x2-12, y+8)], INK, 3)
        self.paragraph(x1, y-53, label, x2-x1, 23)

    def save_bytes(self):
        stream = io.BytesIO()
        self.image.save(stream, format="PNG", optimize=True)
        return ("\n".join(self.svg + ["</svg>"]) + "\n").encode(), stream.getvalue()


def scene_placeholder(d, x, y, w, h, person=False):
    d.rect(x, y, w, h, PALE)
    d.line([(x+8, y+h-15), (x+w*.3, y+h*.55), (x+w*.5, y+h-24),
            (x+w*.74, y+h*.35), (x+w-8, y+h-15)])
    if person:
        d.ellipse(x+w*.43, y+10, 26, 26, PALE)
        d.line([(x+w*.35, y+h-12), (x+w*.42, y+42), (x+w*.57, y+42), (x+w*.65, y+h-12)], MUTED, 3)
    d.text(x+9, y+8, "情境画面", 18, MUTED)


def block(d, x, y, w, h, data, visual=None):
    active = data.get("kind") == "action"
    d.rect(x, y, w, h, ACTION if active else "white", INK if active else LINE)
    cursor = d.paragraph(x+16, y+15, data["title"], w-32, 25, leading=32)
    cursor += 12
    if visual:
        scene_placeholder(d, x+16, cursor, w-32, 94, person=visual == "person")
        cursor += 111
    for item in data["lines"]:
        if "← 选中" in item:
            d.rect(x+10, cursor-5, w-20, 37, ACTION, ACTION)
        cursor = d.paragraph(x+16, cursor, item, w-32, 22, leading=29) + 13
    if cursor > y+h+2:
        raise ValueError(f"Block text overflow: {data['title']} ({cursor-y}>{h})")


def frame(d, x, y, f, index, sheet):
    w, h = 744, 662
    d.text(x, y, f["title"], 30)
    sy = y+52
    d.rect(x, sy, w, h, "white", INK)
    d.rect(x, sy, w, 43, PALE)
    d.text(x+16, sy+11, "R1  全局状态与入口 · 始终可达", 21, MUTED)
    # Persistent world rail: thumbnail + information instead of a text-only menu.
    d.rect(x, sy+43, 72, h-104, PALE)
    d.text(x+13, sy+60, "R2", 21, MUTED)
    d.text(x+13, sy+90, "世界", 21, MUTED)
    for k in range(3):
        py = sy+133+k*113
        d.rect(x+13, py, 46, 45, "white")
        d.line([(x+18,py+35),(x+33,py+17),(x+53,py+35)])
        d.line([(x+14,py+61),(x+57,py+61)])
        d.line([(x+14,py+76),(x+46,py+76)])
    # Prayer summaries remain accessible, not a second open action panel.
    d.rect(x+w-64, sy+43, 64, h-104, PALE)
    d.text(x+w-53, sy+60, "R4", 21, MUTED)
    d.text(x+w-53, sy+90, "祈求", 21, MUTED)
    for k in range(2):
        py = sy+133+k*137
        d.rect(x+w-53, py, 42, 99, "white")
        d.ellipse(x+w-42, py+13, 20, 20, PALE)
        d.line([(x+w-47,py+52),(x+w-17,py+52)])
        d.line([(x+w-47,py+68),(x+w-23,py+68)])
    cx, cw = x+86, w-164
    task_end = d.paragraph(cx, sy+59, f["task"], cw, 25, leading=32)
    if task_end > sy+123:
        raise ValueError("Task heading overflow")
    by = sy+133
    leftw = {"overview": 310, "history": 200}.get(f.get("composition"), 238)
    visual = f.get("visual")
    block(d, cx, by, leftw, 350, f["left"], visual)
    block(d, cx+leftw+12, by, cw-leftw-12, 350, f["right"])
    d.text(cx, by+363, "当前任务内的入口 / 执行 / 返回", 18, MUTED)
    d.rect(cx, by+392, cw, 65, PALE)
    end = d.paragraph(cx+12, by+402, f["bottom"], cw-24, 22, leading=27)
    if end > by+456:
        raise ValueError("Task footer overflow")
    # Continuous bottom region, with its dedicated next-round space.
    dy = sy+h-61
    d.rect(x, dy, w, 61, PALE)
    d.text(x+15, dy+9, "R5  权能 / 圣物", 19, MUTED)
    d.text(x+15, dy+34, "编年史", 19, MUTED)
    d.line([(x+w-104,dy),(x+w-104,dy+61)])
    d.text(x+w-92,dy+22,"下一回合",19,MUTED)
    d.paragraph(x+4, sy+h+19, f["note"], w-8, 25, leading=34)


def render(data, font_path, font_index):
    rows = math.ceil(len(data["frames"])/3)
    height = 1200 if rows == 1 else 2130
    d = Drawing(2400, height, font_path, font_index)
    d.text(44, 30, data["title"], 37)
    d.text(44, 86, "结构线框 · 推荐待审 · 信息关系示意，非正式局面；框线不是游戏边框，位置比例尚待实机验证。", 25, MUTED)
    d.text(44, 125, "中央＝R3主内容。浅灰：常驻入口；白色：资料；深框灰底：当前操作；行底色：选中；箭头：玩家动作。", 23, MUTED)
    for i, f in enumerate(data["frames"]):
        row, col = divmod(i, 3)
        x, y = 44+col*784, 182+row*930
        frame(d, x, y, f, i, data)
        if f.get("arrow"):
            # Numbered jumps keep a six-state sheet readable without suggesting
            # a nested screen stack; the third state points to the next row.
            label = f"→ {data['frames'][i+1]['title'].split(' ')[0]}  {f['arrow']}"
            d.arrow(x+6, y+867, x+720, label)
    d.line([(44,height-86),(2356,height-86)],LINE)
    d.paragraph(44,height-66,data["method"],2312,24,leading=31)
    return d.save_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare generated files without modifying them")
    parser.add_argument("--font", default=FONT_DEFAULT, help="Path to a CJK font; default is macOS Songti")
    parser.add_argument("--font-index", type=int, default=6)
    args = parser.parse_args()
    if not Path(args.font).is_file():
        parser.error("CJK font missing. Supply --font and --font-index for your environment.")
    failures = []
    count = 0
    for path in sorted(DATA.glob("*.json")):
        data = json.loads(path.read_text())
        if path.stem != data["id"]:
            raise ValueError(f"Diagram id mismatch: {path}")
        outputs = render(data, args.font, args.font_index)
        for suffix, content in zip(("svg", "png"), outputs):
            output = path.with_suffix("."+suffix)
            if args.check:
                if not output.exists() or output.read_bytes() != content:
                    failures.append(output.relative_to(ROOT).as_posix())
            else:
                output.write_bytes(content)
        count += 1
    if failures:
        raise SystemExit("Wireframe drift:\n" + "\n".join(failures))
    print(f"{'Verified' if args.check else 'Rendered'} {count} wireframe sheets (SVG + PNG).")


if __name__ == "__main__":
    main()
