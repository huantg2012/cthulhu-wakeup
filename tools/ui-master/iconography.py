"""Editable etched emblems for the Echoes UI boards.

The symbols describe existing actions and information; they are not gameplay
assets or a second source of game data. Each call owns its paint-server IDs, so
many copies may safely share a document. Resource defaults keep their identity
colors; pass ``muted`` for an unavailable state.
"""
from __future__ import annotations

from itertools import count
from math import isfinite
from uuid import uuid4

# Highlight / middle metal / patina / edge / recess. Gradients are intentionally
# restrained: relief is carried by silhouettes, openings and engraved strokes.
_PALETTES = {
    "gold": ("#f1dfb6", "#bc9a58", "#6f522d", "#f4e5c3", "#493d2b"),
    "bone": ("#f0e7ce", "#c4b99b", "#786e56", "#fff3d7", "#514b3c"),
    "cyan": ("#b4e4e2", "#57a7ad", "#285d6b", "#d3f4ed", "#173d47"),
    "violet": ("#d9c2ec", "#a083bb", "#584568", "#ecdbf9", "#3b2d4a"),
    "red": ("#e9b5a1", "#bb6b57", "#68382d", "#f5d0b7", "#472c26"),
    "muted": ("#abb0a4", "#7d8379", "#4d554f", "#bdc0b0", "#353d38"),
}
_RESOURCE_TONES = {"whispers": "cyan", "faith": "gold", "awakening": "violet"}
_UID_PREFIX = "echoes-" + uuid4().hex[:12]
_IDS = count(1)


def _metal(path: str) -> str:
    return f'<path d="{path}" fill="@metal" stroke="@cut" stroke-width="1.6" stroke-linejoin="round"/>'


def _edge(path: str, width: float = 2.1) -> str:
    return f'<path d="{path}" fill="none" stroke="@edge" stroke-width="{width:g}" stroke-linecap="round" stroke-linejoin="round"/>'


def _etch(path: str, width: float = 1.8) -> str:
    return f'<path d="{path}" fill="none" stroke="@cut" stroke-width="{width:g}" stroke-linecap="round" stroke-linejoin="round"/>'


def _hole(path: str) -> str:
    return f'<path d="{path}" fill="#0a1115" stroke="@edge" stroke-width="1.1" stroke-linejoin="round"/>'


def _bead(x: float, y: float, radius: float) -> str:
    return f'<circle cx="{x:g}" cy="{y:g}" r="{radius:g}" fill="@metal" stroke="@edge" stroke-width="1.1"/>'


# 64-unit drawings. Broad gold masses survive at 32 px; details are subordinate.
_GLYPHS = {
    "listen": (
        _metal("M5 32Q17 17 32 18Q47 17 59 32Q47 47 32 46Q17 47 5 32Z")
        + _hole("M11 32Q23 23 32 24Q43 23 53 32Q42 41 32 40Q21 41 11 32Z")
        + _bead(32, 32, 8)
        + _hole("M32 25Q36 31 32 39Q28 32 32 25Z")
        + _edge("M13 18Q20 11 29 11M35 53Q44 53 51 46M32 6V12M32 52V58M6 23L11 26M53 38L58 41", 2.2)
        + _etch("M18 21L22 24M43 40L47 43")
    ),
    "dream": (
        _metal("M42 7C21 4 9 19 12 37C15 56 39 60 53 45C38 50 23 43 22 30C21 19 29 12 42 7Z")
        + _edge("M19 42C27 52 44 48 48 37C52 26 41 18 33 23C24 29 30 40 37 37C43 35 39 29 36 31", 2.9)
        + _etch("M18 19Q12 31 19 42")
        + _metal("M50 8L52 14L58 16L52 18L50 24L48 18L42 16L48 14Z")
        + _bead(9, 50, 1.7)
    ),
    "oracle": (
        _metal("M20 9Q31 4 42 9L43 33Q40 44 32 52Q24 45 20 34Z")
        + _hole("M23 20L30 23L24 26ZM34 23L41 20L40 26Z")
        + _etch("M31 14L30 31L34 33M27 40Q32 37 37 40")
        + _metal("M31 43L34 43L34 58L31 61L29 57Z")
        + _edge("M13 20Q6 30 13 40M49 20Q56 30 49 40M7 15Q-1 30 7 45M55 15Q63 30 55 45", 2.8)
        + _edge("M24 11L24 16M38 10L39 15", 1.5)
    ),
    "bestow": (
        _metal("M32 4C30 12 21 19 22 27C23 40 42 40 43 27C44 19 35 12 32 4Z")
        + _hole("M32 15C31 21 28 23 28 28Q32 35 36 28C37 23 33 20 32 15Z")
        + _metal("M6 34L13 38L21 49L30 47L31 40L34 40L35 47L44 49L52 38L58 34L54 48L42 58L22 58L10 48Z")
        + _edge("M13 40L23 53L31 52M51 40L41 53L35 52", 1.7)
        + _bead(32, 59, 1.5)
    ),
    "appoint": (
        _metal("M10 31L13 48Q32 55 51 48L54 31L43 37L32 24L21 37Z")
        + _metal("M28 23C23 16 32 12 31 4C42 13 40 21 35 26Z")
        + _metal("M13 29C7 25 15 20 14 14C23 23 20 28 17 31ZM47 29C41 25 49 20 49 14C58 23 54 28 51 31Z")
        + _edge("M17 46Q32 51 47 46M14 53Q32 59 50 53", 2.2)
        + _hole("M32 33L37 40L32 46L27 40Z")
        + _etch("M18 35L20 44M46 35L44 44")
    ),
    "sacrifice": (
        _metal("M42 5L51 9L29 35L25 34L24 29Z")
        + _edge("M43 9L28 29", 1.5)
        + _metal("M19 28L33 39L30 43L16 32ZM19 36L25 41L17 53L11 48Z")
        + _metal("M32 41L57 41Q56 53 46 56V60H39V56Q30 53 28 46Z")
        + _edge("M31 44H53M36 53H49", 1.6)
        + _metal("M40 25Q36 31 40 34Q45 32 40 25ZM49 29Q46 35 49 37Q53 35 49 29Z")
    ),
    "breach": (
        _metal("M8 51L8 23L18 9L29 6L26 15L20 17L15 25V51ZM39 7L49 13L56 24V51H49V26L42 20L43 15Z")
        + _metal("M34 3L26 24L33 28L24 47L31 43L28 61L42 35L35 32L43 17L34 21Z")
        + _edge("M10 53H20M45 53H57M13 22L19 13M46 17L52 25", 1.8)
        + _etch("M33 12L31 24L37 26M30 47L36 37", 1.4)
    ),
    "seed": (
        _metal("M28 36L30 22H34L36 36L41 48L55 56L41 55L33 49L34 60H29L29 49L21 55L8 56L22 48Z")
        + _metal("M31 22C17 23 18 8 30 5C41 8 42 20 31 22ZM23 34C9 34 7 20 14 16C25 18 31 29 23 34ZM41 34C33 29 39 18 50 16C57 20 55 34 41 34Z")
        + _edge("M30 9Q27 15 29 18M13 20Q14 26 20 29M50 20Q48 27 43 29", 1.7)
        + _etch("M32 29V45M22 48L18 52M42 48L47 52", 2)
        + _bead(8, 10, 1.5) + _bead(55, 8, 1.5)
    ),
    "anchor": (
        _metal("M28 19H36L35 31H44V36H35L34 49Q46 46 49 36L45 38L47 28L57 38L53 38Q51 55 32 60Q13 55 11 38L7 38L17 28L19 38L15 36Q18 46 30 49L29 36H20V31H29Z")
        + _bead(32, 13, 8)
        + _hole("M32 8A5 5 0 1 0 32.1 8Z")
        + _edge("M32 23V49M17 42Q21 50 28 53M47 42Q43 50 36 53", 1.7)
    ),
    "veil": (
        _metal("M8 50Q15 24 32 7Q49 24 56 50L45 47L39 54L32 50L25 54L18 47Z")
        + _hole("M20 36Q32 25 44 36Q32 46 20 36Z")
        + _metal("M25 34Q32 30 39 34L35 39H29Z")
        + _edge("M17 41L13 49M25 21L18 32M39 21L46 32M48 41L52 49", 1.5)
        + _etch("M19 49L26 41M45 49L39 41M32 13V26", 2)
        + _metal("M7 14L10 18L7 22L4 18ZM56 12L59 16L56 20L53 16Z")
    ),
    "transfer": (
        _metal("M5 48V18L18 11L27 18V48H21V23L18 20L12 23V48ZM38 45V16L49 9L59 16V45H53V21L49 18L44 21V45Z")
        + _metal("M14 32H35V25L44 35L35 45V38H14Z")
        + _edge("M8 51H25M38 48H59M8 18L18 14L23 18M41 16L49 12L56 16", 1.5)
        + _etch("M18 34H35", 1.7)
        + _edge("M26 8L32 6L36 10M28 55L34 57L39 53", 1.8)
    ),
    "manifest": (
        _metal("M32 3L38 17L34 15V28H30V15L26 17Z")
        + _metal("M8 44L23 31L27 35L19 42L32 48L45 42L37 35L41 31L56 44L32 58Z")
        + _hole("M21 44L32 38L43 44L32 50Z")
        + _metal("M32 24L41 37L32 43L23 37Z")
        + _edge("M5 30L14 35M59 30L50 35M12 14L20 24M52 14L44 24M32 60V63", 2.4)
        + _edge("M9 51L18 55M55 51L46 55", 1.8)
        + _etch("M32 29V38", 1.6)
    ),
    "whispers": (
        _metal("M29 3C32 16 18 17 20 30C12 26 16 18 14 15C2 31 13 54 31 59C48 57 58 41 51 25C49 31 45 33 43 29C41 19 34 18 37 10L29 3Z")
        + _hole("M30 25C34 32 25 34 28 41C23 39 23 35 23 33C19 43 28 50 33 51C44 46 43 38 37 32C38 41 31 43 32 36C34 32 32 28 30 25Z")
        + _edge("M19 21Q14 33 21 42M41 45Q45 39 43 33", 1.7)
    ),
    "faith": (
        _metal("M33 4C35 17 45 18 44 30C48 29 48 24 49 21C61 40 46 57 32 59C16 57 6 44 12 31C16 35 20 32 21 25C21 15 30 14 33 4Z")
        + _hole("M32 25C30 32 23 35 24 42C24 52 40 52 41 42C41 36 35 34 32 25Z")
        + _metal("M32 35L37 43L32 49L27 43Z")
        + _edge("M17 36Q15 47 24 52M37 17Q43 23 40 29", 1.8)
    ),
    "awakening": (
        _metal("M4 32Q17 18 32 18Q47 18 60 32Q47 46 32 46Q17 46 4 32Z")
        + _hole("M11 32Q22 24 32 24Q42 24 53 32Q42 40 32 40Q22 40 11 32Z")
        + _bead(32, 32, 9)
        + _hole("M32 24L35 32L32 41L29 32Z")
        + _metal("M32 4L36 12L32 17L28 12ZM32 47L36 52L32 60L28 52Z")
        + _edge("M10 17L15 21M54 17L49 21M10 47L15 43M54 47L49 43", 1.9)
    ),
    "world": (
        _metal("M5 43L19 34L29 37L43 28L58 37L53 48L34 59L13 53Z")
        + _metal("M15 32L18 16L24 16L27 31ZM30 33L35 9L41 9L45 29Z")
        + _edge("M9 43L26 49L40 40L54 38M16 48L16 51M33 51L34 56M37 13L34 26", 1.6)
        + _etch("M24 18L22 29M41 13L39 26M48 44L44 50", 1.8)
        + _bead(10, 17, 1.6) + _bead(54, 14, 1.6)
    ),
    "cult": (
        _metal("M22 31L32 15L42 31L38 50H26Z")
        + _hole("M32 23L36 31L32 35L28 31Z")
        + _metal("M5 42L14 28L24 42L21 55H9ZM40 42L50 28L59 42L55 55H43Z")
        + _hole("M14 35L17 41L14 44L11 41ZM50 35L53 41L50 44L47 41Z")
        + _edge("M29 39L28 47M35 39L36 47M8 59H56", 1.8)
        + _metal("M32 3L35 7L32 11L29 7Z")
    ),
    "person": (
        _metal("M12 56L17 37L25 31L22 23L23 14L32 8L41 14L42 23L39 31L47 37L52 56Z")
        + _hole("M26 19L32 14L38 19L37 27L32 31L27 27Z")
        + _edge("M22 40L20 52M42 40L44 52M28 36L32 43L36 36", 1.8)
        + _etch("M32 43V54M17 55H47", 2)
    ),
    "prayer": (
        _metal("M28 10L32 6L36 10L35 32L45 44L41 56H23L19 44L29 32Z")
        + _metal("M16 29L22 34L25 42L21 48L11 38L8 23L12 20ZM48 29L42 34L39 42L43 48L53 38L56 23L52 20Z")
        + _edge("M32 13V36M24 52H40M13 29L16 38M51 29L48 38", 1.7)
        + _etch("M28 39L32 44L36 39", 2)
        + _edge("M13 10L18 14M51 10L46 14", 1.8)
    ),
    "barrier": (
        _metal("M12 10L32 5L52 10V32Q48 47 32 60Q16 47 12 32Z")
        + _hole("M19 16L32 12L45 16V31Q41 42 32 51Q23 42 19 31Z")
        + _metal("M29 17H35V43L32 47L29 43Z")
        + _edge("M16 12V31Q19 41 27 49M48 13V31", 1.3)
    ),
    "pollution": (
        _metal("M29 25C15 19 9 25 14 31C17 35 23 32 23 36C23 44 10 44 7 35C1 18 20 11 32 21C37 17 33 12 27 12L28 5C44 3 48 24 37 28C46 28 53 18 57 25C64 37 46 47 39 38C43 49 32 60 23 55L26 48C33 51 39 42 32 37C26 36 24 29 29 25Z")
        + _hole("M30 27Q37 24 38 31Q37 38 31 36Q26 33 30 27Z")
        + _edge("M11 28Q8 20 18 20M34 8Q42 14 38 21M53 28Q56 34 47 36M28 52Q35 51 35 44", 1.6)
    ),
    "alert": (
        _metal("M4 32Q17 18 31 19Q45 18 59 32Q45 47 31 45Q17 46 4 32Z")
        + _hole("M12 32Q23 25 31 25Q41 25 51 32Q41 39 31 39Q21 39 12 32Z")
        + _metal("M29 25H34L33 34H30ZM30 36H33V39H30Z")
        + _edge("M8 16L14 21M19 7L23 16M32 3V14M45 7L41 16M56 16L50 21M17 49L13 54M32 49V59M47 49L51 54", 2.6)
    ),
    "stability": (
        _metal("M5 22L32 7L59 22L55 27H9ZM9 51H55L59 58H5Z")
        + _metal("M13 29H22V48H13ZM28 29H36V48H28ZM43 29H52V48H43Z")
        + _edge("M12 23H52M16 31V46M31 31V46M46 31V46M10 54H54", 1.5)
        + _etch("M21 20L32 13L43 20", 1.8)
    ),
    "history": (
        _metal("M6 12Q21 8 32 16Q43 8 58 12V52Q43 48 32 56Q21 48 6 52Z")
        + _hole("M12 18Q22 17 28 21V46Q21 42 12 44ZM36 21Q43 17 52 18V44Q43 42 36 46Z")
        + _edge("M32 19V51M15 25Q21 24 25 27M15 32Q21 31 25 34M39 27Q44 24 49 25M39 34Q44 31 49 32", 1.8)
        + _metal("M43 8H48V23L45 20L42 24Z")
    ),
    "maintenance": (
        _metal("M12 30H52L48 43L36 50V55H44V60H20V55H28V50L16 43Z")
        + _edge("M15 34H49M23 43L28 46M41 43L36 46", 1.8)
        + _metal("M32 4C31 11 24 15 25 21C25 30 39 30 39 21C39 15 33 11 32 4Z")
        + _hole("M32 14L35 21L32 24L29 21Z")
        + _edge("M9 20L14 23M55 20L50 23", 2)
    ),
    "event": (
        _metal("M24 8H40L38 23L47 31L44 52H20L17 31L26 23Z")
        + _hole("M29 14H35L33 25L39 33L37 43H27L25 33L31 25Z")
        + _metal("M26 54H38V59H26Z")
        + _edge("M8 14L16 21M56 14L48 21M4 34H12M60 34H52M9 52L16 45M55 52L48 45", 2.4)
        + _bead(32, 47, 2)
    ),
    "search": (
        _metal("M27 6A20 20 0 1 0 40 41L52 58L59 51L43 38A20 20 0 0 0 27 6Z")
        + _hole("M27 13A13 13 0 1 0 27.1 13Z")
        + _edge("M17 20Q20 15 27 16M45 43L53 53", 2)
        + _etch("M43 42L47 39", 1.8)
    ),
    "close": (
        _metal("M16 8L32 25L48 8L56 16L39 32L56 48L48 56L32 39L16 56L8 48L25 32L8 16Z")
        + _edge("M16 14L31 30M48 14L34 29M14 48L28 35M48 50L35 37", 1.6)
        + _hole("M32 28L36 32L32 36L28 32Z")
    ),
    "back": (
        _metal("M31 8L8 32L31 56L37 49L21 35H56V28H21L37 15Z")
        + _edge("M29 15L14 31M25 31H51M19 37L29 48", 1.6)
        + _etch("M53 29V34", 1.6)
    ),
    "shallow": (
        _metal("M32 6C31 14 22 22 23 30C24 42 41 42 42 30C42 23 35 14 32 6Z")
        + _hole("M32 18C31 23 28 28 28 31Q32 37 36 31C36 27 34 23 32 18Z")
        + _edge("M18 44Q32 53 46 44M10 49Q32 63 54 49", 2.7)
    ),
    "deep": (
        _metal("M32 4L42 18L37 16V36H44L32 52L20 36H27V16L22 18Z")
        + _edge("M17 24Q7 33 13 42M47 24Q57 33 51 42M9 48Q32 65 55 48", 2.5)
        + _edge("M32 13V36", 1.8)
        + _etch("M26 38L32 46L38 38", 1.5)
    ),
    "relatives": (
        _metal("M6 51L10 34L18 28L26 34L29 51ZM35 51L38 34L46 28L54 34L58 51Z")
        + _bead(18, 20, 8) + _bead(46, 20, 8)
        + _edge("M25 43Q32 36 39 43M25 48Q32 53 39 48", 3)
        + _etch("M14 38L12 46M50 38L52 46", 1.8)
        + _metal("M32 6L35 10L32 14L29 10Z")
    ),
    "ritual": (
        _metal("M10 36H54L49 44H15ZM15 46H23V54H41V46H49V59H15Z")
        + _metal("M17 20H22V33H17ZM42 20H47V33H42ZM29 13H35V33H29Z")
        + _metal("M19 7C12 15 17 21 21 18C26 15 21 11 19 7ZM45 7C38 15 43 21 47 18C52 15 47 11 45 7ZM32 1C25 9 30 15 34 12C39 9 34 5 32 1Z")
        + _edge("M15 39H49M19 49V56M45 49V56", 1.5)
    ),
    "evidence": (
        _metal("M12 5H40L51 16V57H12Z")
        + _hole("M18 12H36V21H45V51H18Z")
        + _metal("M39 5V17H51Z")
        + _edge("M23 25H38M23 31H34M23 37H30", 2)
        + _metal("M37 35L43 38L44 45L39 49L33 46L31 40Z")
        + _hole("M37 39L40 41L38 45L35 43Z")
        + _edge("M14 8V53", 1.3)
    ),
}

ICON_NAMES = tuple(_GLYPHS)


def icon(name: str, size: int | float = 32, tone: str = "gold") -> str:
    """Return a self-contained SVG emblem for insertion next to a text label.

    ``size`` is CSS pixels. Supported tones: gold, cyan, violet, red, muted,
    bone. The default maps whispers/faith/awakening to cyan/gold/violet.
    All paint-server and filter IDs are unique for every returned SVG.
    """
    if name not in _GLYPHS:
        raise ValueError(f"Unknown Echoes icon {name!r}; expected one of {ICON_NAMES!r}")
    if tone not in _PALETTES:
        raise ValueError(f"Unknown Echoes icon tone {tone!r}")
    if isinstance(size, bool) or not isinstance(size, (int, float)) or not isfinite(size) or size <= 0:
        raise ValueError("Icon size must be a positive finite pixel number")
    actual_tone = _RESOURCE_TONES.get(name, tone) if tone == "gold" else tone
    light, middle, dark, edge, cut = _PALETTES[actual_tone]
    uid = f"{_UID_PREFIX}-{next(_IDS)}"
    content = (_GLYPHS[name].replace("@metal", f"url(#{uid}-metal)")
               .replace("@edge", f"url(#{uid}-edge)").replace("@cut", cut))
    dimension = f"{size:g}"
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" '
        f'width="{dimension}" height="{dimension}" class="sigil etched-icon" '
        f'data-icon="{name}" data-tone="{actual_tone}" aria-hidden="true" focusable="false">'
        '<defs>'
        f'<linearGradient id="{uid}-metal" x1="12%" y1="0%" x2="83%" y2="100%">'
        f'<stop offset="0" stop-color="{light}"/>'
        f'<stop offset=".42" stop-color="{middle}"/>'
        f'<stop offset=".7" stop-color="{light}"/>'
        f'<stop offset="1" stop-color="{dark}"/></linearGradient>'
        f'<linearGradient id="{uid}-edge" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{edge}"/>'
        f'<stop offset="1" stop-color="{middle}"/></linearGradient>'
        f'<filter id="{uid}-relief" x="-15%" y="-15%" width="130%" height="140%" color-interpolation-filters="sRGB">'
        '<feDropShadow dx="0" dy="1.2" stdDeviation=".7" flood-color="#00080b" flood-opacity=".8"/>'
        '</filter></defs>'
        f'<g filter="url(#{uid}-relief)">{content}</g></svg>'
    )
