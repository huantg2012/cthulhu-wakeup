extends RefCounted
const EData = preload("res://src/art_generation/source/data.gd")
## Procedural names and design notes for Cthulhu-mythos flavoured celestial bodies.

const SYL_A := ["Yu", "Zha", "Ngh", "Cth", "Ygg", "Xo", "Tsa", "Nyar", "Sho", "Gla", "Ithi", "Hy", "Bok", "Ub", "Aza", "Yog", "Shu", "Ghr", "Ny", "K'n", "Ry", "Tul", "Zo", "Vho", "Mnar", "Lng", "Thu", "Ul", "Dag", "Hast"]
const SYL_B := ["ggo", "th", "'ul", "lath", "oth", "ugg", "'tha", "rl", "nai", "gn", "aqua", "zh", "ruk", "yeh", "'oth", "orr", "uth", "'ngh", "ak", "lyeh", "ar", "osa", "ith", "un", "'ai", "ss", "og"]
const SYL_C := ["", "", "", "-Ka", "ia", "on", "'ath", "ur", "ix", "eth", "-Zho", "ul", "a", "oth", "ys"]

const CN_A := ["幽", "冥", "溺", "噬", "渊", "骸", "螺", "黯", "腐", "瞳", "蚀", "寂", "狂", "梦", "咒", "疫", "朽", "黄", "苍", "血"]
const CN_B := ["星", "域", "渊", "冕", "窟", "环", "庭", "海", "茧", "瞳", "城", "塔", "原", "宫", "门", "穴"]

const EPITHETS := {
	0: ["沉没诸城之母", "潮汐下的沉睡者", "拉莱耶的回声", "无光深海的摇篮"],
	1: ["永不闭合者", "注视万物之瞳", "群星间的窥视者", "梦境的监工"],
	2: ["蠕动的血肉苗床", "千口低语之巢", "搏动的胎膜", "无名之母的腹"],
	3: ["孢子的寂静王国", "犹格斯之菌园", "米·戈的采集场", "腐光之野"],
	4: ["燃烧的祭坛", "克图格亚的薪柴", "熔铸之喉", "永劫火刑场"],
	5: ["冷原的高台", "无月之脊", "古老者的冰墓", "风行者的足迹"],
	6: ["不可名状之色", "坠落的异彩", "超越光谱者", "枯萎之源"],
	7: ["卡尔克萨之影", "黄衣之王的宫阙", "哈利湖畔的废都", "双日下的戏台"],
	8: ["盲目痴愚的王座", "混沌的心核", "吹笛者的舞池", "原初的沸腾"],
	9: ["未诞之神", "沉眠于卵的旧日支配者", "星辰的胚胎", "破壳之前夜"],
	10: ["白骨坟冢", "被啃噬的卫星", "群星的墓碑", "朔月残骸"],
}

const HOOKS := [
	"天文台在其近日点记录到规律的低频脉冲，波形与人类脑电α波一致。",
	"所有长时间注视该天体的观测员都开始绘制同一幅图案。",
	"它在星图上的位置每晚偏移一度，但没有任何引力模型能解释其轨迹。",
	"探测器传回的最后一帧图像中，地表纹路拼出了发送者的名字。",
	"在某些古籍中，它被描述为“尚未被梦见的世界”。",
	"其光谱中存在一条不属于任何已知元素的谱线，研究者称之为“第十一种颜色”。",
	"宗教团体坚信，当它与三颗卫星连成一线时，“门”将会开启。",
	"地表的巨型纹路在千年间缓慢地改变，像是在书写。",
	"无线电静默区中偶尔能捕捉到它的“呼吸声”。",
	"它不反射任何雷达信号，仿佛那里只有一个形状完美的空洞。",
	"梦见它的人醒来后会使用一种未知语言低语数小时。",
	"殖民船队在抵达前三天集体改变了航向，日志中只留下一句：“它不希望我们看见。”",
]

const GAMEPLAY := {
	0: "适合作为水下遗迹探索关卡；理智值随深度衰减；关键道具：潜水钟、古神符石。",
	1: "可设计为“被注视”机制：处于视线内时隐身失效、理智持续下降。",
	2: "可作为生物型地牢；地形会再生/收缩；敌人为寄生体与组织守卫。",
	3: "孢子云影响视野与状态，可收集菌类作为炼金/改造素材。",
	4: "高温环境与周期性喷发事件，适合限时撤离类玩法。",
	5: "风暴与低温双重生存压力；冰层下封存着古老者遗物。",
	6: "颜色污染机制：接触者逐步“褪色”并获得异能，代价不可逆。",
	7: "城市剧场关卡：NPC 会在“演出”中逐渐疯狂；黄印为关键收集物。",
	8: "Boss 级天体；环境规则随回合随机重写，适合终局战场。",
	9: "倒计时型剧情节点：茧破之前必须完成封印仪式。",
	10: "墓地类采集点；骸骨中埋有远古文明的记录残片。",
}

const SYSTEM_HOOKS := [
	"这个星系的行星排布构成了一个古老的召唤阵，最后一颗行星的位置尚不确定。",
	"所有行星的自转方向都朝向同一处虚空——那里什么也看不见。",
	"星系中心的天体每隔 33 年会“眨眼”一次，期间星系内所有生命陷入同一个梦。",
	"天文学家发现，这些轨道的比例恰好对应《死灵之书》中的某段吟唱节奏。",
	"星系边缘漂浮着一层由碎骨与冰组成的云带，任何穿越者都会听到合唱。",
]

const WONDER_HOOKS := [
	"它不在任何一张星图上，但每个见过它的人都能准确画出它的形状。",
	"舰队的导航系统在接近时一致报错：“目标坐标存在于三个不同的时间。”",
	"在它附近，光会以奇怪的角度弯折，几何学不再可靠。",
	"它在等待。没有人知道它在等待什么，但所有人都确信，那东西快要到了。",
	"从它的方向传来的星光，比宇宙本身更古老。",
]


static func _cap(s: String) -> String:
	if s.is_empty():
		return s
	return s.substr(0, 1).to_upper() + s.substr(1)


static func gen_name(rng: RandomNumberGenerator) -> String:
	var n: String = SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()]
	if rng.randf() < 0.55:
		n += SYL_C[rng.randi() % SYL_C.size()]
	return _cap(n)


static func gen_cn_name(rng: RandomNumberGenerator) -> String:
	return CN_A[rng.randi() % CN_A.size()] + CN_B[rng.randi() % CN_B.size()]


static func catalog_id(rng: RandomNumberGenerator) -> String:
	var prefix := ["NGC", "R'lyeh-", "MISK-", "YOG", "KDT", "Ψ-", "AZ"]
	return "%s%d" % [prefix[rng.randi() % prefix.size()], rng.randi_range(100, 9999)]


static func pick(rng: RandomNumberGenerator, arr: Array):
	return arr[rng.randi() % arr.size()]


static func roman(n: int) -> String:
	var r := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return r[clampi(n, 1, 10) - 1]
