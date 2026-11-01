#!/usr/bin/env python3
"""Build an offline structure reader from the marked, authoritative UI spec.

Uses only the Python standard library. The reader contains no game code or data
queries. Run from any directory; defaults are resolved against this repository.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import html
import json
import math
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[2]
START = "<!-- ui-structure:start -->"
END = "<!-- ui-structure:end -->"
WIDTH, HEIGHT = 1280, 720
GRAPH_WIDTH, GRAPH_HEIGHT = 1280, 880
NODE_WIDTH, NODE_HEIGHT = 250, 102
ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\Z")
STRUCTURE_FENCE = re.compile(r"^```ui-structure\s*\n(.*?)^```\s*$", re.M | re.S)
HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
LIST_ITEM = re.compile(r"^(\s*)([-+*]|\d+[.)])\s+(.+)$")


class SourceError(ValueError):
    """A source contract or geometry error; no artifact should be written."""


def escaped(value: object) -> str:
    return html.escape(str(value), quote=True)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SourceError(message)


def text_value(value: object, location: str, *, empty: bool = False) -> str:
    require(isinstance(value, str), f"{location}: expected a string")
    require(empty or bool(value.strip()), f"{location}: cannot be empty")
    return value


def object_value(value: object, location: str) -> dict:
    require(isinstance(value, dict), f"{location}: expected an object")
    return value


def list_value(value: object, location: str, *, empty: bool = False) -> list:
    require(isinstance(value, list), f"{location}: expected an array")
    require(empty or bool(value), f"{location}: cannot be empty")
    return value


def check_id(value: object, location: str, seen: set[str]) -> str:
    item_id = text_value(value, location)
    require(bool(ID_PATTERN.fullmatch(item_id)), f"{location}: invalid ID {item_id!r}")
    require(item_id not in seen, f"{location}: duplicate ID {item_id!r}")
    seen.add(item_id)
    return item_id


def validate_structure(value: object) -> dict:
    data = object_value(value, "ui-structure")
    text_value(data.get("title"), "title")
    scenes = list_value(data.get("scenes"), "scenes")
    links = list_value(data.get("links"), "links", empty=True)
    frames = list_value(data.get("wireframes"), "wireframes")
    scene_ids: set[str] = set()
    frame_ids: set[str] = set()
    for index, scene in enumerate(scenes):
        place = f"scenes[{index}]"
        object_value(scene, place)
        check_id(scene.get("id"), f"{place}.id", scene_ids)
        text_value(scene.get("title"), f"{place}.title")
        text_value(scene.get("subtitle"), f"{place}.subtitle", empty=True)
    graph_positions(scenes)
    for index, link in enumerate(links):
        place = f"links[{index}]"
        object_value(link, place)
        for key in ("from", "to"):
            text_value(link.get(key), f"{place}.{key}")
            require(link.get(key) in scene_ids, f"{place}.{key}: unknown scene")
        text_value(link.get("label"), f"{place}.label")
        text_value(link.get("type"), f"{place}.type")
    represented: set[str] = set()
    for index, frame in enumerate(frames):
        place = f"wireframes[{index}]"
        object_value(frame, place)
        check_id(frame.get("id"), f"{place}.id", frame_ids)
        text_value(frame.get("title"), f"{place}.title")
        text_value(frame.get("phase"), f"{place}.phase", empty=True)
        text_value(frame.get("scene"), f"{place}.scene")
        require(frame.get("scene") in scene_ids, f"{place}.scene: unknown scene")
        represented.add(frame["scene"])
        for note_index, note in enumerate(list_value(frame.get("notes"), f"{place}.notes", empty=True)):
            text_value(note, f"{place}.notes[{note_index}]")
        for region_index, region in enumerate(list_value(frame.get("regions"), f"{place}.regions")):
            region_place = f"{place}.regions[{region_index}]"
            object_value(region, region_place)
            for key in ("x", "y", "w", "h"):
                number = region.get(key)
                require(type(number) in (int, float) and math.isfinite(number),
                        f"{region_place}.{key}: expected a finite number")
            require(region["x"] >= 0 and region["y"] >= 0
                    and region["w"] > 0 and region["h"] > 0
                    and region["x"] + region["w"] <= WIDTH
                    and region["y"] + region["h"] <= HEIGHT,
                    f"{region_place}: region must stay inside {WIDTH} x {HEIGHT}")
            text_value(region.get("title"), f"{region_place}.title", empty=True)
            text_value(region.get("type"), f"{region_place}.type")
            for line_index, line in enumerate(list_value(region.get("lines"), f"{region_place}.lines", empty=True)):
                text_value(line, f"{region_place}.lines[{line_index}]", empty=True)
            fit_region(region, region_place)
    require(represented == scene_ids, "Every scene needs at least one wireframe")
    return data


def character_width(character: str, size: float) -> float:
    if unicodedata.combining(character):
        return 0
    if unicodedata.east_asian_width(character) in ("W", "F"):
        return size
    if character.isspace():
        return size * 0.35
    if character in "ilI.,:;!'|`":
        return size * 0.35
    if character in "MW@#%&":
        return size * 0.88
    return size * 0.64


def wrapped_lines(value: str, width: float, size: float) -> list[str]:
    """Conservatively wrap CJK and Latin text without discarding characters."""
    output: list[str] = []
    for paragraph in value.split("\n"):
        current, used = "", 0.0
        for character in paragraph:
            advance = character_width(character, size)
            if current and used + advance > width:
                output.append(current)
                current, used = "", 0.0
            current += character
            used += advance
        output.append(current)
    return output


def fit_region(region: dict, location: str) -> tuple[int, int, list[tuple[str, bool]]]:
    """Keep the reader within 14–18 px; reject source that cannot fit."""
    padding = 12
    for body_size in (16, 15, 14):
        title_size = min(18, body_size + 2)
        rows: list[tuple[str, bool]] = []
        available_width = region["w"] - 2 * padding - 4
        if available_width <= 0:
            continue
        if region["title"]:
            rows.extend((line, True) for line in wrapped_lines(region["title"], available_width, title_size))
        for line in region["lines"]:
            rows.extend((part, False) for part in wrapped_lines(line, available_width, body_size))
        used = 2 * padding + sum(title_size * 1.3 if title else body_size * 1.45 for _, title in rows)
        if region["title"] and region["lines"]:
            used += 6
        if used <= region["h"]:
            return title_size, body_size, rows
    raise SourceError(f"{location}: text does not fit at 14 px; enlarge the region or shorten source text")


def slug(value: str) -> str:
    plain = re.sub(r"[`*_~]", "", value).strip().lower()
    return re.sub(r"[^\w\u3400-\u9fff-]+", "-", plain).strip("-") or "section"


class Markdown:
    """Small escaped renderer for this document's headings/tables/lists contract."""

    def __init__(self, source: str, scenes: list[dict] | None = None) -> None:
        self.headings: list[tuple[int, str, str]] = []
        self.anchors: dict[str, str] = {}
        self.scenes = scenes or []
        self.scene_rows: dict[str, str] = {}
        self.heading_ids: list[str] = []
        used: dict[str, int] = {}
        in_fence = False
        for line in source.splitlines():
            if line.startswith("```"):
                in_fence = not in_fence
            heading = HEADING.match(line) if not in_fence else None
            if heading:
                base = slug(heading[2])
                count = used.get(base, 0)
                used[base] = count + 1
                key = base if count == 0 else f"{base}-{count}"
                anchor = f"spec-{key}"
                self.heading_ids.append(anchor)
                self.anchors.setdefault(base, anchor)
                self.headings.append((len(heading[1]), heading[2], anchor))
        self.heading_cursor = 0

    def link_target(self, target: str) -> str | None:
        if target.startswith("#"):
            name = target[1:]
            if name in self.anchors:
                return "#" + self.anchors[name]
            return target
        if urlsplit(target).scheme.lower() not in ("", "https", "http"):
            return None
        # The artifact lives in docs/game-state; source links are from docs/specs.
        if not urlsplit(target).scheme and not target.startswith("/"):
            return "../specs/" + target
        return target

    def inline(self, value: str) -> str:
        pattern = re.compile(r"(`+)(.+?)\1|\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|~~([^~]+)~~|(?<!\*)\*([^*]+)\*|<br\s*/?>", re.I)
        pieces: list[str] = []
        offset = 0
        for match in pattern.finditer(value):
            pieces.append(escaped(value[offset:match.start()]).replace("\\|", "|"))
            if match[1]:
                pieces.append(f"<code>{escaped(match[2])}</code>")
            elif match[3]:
                target = self.link_target(match[4])
                label = self.inline(match[3])
                pieces.append(f'<a href="{escaped(target)}">{label}</a>' if target else label)
            elif match[5]:
                pieces.append(f"<strong>{escaped(match[5])}</strong>")
            elif match[6]:
                pieces.append(f"<del>{escaped(match[6])}</del>")
            elif match[7]:
                pieces.append(f"<em>{escaped(match[7])}</em>")
            else:
                pieces.append("<br>")
            offset = match.end()
        pieces.append(escaped(value[offset:]).replace("\\|", "|"))
        return "".join(pieces)

    @staticmethod
    def table_cells(line: str) -> list[str]:
        cells, current = [], []
        in_code = False
        escaped_next = False
        for character in line.strip().strip("|"):
            if character == "|" and not in_code and not escaped_next:
                cells.append("".join(current).strip())
                current = []
            else:
                current.append(character)
            if character == "`" and not escaped_next:
                in_code = not in_code
            escaped_next = character == "\\" and not escaped_next
        cells.append("".join(current).strip())
        return cells

    def is_table(self, lines: list[str], index: int) -> bool:
        return index + 1 < len(lines) and "|" in lines[index] and all(
            re.fullmatch(r":?-{3,}:?", cell)
            for cell in self.table_cells(lines[index + 1])
        )

    def render(self, source: str) -> str:
        lines = source.splitlines()
        output: list[str] = []
        index = 0
        while index < len(lines):
            line = lines[index]
            if not line.strip():
                index += 1
                continue
            heading = HEADING.match(line)
            if heading:
                level = min(6, len(heading[1]) + 1)
                anchor = self.heading_ids[self.heading_cursor]
                self.heading_cursor += 1
                output.append(f'<h{level} id="{escaped(anchor)}">{self.inline(heading[2])}</h{level}>')
                index += 1
            elif line.startswith("```"):
                index += 1
                block: list[str] = []
                while index < len(lines) and not lines[index].startswith("```"):
                    block.append(lines[index])
                    index += 1
                index += 1
                output.append("<pre><code>" + escaped("\n".join(block)) + "</code></pre>")
            elif self.is_table(lines, index):
                headers = self.table_cells(line)
                output.append('<div class="table-scroll" tabindex="0"><table><thead><tr>')
                output.extend(f"<th scope=\"col\">{self.inline(cell)}</th>" for cell in headers)
                output.append("</tr></thead><tbody>")
                index += 2
                while index < len(lines) and "|" in lines[index] and lines[index].strip():
                    cells = self.table_cells(lines[index])
                    require(len(cells) == len(headers), f"Markdown table row has {len(cells)} cells; expected {len(headers)}: {lines[index][:100]}")
                    row_id = ""
                    for scene in self.scenes:
                        if scene["id"] not in self.scene_rows and re.search(r"(?<![\w-])" + re.escape(scene["id"]) + r"(?![\w-])", cells[0]):
                            anchor = f'spec-scene-{scene["id"]}'
                            self.scene_rows[scene["id"]] = anchor
                            row_id = f' id="{escaped(anchor)}"'
                            break
                    output.append(f"<tr{row_id}>" + "".join(f"<td>{self.inline(cell)}</td>" for cell in cells) + "</tr>")
                    index += 1
                output.append("</tbody></table></div>")
            elif LIST_ITEM.match(line):
                first = LIST_ITEM.match(line)
                assert first is not None
                base = len(first[1])
                ordered = first[2][0].isdigit()
                tag = "ol" if ordered else "ul"
                start = f' start="{int(re.match(r"\d+", first[2])[0])}"' if ordered else ""
                output.append(f"<{tag}{start}>")
                while index < len(lines):
                    item = LIST_ITEM.match(lines[index])
                    if not item or len(item[1]) != base or item[2][0].isdigit() != ordered:
                        break
                    output.append("<li>" + self.inline(item[3]))
                    index += 1
                    continuation: list[str] = []
                    while index < len(lines) and lines[index].strip():
                        next_item = LIST_ITEM.match(lines[index])
                        if next_item and len(next_item[1]) <= base:
                            break
                        if len(lines[index]) - len(lines[index].lstrip()) <= base:
                            break
                        continuation.append(lines[index][base + 2:])
                        index += 1
                    if continuation:
                        output.append(self.render("\n".join(continuation)))
                    output.append("</li>")
                output.append(f"</{tag}>")
            elif re.fullmatch(r"\s*(?:-{3,}|\*{3,}|_{3,})\s*", line):
                output.append("<hr>")
                index += 1
            elif line.startswith(">"):
                quote: list[str] = []
                while index < len(lines) and lines[index].startswith(">"):
                    quote.append(lines[index][1:].lstrip())
                    index += 1
                output.append("<blockquote>" + self.render("\n".join(quote)) + "</blockquote>")
            else:
                paragraph = [line.strip()]
                index += 1
                while index < len(lines) and lines[index].strip() and not (
                    HEADING.match(lines[index]) or LIST_ITEM.match(lines[index])
                    or lines[index].startswith(("```", ">")) or self.is_table(lines, index)
                    or re.fullmatch(r"\s*(?:-{3,}|\*{3,}|_{3,})\s*", lines[index])
                ):
                    paragraph.append(lines[index].strip())
                    index += 1
                output.append("<p>" + self.inline(" ".join(paragraph)) + "</p>")
        return "\n".join(output)

    def scene_anchor(self, scene: dict) -> str:
        if scene["id"] in self.scene_rows:
            return "#" + self.scene_rows[scene["id"]]
        for _, title, anchor in self.headings:
            if scene["id"] in title or scene["title"] in title:
                return "#" + anchor
        return "#spec"


def svg_text(x: float, y: float, lines: list[str], size: int, line_height: float,
             *, weight: int = 400, anchor: str = "start") -> str:
    spans = "".join(f'<tspan x="{x:.2f}" y="{y + index * line_height:.2f}">{escaped(line)}</tspan>'
                    for index, line in enumerate(lines))
    return f'<text font-size="{size}" font-weight="{weight}" text-anchor="{anchor}">{spans}</text>'


def wireframe_svg(frame: dict) -> str:
    result = [f'<svg class="wireframe" xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-label="{escaped(frame["title"])}">',
              f'<title>{escaped(frame["title"])}</title>',
              f'<rect x="0.5" y="0.5" width="{WIDTH - 1}" height="{HEIGHT - 1}" fill="#f5f5f5" stroke="#8b8b8b"/>']
    for index, region in enumerate(frame["regions"]):
        title_size, body_size, rows = fit_region(region, f'{frame["id"]}.regions[{index}]')
        x, y = region["x"], region["y"]
        result.append(f'<g data-region="{index}" data-region-type="{escaped(region["type"])}"><rect x="{x}" y="{y}" width="{region["w"]}" height="{region["h"]}" fill="#fff" stroke="#777"/>')
        cursor = y + 12
        previous_title = False
        for content, is_title in rows:
            size = title_size if is_title else body_size
            if previous_title and not is_title:
                cursor += 6
            result.append(svg_text(x + 12, cursor + size, [content], size, size * 1.45,
                                   weight=600 if is_title else 400))
            cursor += size * (1.3 if is_title else 1.45)
            previous_title = is_title
        result.append("</g>")
    result.append("</svg>")
    return "\n".join(result)


def graph_positions(scenes: list[dict]) -> dict[str, tuple[float, float]]:
    """Scene x/y are optional node centers in the overview document canvas."""
    positions: dict[str, tuple[float, float]] = {}
    for index, scene in enumerate(scenes):
        has_x, has_y = "x" in scene, "y" in scene
        require(has_x == has_y, f'scene {scene["id"]}: provide both x and y, or neither')
        if has_x:
            for axis in ("x", "y"):
                value = scene[axis]
                require(type(value) in (int, float) and math.isfinite(value),
                        f'scene {scene["id"]}.{axis}: expected a finite coordinate')
            x, y = scene["x"], scene["y"]
        else:
            angle = -math.pi / 2 + 2 * math.pi * index / len(scenes)
            x, y = 640 + 455 * math.cos(angle), 440 + 325 * math.sin(angle)
        require(NODE_WIDTH / 2 <= x <= GRAPH_WIDTH - NODE_WIDTH / 2
                and NODE_HEIGHT / 2 <= y <= GRAPH_HEIGHT - NODE_HEIGHT / 2,
                f'scene {scene["id"]}: node must stay inside {GRAPH_WIDTH} x {GRAPH_HEIGHT}')
        for other_id, (other_x, other_y) in positions.items():
            require(abs(x - other_x) >= NODE_WIDTH or abs(y - other_y) >= NODE_HEIGHT,
                    f'scene {scene["id"]}: node overlaps scene {other_id}')
        positions[scene["id"]] = (x, y)
    return positions


def graph_svg(data: dict) -> str:
    # Explicit centers come from the source; otherwise use a neutral ring.
    # This lays out a document, not a world map or a simulated game scene.
    scenes = data["scenes"]
    positions = graph_positions(scenes)
    result = ['<svg class="scene-graph" xmlns="http://www.w3.org/2000/svg" width="1280" height="880" viewBox="0 0 1280 880" role="img" aria-labelledby="graph-title graph-description">',
              '<title id="graph-title">场景导航关系图</title>',
              '<desc id="graph-description">场景位置只用于排版。箭头编号对应下方原文关系表。选择场景可查看该场景线框。</desc>',
              '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#777"/></marker></defs>']
    edge_labels: list[str] = []
    label_centers: list[tuple[float, float]] = []
    for index, link in enumerate(data["links"]):
        start_x, start_y = positions[link["from"]]
        end_x, end_y = positions[link["to"]]
        dx, dy = end_x - start_x, end_y - start_y
        length = math.hypot(dx, dy)
        if length == 0:
            path = f"M {start_x + 125} {start_y - 12} C {start_x + 205} {start_y - 112}, {start_x + 205} {start_y + 112}, {start_x + 125} {start_y + 12}"
            label_x, label_y = start_x + 177, start_y
        else:
            start_fraction = min(125 / abs(dx) if dx else math.inf, 51 / abs(dy) if dy else math.inf)
            end_fraction = start_fraction
            sx, sy = start_x + dx * start_fraction, start_y + dy * start_fraction
            ex, ey = end_x - dx * end_fraction, end_y - dy * end_fraction
            curve = 24 + (index % 3) * 13
            cx, cy = (sx + ex) / 2 - dy / length * curve, (sy + ey) / 2 + dx / length * curve
            path = f"M {sx:.2f} {sy:.2f} Q {cx:.2f} {cy:.2f} {ex:.2f} {ey:.2f}"
            candidates = [0.37 + (index % 3) * 0.13, 0.25, 0.75, 0.5, 0.17, 0.83]
            found_position = False
            for t in candidates:
                label_x = (1 - t) ** 2 * sx + 2 * (1 - t) * t * cx + t ** 2 * ex
                label_y = (1 - t) ** 2 * sy + 2 * (1 - t) * t * cy + t ** 2 * ey
                clear_labels = all(math.hypot(label_x - px, label_y - py) >= 30
                                   for px, py in label_centers)
                clear_nodes = all(abs(label_x - nx) >= NODE_WIDTH / 2 + 15
                                  or abs(label_y - ny) >= NODE_HEIGHT / 2 + 15
                                  for nx, ny in positions.values())
                if clear_labels and clear_nodes:
                    found_position = True
                    break
            require(found_position, f'link {index + 1}: cannot place its label without overlap')
        label_centers.append((label_x, label_y))
        marker_start = ' marker-start="url(#arrow)"' if link["type"] == "both" else ""
        result.append(f'<path d="{path}" fill="none" stroke="#929292" stroke-width="1.5"{marker_start} marker-end="url(#arrow)"><title>{escaped(link["label"])} · {escaped(link["type"])}</title></path>')
        edge_labels.append(f'<a href="#relationship-{index + 1}" aria-label="导航关系 {index + 1}：{escaped(link["label"])}"><circle cx="{label_x:.2f}" cy="{label_y:.2f}" r="13" fill="white" stroke="#888"/>{svg_text(label_x, label_y + 5, [str(index + 1)], 14, 18, anchor="middle")}</a>')
    result.extend(edge_labels)
    for scene in scenes:
        x, y = positions[scene["id"]]
        result.append(f'<a href="#scene-{escaped(scene["id"])}" aria-label="查看{escaped(scene["title"])}线框"><rect class="scene-node" x="{x - 125:.2f}" y="{y - 51:.2f}" width="250" height="102" rx="2" fill="white" stroke="#555" stroke-width="1.5"/>')
        title = wrapped_lines(scene["title"], 226, 18)
        subtitle = wrapped_lines(scene["subtitle"], 224, 14) if scene["subtitle"] else []
        content_height = len(title) * 24 + len(subtitle) * 20 + (6 if subtitle else 0)
        require(content_height <= 78, f'scene {scene["id"]}: graph title/subtitle does not fit the node')
        top = y - content_height / 2
        result.append(svg_text(x, top + 18, title, 18, 24, weight=600, anchor="middle"))
        result.append(svg_text(x, top + len(title) * 24 + 20, subtitle, 14, 20, anchor="middle"))
        result.append("</a>")
    result.append("</svg>")
    return "\n".join(result)


STYLE = r"""
:root { color-scheme: light; --ink: #202020; --muted: #5a5a5a; --line: #c8c8c8; --accent: #2458b8; }
* { box-sizing: border-box; }
html { scroll-behavior: auto; }
body { margin: 0; background: #f1f1f1; color: var(--ink); font: 16px/1.65 "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", sans-serif; }
a { color: inherit; text-underline-offset: 4px; }
a:hover { text-decoration-thickness: 2px; }
a:focus-visible, [tabindex]:focus-visible { outline: 3px solid var(--accent); outline-offset: 4px; }
[hidden] { display: none !important; }
header, main, .reader-nav, .global-scenes, footer { margin: 0 auto; max-width: 1456px; padding-left: 32px; padding-right: 32px; }
.page-header { padding-top: 24px; padding-bottom: 16px; }
.eyebrow, .subtle, .provenance, .frame-phase { color: var(--muted); }
.eyebrow { margin: 0 0 4px; font-size: 14px; letter-spacing: .08em; }
h1 { margin: 0; font-size: 18px; line-height: 1.5; font-weight: 650; }
h2 { font-size: 18px; line-height: 1.5; margin: 20px 0 10px; }
h3 { font-size: 18px; margin: 20px 0 10px; }
h4, h5, h6 { font-size: 17px; margin: 18px 0 8px; }
p { margin: 8px 0 16px; }
.scope { display: inline-block; border: 1px solid #777; background: #fff; padding: 5px 12px; margin-top: 12px; font-weight: 600; }
.provenance { font-size: 14px; margin: 12px 0 0; overflow-wrap: anywhere; }
.provenance code { font-size: 13px; }
.reader-nav { display: flex; gap: 8px; padding-top: 6px; padding-bottom: 8px; }
.reader-nav a { display: block; text-decoration: none; padding: 9px 20px; border: 1px solid transparent; }
.reader-nav a[aria-current="page"] { border-color: var(--accent); color: var(--accent); background: #fff; font-weight: 600; }
.global-scenes { padding-top: 8px; padding-bottom: 16px; display: flex; flex-wrap: wrap; align-items: center; gap: 8px 20px; font-size: 14px; }
.global-scenes span { color: var(--muted); }
.global-scenes a[aria-current="true"] { color: var(--accent); font-weight: 600; }
main { padding-bottom: 32px; }
.panel { padding: 24px; border: 1px solid var(--line); background: #fff; }
.panel > h2:first-child { margin-top: 0; }
.diagram-scroll, .frame-scroll, .table-scroll { overflow-x: auto; }
.diagram-scroll { border: 1px solid #ddd; background: #fafafa; }
.scene-graph { display: block; margin: auto; font-family: inherit; fill: var(--ink); }
.scene-node:hover { stroke-width: 3px; }
.scene-links { display: grid; grid-template-columns: repeat(3, minmax(260px, 1fr)); gap: 16px; margin: 24px 0; }
.scene-summary { border: 1px solid var(--line); padding: 16px; }
.scene-summary h3 { margin: 0 0 8px; }
.scene-summary p { font-size: 14px; margin: 8px 0; }
.scene-summary nav { display: flex; gap: 16px; font-size: 14px; }
table { border-collapse: collapse; width: 100%; font-size: 15px; line-height: 1.7; }
th, td { border: 1px solid var(--line); padding: 12px 14px; text-align: left; vertical-align: top; min-width: 105px; overflow-wrap: anywhere; }
th { background: #ececec; font-weight: 600; }
tbody tr:nth-child(even) { background: #fafafa; }
.table-scroll { margin: 16px 0 24px; }
.frame-picker { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 24px; }
.frame-picker a { padding: 7px 12px; border: 1px solid var(--line); text-decoration: none; font-size: 14px; background: #f7f7f7; }
.frame-picker a[aria-current="true"] { border-color: var(--accent); color: var(--accent); background: #fff; }
.frame-heading { padding: 0; max-width: none; margin: 0 0 16px; }
.frame-heading h2 { margin: 0 0 4px; }
.frame-heading p { margin: 0 0 8px; }
.frame-heading nav { display: flex; gap: 20px; font-size: 14px; }
.frame-phase { font-size: 14px; }
.wireframe { display: block; flex: none; font-family: inherit; fill: #202020; }
.frame-scroll { padding-bottom: 8px; }
.frame-notes { margin: 18px 0 0; border-top: 1px solid var(--line); padding-top: 6px; }
.frame-notes h3 { margin: 8px 0; }
.frame-notes ul { margin: 6px 0 0; padding-left: 24px; font-size: 15px; }
.toc { padding: 16px 20px; border: 1px solid var(--line); background: #fafafa; margin: 0 0 32px; }
.toc h3 { margin-top: 0; }
.toc ul { list-style: none; margin: 0; padding: 0; }
.toc li { margin: 5px 0; }
.toc li[data-level="2"] { padding-left: 20px; }
.toc li[data-level="3"], .toc li[data-level="4"] { padding-left: 40px; }
.specification { font-size: 16px; }
.specification h2, .specification h3 { border-bottom: 1px solid var(--line); padding-bottom: 8px; margin-top: 36px; scroll-margin-top: 16px; }
.specification li { margin: 7px 0; }
.specification code, .provenance code { background: #f0f0f0; padding: 1px 4px; overflow-wrap: anywhere; }
.specification pre { white-space: pre-wrap; overflow-wrap: anywhere; background: #f4f4f4; padding: 16px; font-size: 14px; }
.specification blockquote { border-left: 3px solid #999; padding: 4px 20px; margin-left: 0; background: #fafafa; }
footer { color: var(--muted); font-size: 14px; padding-bottom: 28px; }
"""


SCRIPT = r"""
(() => {
  'use strict';
  const frames = Array.from(document.querySelectorAll('[data-frame]'));
  const panelNames = ['overview', 'frames', 'spec'];
  let selectedFrame = frames[0];
  function route() {
    const raw = location.hash.slice(1);
    let hash;
    try { hash = decodeURIComponent(raw); } catch { hash = 'overview'; }
    let panel = 'overview';
    if (hash.startsWith('frame-')) {
      selectedFrame = frames.find(frame => frame.dataset.frame === hash.slice(6)) || selectedFrame;
      panel = 'frames';
    } else if (hash.startsWith('scene-')) {
      selectedFrame = frames.find(frame => frame.dataset.scene === hash.slice(6)) || selectedFrame;
      panel = 'frames';
    } else if (hash === 'frames') {
      panel = 'frames';
    } else if (hash === 'spec' || hash.startsWith('spec-')) {
      panel = 'spec';
    }
    for (const name of panelNames) {
      document.getElementById(name + '-panel').hidden = name !== panel;
      const tab = document.querySelector('[data-tab="' + name + '"]');
      if (name === panel) tab.setAttribute('aria-current', 'page');
      else tab.removeAttribute('aria-current');
    }
    for (const frame of frames) frame.hidden = frame !== selectedFrame;
    for (const link of document.querySelectorAll('[data-frame-link]')) {
      if (link.dataset.frameLink === selectedFrame.dataset.frame) link.setAttribute('aria-current', 'true');
      else link.removeAttribute('aria-current');
    }
    for (const link of document.querySelectorAll('[data-scene-link]')) {
      if (panel === 'frames' && link.dataset.sceneLink === selectedFrame.dataset.scene) link.setAttribute('aria-current', 'true');
      else link.removeAttribute('aria-current');
    }
    requestAnimationFrame(() => {
      const destination = document.getElementById(hash);
      if (destination && (hash.startsWith('spec-') || hash.startsWith('relationship-') || hash.startsWith('frame-'))) {
        destination.scrollIntoView({block: 'start'});
      } else if (hash.startsWith('scene-')) {
        selectedFrame.scrollIntoView({block: 'start'});
      } else {
        window.scrollTo({top: 0, left: 0});
      }
    });
  }
  window.addEventListener('hashchange', route);
  if (!location.hash) location.replace('#overview');
  route();
})();
"""


def build_html(data: dict, prose: str, source: Path, digest: str) -> str:
    markdown = Markdown(prose, data["scenes"])
    specification = markdown.render(prose)
    scenes = {scene["id"]: scene for scene in data["scenes"]}
    try:
        source_name = source.relative_to(ROOT).as_posix()
    except ValueError:
        source_name = source.as_posix()
    generated = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    navigation = "".join(f'<a href="#scene-{escaped(scene["id"])}" data-scene-link="{escaped(scene["id"])}">{escaped(scene["title"])}</a>' for scene in data["scenes"])
    cards: list[str] = []
    for scene in data["scenes"]:
        count = sum(frame["scene"] == scene["id"] for frame in data["wireframes"])
        cards.append(f'<article class="scene-summary"><h3>{escaped(scene["title"])}</h3><p>{escaped(scene["subtitle"])}</p><nav><a href="#scene-{escaped(scene["id"])}">查看 {count} 张线框</a><a href="{escaped(markdown.scene_anchor(scene))}">相关正文</a></nav></article>')
    relationships = []
    for index, link in enumerate(data["links"]):
        relationships.append(f'<tr id="relationship-{index + 1}"><td>{index + 1}</td><td><a href="#scene-{escaped(link["from"])}">{escaped(scenes[link["from"]]["title"])}</a></td><td><a href="#scene-{escaped(link["to"])}">{escaped(scenes[link["to"]]["title"])}</a></td><td>{escaped(link["label"])}</td><td>{escaped(link["type"])}</td></tr>')
    frame_links, articles = [], []
    for frame in data["wireframes"]:
        frame_id = escaped(frame["id"])
        frame_links.append(f'<a href="#frame-{frame_id}" data-frame-link="{frame_id}">{escaped(frame["title"])}</a>')
        notes = "".join(f"<li>{markdown.inline(note)}</li>" for note in frame["notes"])
        articles.append(f'''<article id="frame-{frame_id}" data-frame="{frame_id}" data-scene="{escaped(frame["scene"])}" hidden>
<header class="frame-heading"><p class="frame-phase">{escaped(scenes[frame["scene"]]["title"])} · {escaped(frame["phase"])}</p><h2>{escaped(frame["title"])}</h2><p class="subtle">结构提案 / 示意，非美术稿或运行游戏 · 固定逻辑画布 1280 × 720</p><nav><a href="#overview">返回场景总图</a><a href="{escaped(markdown.scene_anchor(scenes[frame["scene"]]))}">阅读相关正文</a></nav></header>
<div class="frame-scroll" tabindex="0">{wireframe_svg(frame)}</div>
<aside class="frame-notes"><h3>审阅说明（画面外）</h3><ul>{notes}</ul></aside></article>''')
    contents = "".join(f'<li data-level="{level}"><a href="#{escaped(anchor)}">{markdown.inline(title)}</a></li>' for level, title, anchor in markdown.headings)
    return f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'">
<meta name="source-sha256" content="{digest}"><meta name="source-path" content="{escaped(source_name)}">
<title>{escaped(data["title"])} · 结构阅读器</title><style>{STYLE}</style></head>
<body><header class="page-header"><p class="eyebrow">全局 UI 结构审阅 · 离线文档</p><h1>{escaped(data["title"])}</h1>
<div class="scope" role="note">结构提案 / 示意，非美术稿或运行游戏</div>
<p class="provenance">唯一来源：<code>{escaped(source_name)}</code> · 生成时间：{generated}<br>源文件 SHA256：<code>{digest}</code></p></header>
<nav class="reader-nav" aria-label="阅读器页面"><a href="#overview" data-tab="overview">总图</a><a href="#frames" data-tab="frames">场景线框</a><a href="#spec" data-tab="spec">信息与决策正文</a></nav>
<nav class="global-scenes" aria-label="场景跳转"><span>场景：</span>{navigation}</nav>
<main><section id="overview-panel" class="panel"><h2>场景与导航总图</h2><p class="subtle">{len(scenes)} 个场景 · {len(data["wireframes"])} 张线框 · {len(data["links"])} 条导航关系。选择场景可查看线框；箭头编号对应下表。节点位置仅用于文档排版。</p>
<div class="diagram-scroll" tabindex="0">{graph_svg(data)}</div><div class="scene-links">{"".join(cards)}</div>
<h3>导航关系</h3><div class="table-scroll" tabindex="0"><table><thead><tr><th>编号</th><th>从</th><th>到</th><th>条件 / 动作</th><th>关系类型（源文）</th></tr></thead><tbody>{"".join(relationships)}</tbody></table></div></section>
<section id="frames-panel" class="panel" hidden><nav class="frame-picker" aria-label="线框选择">{"".join(frame_links)}</nav>{"".join(articles)}</section>
<section id="spec-panel" class="panel" hidden><h2>信息与决策正文</h2><p class="subtle">以下内容直接由源文件本轮有效设计段生成。场景图和线框的机器描述用于绘图，不重复为第二份正文。</p><aside class="toc"><h3>目录</h3><ul>{contents}</ul></aside><article class="specification">{specification}</article></section></main>
<footer>此阅读器只切换审阅材料；不连接游戏状态、不执行行动。修改唯一源后重新生成本页。</footer>
<script>{SCRIPT}</script></body></html>
'''


def load_source(path: Path) -> tuple[dict, str, str]:
    raw = path.read_bytes()
    source = raw.decode("utf-8-sig").replace("\r\n", "\n")
    require(source.count(START) == 1 and source.count(END) == 1,
            "Expected exactly one ui-structure:start and ui-structure:end marker; authoritative source is not ready")
    start = source.index(START) + len(START)
    end = source.index(END)
    require(end > start, "ui-structure:end must follow ui-structure:start")
    section = source[start:end].strip()
    fences = list(STRUCTURE_FENCE.finditer(section))
    require(len(fences) == 1, "Expected exactly one fenced ui-structure JSON block inside the markers")
    try:
        payload = json.loads(fences[0][1])
    except json.JSONDecodeError as error:
        raise SourceError(f"Invalid ui-structure JSON: {error}") from error
    data = validate_structure(payload)
    prose = section[:fences[0].start()] + section[fences[0].end():]
    require(bool(prose.strip()), "The marked source needs human-readable design prose")
    return data, prose, hashlib.sha256(raw).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "docs/specs/ui-interaction.md")
    parser.add_argument("--output", type=Path, default=ROOT / "docs/game-state/ui-structure.html")
    parser.add_argument("--check", action="store_true", help="Validate source and rendering without writing output")
    args = parser.parse_args()
    try:
        source = args.source.resolve()
        output = args.output.resolve()
        require(source != output, "Output must not overwrite the authoritative source")
        data, prose, digest = load_source(source)
        rendered = build_html(data, prose, source, digest)
        if not args.check:
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(rendered, encoding="utf-8", newline="\n")
        action = "Validated" if args.check else f"Generated {output}"
        print(f"{action}: {len(data['scenes'])} scenes, {len(data['wireframes'])} frames, {len(data['links'])} links")
        print(f"Source SHA256: {digest}")
        return 0
    except (OSError, UnicodeError, SourceError) as error:
        print(f"ui-structure: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
