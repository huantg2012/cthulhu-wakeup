"""Validate and render fixed-canvas perception studies using only stdlib.

Primitives describe a review drawing, never game controls or game behavior.
Text coordinates follow SVG: x is the selected anchor, y is the baseline.
"""
from __future__ import annotations

import html
import math
import re
import unicodedata


ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\Z")
COLOR = re.compile(r"(?:#[0-9a-fA-F]{3}|#[0-9a-fA-F]{4}|#[0-9a-fA-F]{6}|#[0-9a-fA-F]{8}|[A-Za-z]{1,24})\Z")
SIZES = (16, 18, 20, 24, 28)
TYPES = {"rect", "ellipse", "line", "polygon", "bezier", "text"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def string(value: object, where: str, maximum: int, empty: bool = False) -> str:
    require(isinstance(value, str), f"{where}: expected text")
    require(len(value) <= maximum and (empty or bool(value.strip())), f"{where}: empty or too long")
    require(not any(ord(c) < 32 and c not in "\n\t" for c in value), f"{where}: invalid control character")
    return value


def number(value: object, where: str, low: float, high: float) -> float:
    require(type(value) in (int, float) and math.isfinite(value), f"{where}: expected finite number")
    require(low <= value <= high, f"{where}: outside {low}..{high}")
    return value


def validate(data: object) -> dict:
    require(isinstance(data, dict), "perception-study: expected an object")
    require(data.get("kind") == "perception-study", "Unsupported study kind")
    require(type(data.get("width")) is int and data["width"] == 1280
            and type(data.get("height")) is int and data["height"] == 720,
            "perception-study requires a fixed 1280 x 720 canvas")
    string(data.get("title"), "title", 200)
    views = data.get("views")
    require(isinstance(views, list) and 1 <= len(views) <= 32, "views: expected 1..32 views")
    ids = set()
    for vi, view in enumerate(views):
        at = f"views[{vi}]"
        require(isinstance(view, dict), f"{at}: expected an object")
        key = string(view.get("id"), at + ".id", 80)
        require(bool(ID.fullmatch(key)) and key not in ids, f"{at}.id: invalid or duplicate ID")
        ids.add(key)
        string(view.get("title"), at + ".title", 200)
        string(view.get("description"), at + ".description", 2000, empty=True)
        notes = view.get("notes")
        require(isinstance(notes, list) and len(notes) <= 100, f"{at}.notes: expected at most 100 notes")
        for ni, note in enumerate(notes):
            string(note, f"{at}.notes[{ni}]", 2000)
        elements = view.get("elements")
        require(isinstance(elements, list) and 1 <= len(elements) <= 2500,
                f"{at}.elements: expected 1..2500 primitives")
        for ei, element in enumerate(elements):
            validate_element(element, f"{at}.elements[{ei}]", data["width"], data["height"])
    return data


def validate_element(e: object, at: str, width: int, height: int) -> None:
    require(isinstance(e, dict), f"{at}: expected an object")
    kind = e.get("type")
    require(isinstance(kind, str) and kind in TYPES, f"{at}.type: unsupported primitive")

    def n(key: str, high: float, low: float = 0) -> float:
        return number(e.get(key), at + "." + key, low, high)

    for key in (["fill"] if kind == "text" else ["stroke"] if kind in ("line", "bezier") else ["fill", "stroke"]):
        color = string(e.get(key), at + "." + key, 24)
        require(bool(COLOR.fullmatch(color)), f"{at}.{key}: use a color name or hex color")
    if "opacity" in e:
        n("opacity", 1)
    if "strokeWidth" in e:
        n("strokeWidth", 30)
    if kind == "rect":
        x, y, w, h = n("x", width), n("y", height), n("w", width), n("h", height)
        require(w > 0 and h > 0 and x + w <= width and y + h <= height, f"{at}: rectangle outside canvas")
    elif kind == "ellipse":
        cx, cy, rx, ry = n("cx", width), n("cy", height), n("rx", width), n("ry", height)
        require(rx > 0 and ry > 0 and 0 <= cx - rx and cx + rx <= width
                and 0 <= cy - ry and cy + ry <= height, f"{at}: ellipse outside canvas")
    elif kind == "line":
        n("x1", width); n("x2", width); n("y1", height); n("y2", height)
    elif kind in ("polygon", "bezier"):
        points = e.get("points")
        require(isinstance(points, list), f"{at}.points: expected an array")
        require(len(points) == 4 if kind == "bezier" else 3 <= len(points) <= 128,
                f"{at}.points: expected four Bezier points or 3..128 polygon points")
        for pi, point in enumerate(points):
            require(isinstance(point, list) and len(point) == 2, f"{at}.points[{pi}]: expected [x,y]")
            number(point[0], f"{at}.points[{pi}].x", 0, width)
            number(point[1], f"{at}.points[{pi}].y", 0, height)
        if kind == "bezier" and "fill" in e:
            require(e["fill"] == "none", f"{at}.fill: Bezier fill must be none")
    else:
        x, y = n("x", width), n("y", height)
        text = string(e.get("text"), at + ".text", 200)
        require("\n" not in text and "\t" not in text, f"{at}.text: use a separate primitive for each line")
        size = e.get("size")
        require(type(size) is int and size in SIZES, f"{at}.size: expected one of {SIZES}")
        require(type(e.get("weight")) is int and e["weight"] in (400, 600), f"{at}.weight: expected 400 or 600")
        anchor = e.get("anchor", "start")
        require(anchor in ("start", "middle", "end"), f"{at}.anchor: unsupported anchor")
        # A conservative advance estimate catches plainly off-canvas lines.
        # Real font shaping still needs a separate rendered-image inspection.
        advance = sum(0 if unicodedata.combining(c) else size if unicodedata.east_asian_width(c) in ("W", "F")
                      else size * (0.35 if c.isspace() else 0.65) for c in text)
        left = x - (advance / 2 if anchor == "middle" else advance if anchor == "end" else 0)
        require(left >= 0 and left + advance <= width and y >= size and y + size * .25 <= height,
                f"{at}: estimated text bounds outside canvas")


def escape(value: object) -> str:
    return html.escape(str(value), quote=True)


def svg(view: dict, width: int = 1280, height: int = 720) -> str:
    parts = [f'<svg class="perception-canvas" xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="drawing-{escape(view["id"])}">',
             f'<title id="drawing-{escape(view["id"])}">{escape(view["title"])}</title>']
    for e in view["elements"]:
        kind = e["type"]
        attrs = f' opacity="{escape(e.get("opacity", 1))}"'
        if kind != "text":
            attrs += f' stroke="{escape(e["stroke"])}" stroke-width="{escape(e.get("strokeWidth", 1))}"'
        if kind == "text":
            parts.append(f'<text x="{e["x"]}" y="{e["y"]}" font-size="{e["size"]}" font-weight="{e["weight"]}" text-anchor="{e.get("anchor", "start")}" fill="{escape(e["fill"])}"{attrs}>{escape(e["text"])}</text>')
        elif kind in ("rect", "ellipse", "line"):
            keys = {"rect": ("x", "y", "w", "h"), "ellipse": ("cx", "cy", "rx", "ry"), "line": ("x1", "y1", "x2", "y2")}[kind]
            dimensions = " ".join(f'{ {"w":"width", "h":"height"}.get(k,k)}="{e[k]}"' for k in keys)
            fill = f' fill="{escape(e["fill"])}"' if kind != "line" else ""
            parts.append(f'<{kind} {dimensions}{fill}{attrs}/>')
        elif kind == "polygon":
            points = " ".join(f"{x},{y}" for x, y in e["points"])
            parts.append(f'<polygon points="{points}" fill="{escape(e["fill"])}"{attrs}/>')
        else:
            p = e["points"]
            path = f'M {p[0][0]} {p[0][1]} C {p[1][0]} {p[1][1]}, {p[2][0]} {p[2][1]}, {p[3][0]} {p[3][1]}'
            parts.append(f'<path d="{path}" fill="none"{attrs}/>')
    parts.append("</svg>")
    return "\n".join(parts)


STYLE = """
.study-picker { display:flex; flex-wrap:wrap; gap:8px; margin:20px 0; }
.study-picker button { font:inherit; color:#222; background:#fff; border:1px solid #999; padding:8px 14px; cursor:pointer; }
.study-picker button[aria-pressed="true"] { border:2px solid #222; padding:7px 13px; font-weight:600; }
.study-picker button:focus-visible { outline:3px solid #2458b8; outline-offset:3px; }
.study-scroll { overflow-x:auto; border:1px solid #aaa; }
.perception-canvas { display:block; width:1280px; height:720px; max-width:none; font-family:"Microsoft YaHei","PingFang SC","Noto Sans CJK SC",sans-serif; }
.study-notes { padding:12px 0; }
.study-prose { margin-top:32px; }
"""

SCRIPT = r"""
(() => {
  'use strict';
  const views = Array.from(document.querySelectorAll('[data-study-view]'));
  const buttons = Array.from(document.querySelectorAll('[data-study-select]'));
  function route() {
    let hash = '';
    try { hash = decodeURIComponent(location.hash.slice(1)); } catch { /* First view is safe fallback. */ }
    const selected = views.find(view => 'view-' + view.dataset.studyView === hash) || views[0];
    for (const view of views) view.hidden = view !== selected;
    for (const button of buttons) button.setAttribute('aria-pressed', String(button.dataset.studySelect === selected.dataset.studyView));
  }
  for (const button of buttons) button.addEventListener('click', () => {
    const hash = '#view-' + encodeURIComponent(button.dataset.studySelect);
    if (location.hash === hash) route();
    else location.hash = hash;
  });
  window.addEventListener('hashchange', route);
  route();
})();
"""


def build_html(data: dict, prose: str, source_name: str, digest: str,
               generated: str, markdown, base_style: str) -> str:
    buttons, drawings = [], []
    for index, view in enumerate(data["views"]):
        key = escape(view["id"])
        buttons.append(f'<button type="button" data-study-select="{key}" aria-controls="view-{key}" aria-pressed="{str(index == 0).lower()}">{escape(view["title"])}</button>')
        notes = "".join(f'<li>{markdown.inline(note)}</li>' for note in view["notes"])
        drawings.append(f'<article id="view-{key}" data-study-view="{key}"{ " hidden" if index else ""}><h2>{escape(view["title"])}</h2><p>{escape(view["description"])}</p><div class="study-scroll" tabindex="0" aria-label="固定画布，可横向滚动">{svg(view, data["width"], data["height"])}</div><aside class="study-notes"><h3>图外说明</h3><ul>{notes}</ul></aside></article>')
    return f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'">
<meta name="source-sha256" content="{escape(digest)}"><meta name="source-path" content="{escape(source_name)}">
<title>{escape(data["title"])} · 结构示意</title><style>{base_style}\n{STYLE}</style></head>
<body><header class="page-header"><h1>{escape(data["title"])}</h1><p class="scope">设计提案 / 结构示意，非运行游戏或最终美术</p><p class="provenance">唯一来源：<code>{escape(source_name)}</code> · {escape(generated)}<br>源 SHA256：<code>{escape(digest)}</code></p></header>
<main><section class="panel"><p>下方按钮切换审阅材料中的展示状态，不是游戏导航。画布固定为1280 × 720。</p><nav class="study-picker" aria-label="结构示意状态">{"".join(buttons)}</nav>{"".join(drawings)}</section>
<section class="panel study-prose"><h2>完整设计说明</h2><article class="specification">{markdown.render(prose)}</article></section></main>
<footer>本材料离线显示结构示意，不读取游戏状态，不执行游戏操作。</footer><script>{SCRIPT}</script></body></html>'''
