"""Bounded regression checks on native captures, not an aesthetic score."""
import json
from pathlib import Path
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/art/visual-generation/palette-study/evidence"
regions = json.loads((EVIDENCE / "regions.json").read_text())
images = [Image.open(EVIDENCE / f"worlds-{i}.png").convert("RGB") for i in range(2)]
anchor = Image.open(EVIDENCE.parent / "gray-paper-review/worlds-1.png").convert("RGB")
pixels = [list(im.crop(regions["paper"]).get_flattened_data()) for im in images]
paper = [i for i, rgb in enumerate(pixels[0]) if max(rgb) < 110]
primary = [i for i, (r, g, b) in enumerate(pixels[0]) if r > 205 and g > 205 and b > 180]
secondary = [i for i, (r, g, b) in enumerate(pixels[0]) if 172 <= r <= 186 and 181 <= g <= 198 and 160 <= b <= 180]
assert min(len(paper), len(primary), len(secondary)) > 30, "Missing native text / paper samples"


def luminance(rgb):
    linear = [(v / 255 / 12.92 if v / 255 <= .04045 else ((v / 255 + .055) / 1.055) ** 2.4) for v in rgb]
    return sum(v * w for v, w in zip(linear, (.2126, .7152, .0722)))


report = []
anchor_values = list(anchor.crop(regions["paper"]).get_flattened_data())
anchor_floor = median(luminance(anchor_values[i]) for i in paper)
anchor_background = median(luminance(rgb) for rgb in anchor.crop(regions["background"]).get_flattened_data())
anchor_separation = (anchor_floor+.05)/(anchor_background+.05)
for index, image in enumerate(images):
    values = pixels[index]
    ink = [values[i] for i in paper]
    brightness = sorted(sum(v*w for v, w in zip(rgb, (.2126,.7152,.0722)))/255 for rgb in ink)
    spread = brightness[int(len(brightness)*.9)] - brightness[int(len(brightness)*.1)]
    floor = median(luminance(rgb) for rgb in ink)
    background = median(luminance(rgb) for rgb in image.crop(regions["background"]).get_flattened_data())
    separation = (floor+.05)/(background+.05)
    text_light = {name: median(luminance(values[i]) for i in mask)
                  for name,mask in [("primary",primary),("secondary",secondary)]}
    contrast = {name: (max(floor,value)+.05)/(min(floor,value)+.05)
                for name,value in text_light.items()}
    art_exact = image.crop(regions["world_art"]).tobytes() == images[0].crop(regions["world_art"]).tobytes()
    if index:
        assert art_exact, "UI pigment changed original world illustration pixels"
        assert image.crop(regions["background"]).tobytes() == images[0].crop(regions["background"]).tobytes(), "Accepted background was recoloured"
        # The producer accepted separation in this anchor, not its aesthetics.
        # Preserve that measured visibility, with 10% room for material shading.
        assert floor >= anchor_floor*.90, "Card was substantially darkened from the separated-paper anchor"
        assert separation >= anchor_separation*.90, "Card/background separation regressed"
        assert contrast["primary"] >= 4.5 and contrast["secondary"] >= 4.5, "Text contrast regressed"
    report.append(dict(palette=index, original_art_exact=art_exact,
                       paper_brightness=round(median(brightness),4),
                       body_luminance_relative_to_anchor=round(floor/anchor_floor,3), grain_spread=round(spread,4),
                       card_background_contrast=round(separation,2),
                       contrast={k:round(v,2) for k,v in contrast.items()}))
table = [Image.open(EVIDENCE / f"table-{i}.png").convert("RGB") for i in range(2)]
assert len(regions["table_art"]) == 2, "Need both paper-style world and person evidence"
for bounds in regions["table_art"]:
    assert table[0].crop(bounds).tobytes() == table[1].crop(bounds).tobytes(), "Paper-style portrait RGB changed"
print(json.dumps({"worlds":report,"paper_style_world_and_person_exact":True,
                 "sampled_background_exact":True,
                 "scope":"Sampled card separation, text and portrait integrity only; not aesthetic approval."},ensure_ascii=False,indent=2))
