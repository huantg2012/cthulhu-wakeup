class_name EData
extends RefCounted
## Static tables: art styles, planet archetypes, palettes, scene types.

const STYLES := [
	{"name": "暗黑厚涂", "en": "Dark Painterly", "desc": "油画笔触与厚重明暗，适合主视觉与宣传立绘",
		"bloom": 0.75, "grain": 0.05, "vig": 0.55, "rim": 0.7},
	{"name": "赛璐璐漫画", "en": "Cel Shading", "desc": "硬边明暗分层+描线，适合卡牌/二次元项目",
		"bloom": 0.55, "grain": 0.015, "vig": 0.35, "rim": 1.0},
	{"name": "古典铜版画", "en": "Engraving", "desc": "十九世纪天文图鉴式交叉排线，适合典籍/图鉴界面",
		"bloom": 0.25, "grain": 0.03, "vig": 0.3, "rim": 0.35},
	{"name": "低多边形", "en": "Low Poly", "desc": "平面着色多边形，适合独立/休闲风格与快速原型",
		"bloom": 0.55, "grain": 0.012, "vig": 0.4, "rim": 0.6},
	{"name": "复古像素", "en": "Pixel Art", "desc": "低分辨率抖动色阶，适合像素/复古向游戏",
		"bloom": 0.6, "grain": 0.0, "vig": 0.0, "rim": 0.8},
	{"name": "全息星图", "en": "Hologram", "desc": "单色全息投影与经纬网格，适合星图/UI/科幻终端",
		"bloom": 1.0, "grain": 0.035, "vig": 0.5, "rim": 0.5},
	{"name": "水彩手稿", "en": "Watercolor", "desc": "纸面晕染与墨线，适合调查员笔记/日记插图",
		"bloom": 0.3, "grain": 0.025, "vig": 0.35, "rim": 0.3},
	{"name": "怪奇杂志", "en": "Pulp Halftone", "desc": "二十年代廉价杂志网点印刷，适合复古海报/封面",
		"bloom": 0.45, "grain": 0.03, "vig": 0.45, "rim": 0.9},
]

const SCENE_TYPES := ["星球立绘", "星系图", "星际奇景"]

const COMPOSITIONS := ["自动", "居中", "三分构图", "巨构地平线", "远景", "日蚀逆光"]

const ASPECTS := [
	{"name": "16:9 横幅", "w": 1280, "h": 720},
	{"name": "1:1 方图", "w": 960, "h": 960},
	{"name": "3:4 竖幅", "w": 840, "h": 1120},
	{"name": "9:16 手机", "w": 720, "h": 1280},
	{"name": "21:9 宽银幕", "w": 1680, "h": 720},
]

const WONDERS := [
	{"name": "旧日星门", "en": "The Elder Gate"},
	{"name": "吞星之口", "en": "The Devouring Maw"},
	{"name": "虚空裂隙", "en": "The Rift Between"},
	{"name": "宇宙之眼", "en": "The Watcher Beyond"},
	{"name": "浮空遗迹", "en": "Drifting Ruins"},
	{"name": "星海巨触", "en": "Tendrils of the Deep Sky"},
]

const STAR_TYPES := [
	{"name": "燃烧之星", "en": "Burning Star"},
	{"name": "黑日", "en": "Black Sun"},
	{"name": "眼之星", "en": "Eye Star"},
	{"name": "苍白残星", "en": "Pale Remnant"},
	{"name": "黑洞", "en": "Singularity"},
]

# arch fields: name / en / pals (preferred palette ids) / sea / night / atmo / bump / eyes(default many-eyes)
const ARCHETYPES := [
	{"name": "溺亡之海", "en": "Drowned World", "pals": [0, 7, 5], "sea": 0.0, "night": 0.25, "atmo": 0.9, "bump": 1.0},
	{"name": "凝视之眼", "en": "Watcher World", "pals": [2, 1, 3, 4], "sea": 0.0, "night": 0.0, "atmo": 0.6, "bump": 1.2},
	{"name": "血肉之星", "en": "Flesh World", "pals": [2, 6, 3], "sea": 0.0, "night": 0.0, "atmo": 0.7, "bump": 1.4},
	{"name": "菌蚀冥星", "en": "Fungal World", "pals": [3, 5, 0], "sea": 0.0, "night": 0.0, "atmo": 0.5, "bump": 1.2},
	{"name": "炎狱之星", "en": "Infernal World", "pals": [6, 2, 1], "sea": 0.0, "night": 0.0, "atmo": 0.8, "bump": 1.2},
	{"name": "冷原", "en": "Frozen Plateau", "pals": [4, 8, 7], "sea": 0.0, "night": 0.0, "atmo": 0.55, "bump": 1.3},
	{"name": "星之彩", "en": "Colour from Beyond", "pals": [9, 3, 0], "sea": 0.0, "night": 0.0, "atmo": 1.0, "bump": 0.9},
	{"name": "黄衣王城", "en": "City of the Yellow King", "pals": [1, 6, 8], "sea": 0.0, "night": 0.8, "atmo": 0.7, "bump": 1.0},
	{"name": "混沌核心", "en": "Chaos Core", "pals": [3, 2, 9, 1], "sea": 0.0, "night": 0.0, "atmo": 1.1, "bump": 0.4},
	{"name": "古神之茧", "en": "Cocoon of the Old One", "pals": [5, 0, 3, 6], "sea": 0.0, "night": 0.0, "atmo": 0.8, "bump": 1.2},
	{"name": "骸骨之月", "en": "Ossuary Moon", "pals": [8, 4, 2], "sea": 0.0, "night": 0.0, "atmo": 0.0, "bump": 1.6},
]

const PALETTES := [
	{"name": "深渊翠", "c": ["04161a", "0b3b3d", "1f6b5e", "8c9a6a", "6bff9e"], "atmo": "3fd9a0", "iris": "e8d35a", "rim": "4dffb0",
		"neb": ["0a2a2e", "1f6b5e", "5a2a6e"], "cor": ["0a0010", "c040ff"], "star": ["fff4c8", "ffb050"]},
	{"name": "黄印金", "c": ["1a1206", "4a3410", "9a7322", "e6c55a", "ffe066"], "atmo": "f2c94c", "iris": "ffd23f", "rim": "ffcf5a",
		"neb": ["1e1408", "6b4a14", "7a2a1a"], "cor": ["120a00", "ff9020"], "star": ["fff8d0", "ffc040"]},
	{"name": "血月猩红", "c": ["1a0306", "4d0a12", "8f1d22", "d46a5a", "ff3b3b"], "atmo": "ff4d4d", "iris": "ffb03b", "rim": "ff5544",
		"neb": ["200508", "6e0f1a", "3a0f4a"], "cor": ["080002", "ff2020"], "star": ["ffe0c0", "ff4020"]},
	{"name": "幽紫秘仪", "c": ["0c0516", "2b0f45", "5e2a8a", "b58ad6", "e05cff"], "atmo": "b06bff", "iris": "7dffcf", "rim": "d77bff",
		"neb": ["10061c", "4a1a6e", "1a6b6b"], "cor": ["040010", "40ffd0"], "star": ["f0e0ff", "b060ff"]},
	{"name": "冷原霜灰", "c": ["0b0f14", "26323d", "56687a", "b8c4cc", "8fd7ff"], "atmo": "9cc9e6", "iris": "ff6b3d", "rim": "a8e0ff",
		"neb": ["0a0f18", "26405e", "3a2a4e"], "cor": ["020408", "60c0ff"], "star": ["e8f4ff", "80b0ff"]},
	{"name": "腐沼胆绿", "c": ["0e1206", "2c3610", "5d6e1f", "b5b46a", "c6ff3b"], "atmo": "a8d84a", "iris": "ff3b6b", "rim": "c8ff5a",
		"neb": ["0e1408", "3e4e12", "4e1a2e"], "cor": ["060800", "ff40a0"], "star": ["f8ffd0", "c0e040"]},
	{"name": "余烬熔金", "c": ["100604", "2e120a", "5a2a16", "a0705a", "ff8a2a"], "atmo": "ff7a3d", "iris": "fff07a", "rim": "ffae5a",
		"neb": ["160806", "5e2410", "2a0e3a"], "cor": ["0a0200", "ffd040"], "star": ["fff0c0", "ff7020"]},
	{"name": "深海靛蓝", "c": ["03071a", "0a1a45", "1d3f7a", "6a8fb8", "3bd6ff"], "atmo": "4d9fff", "iris": "ffe24d", "rim": "5ac8ff",
		"neb": ["050a20", "14306e", "3a1a5e"], "cor": ["000210", "40ffb0"], "star": ["e0f0ff", "6090ff"]},
	{"name": "骨白苍灰", "c": ["15130f", "3b362d", "7a7262", "d8cfb8", "ffe9b0"], "atmo": "d6c9a8", "iris": "c43030", "rim": "f0e0c0",
		"neb": ["0e0d0c", "3a342a", "4a2420"], "cor": ["080404", "ff3030"], "star": ["fffaf0", "d0c0a0"]},
	{"name": "异界虹彩", "c": ["08060f", "23305a", "6a4a9a", "d6a8e6", "b8ff6b"], "atmo": "c78bff", "iris": "6bffe0", "rim": "ff9ae6",
		"neb": ["0a0814", "3a2a6e", "1a5e4e"], "cor": ["020006", "80ff60"], "star": ["ffffff", "ff80e0"]},
]

const HOLO := Color("4de6ff")
const PAPER := Color("e3d5b4")
const INK := Color("2a1d14")


static func col(hex: String) -> Color:
	return Color(hex)


static func pal_colors(pid: int) -> Dictionary:
	var p: Dictionary = PALETTES[pid]
	var c: Array = p["c"]
	return {
		"c0": Color(c[0]), "c1": Color(c[1]), "c2": Color(c[2]), "c3": Color(c[3]), "c4": Color(c[4]),
		"atmo": Color(p["atmo"]), "iris": Color(p["iris"]), "rim": Color(p["rim"]),
		"n0": Color(p["neb"][0]), "n1": Color(p["neb"][1]), "n2": Color(p["neb"][2]),
		"cor_dark": Color(p["cor"][0]), "cor_glow": Color(p["cor"][1]),
		"star_hot": Color(p["star"][0]), "star_cool": Color(p["star"][1]),
	}
