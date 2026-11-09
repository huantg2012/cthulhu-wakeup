extends RefCounted
## Bounds measured in the settled 1600 × 900 interaction-slice.html.
## DOM coordinates stay in the reference space until the native view boundary.
const SCALE := 0.8
const OVERVIEW_REALMS := [
	Rect2(436, 143, 708, 564),
	Rect2(1129.7, 143.4, 430.7, 343.1),
	Rect2(1152.3, 459.5, 395.3, 314.9),
]
const LOCAL_REALMS := [
	Rect2(188.6, -11.2, 896.8, 714.4),
	Rect2(48, 523, 236, 188),
	Rect2(1374, 528, 236, 188),
]
const OVERVIEW_CAPTIONS := [
	Rect2(647, 573, 437, 152),
	Rect2(1258, 405, 266, 93),
	Rect2(1270, 699, 244, 85),
]
const LOCAL_CAPTIONS := [
	Rect2(),
	Rect2(118, 676, 146, 51),
	Rect2(1444, 681, 146, 51),
]
const METRICS := Rect2(78, 322, 265, 40)
const PIN_ANCHOR := Vector2(725, 235)
const PIN_CULT := Vector2(387, 400)
const PIN_PRAYER := Vector2(945, 433)
const PIN_ACTIVITY := Vector2(630, 540)
const PIN_RELIC := Vector2(1054, 284)

static func box(bounds: Rect2) -> Rect2:
	return Rect2(bounds.position * SCALE, bounds.size * SCALE)

static func type_size(px: float) -> int:
	return roundi(px * SCALE)

# Settled scene and reading bounds from the locked sample.
const SCENE := Rect2(40, 145, 1520, 638)
const SCENE_HEADER := Rect2(78, 167, 1444, 38)
const STORY := Rect2(88, 246, 340, 458)
const PETITIONER := Rect2(490, 229, 365, 450)
const RESPONSE := Rect2(1053, 243, 465, 415)
const PEEK := Rect2(1101, 219, 450, 503)
const PICKER := Rect2(455, 272, 690, 411)
const CONTACT_FIELDS := Rect2(86, 269, 375, 414)
const CONTACT_RISK := Rect2(1163, 266, 352, 417)
const CONTACT_FOOT := Rect2(85, 704, 1430, 59)
const EVENT := Rect2(0, 85, 1600, 781)
const EVENT_ART := Rect2(125, 143, 380, 390)
const EVENT_COPY := Rect2(565, 251, 910, 270)
const EVENT_FOOT := Rect2(565, 530, 910, 60)
