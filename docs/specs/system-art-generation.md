---
status: IMPLEMENTED_PENDING_VISUAL_REVIEW
created-by: Codex
last-modified-date: 2026-11-12
interfaces-with: [system-events, system-civilizations]
exposes: [ArtGenerationService.generate, ArtGenerationService.export_result, NativeArtWorkbench, ArtGenerationService.generate_subject, ObjectPortraits.bind]
interface-changed: true
---

TL;DR：世界、教团与人物立绘在游戏本体 Godot 工程内生成。独立工作台直接运行，无浏览器、Node、Python、Web 服务或第二个 Godot 工程依赖；正式呈现从公开对象推导绘画身份并按需出图；绘画服务不创建游戏世界、机构或 NPC。

# 范围与入口

2026-11-12：界面承载母版已获制作人通过，全游戏展示与身份接入要求见[界面美术规范 A13–A16](../art/visual-generation/ui-art-standard.md#6-立绘身份运行时与资产)。工作台与正式对象呈现分别使用下方接口；独立工作台参数不参与正式分配。

`诸界立绘生成.command` 启动 `res://src/art_generation/workbench/workbench.tscn`。原世界／教团／同世界人物／跨世界人物及旧程序画法启动器统一转向该场景。历史 HTML、JavaScript、服务器与图片保留为只读迁移参考，已退出当前生成链。

11 个原作星球原型、6 个画风 sid（0、1、2、4、6、7）与 10 个色板保持可选。原作画风表索引与 sid 分开。输出沿用 960×960 绘画坐标与图像尺寸。世界种子为 0–999999；人物种子为 uint32；一次生成 1–8 人。人物背景来自既有 CSV，潮汐有 6 类／48 种离散造型组合，其余世界各 4 类／24 种；种子及连续身材参数不作为新增职业计数。

# 分层合同

1. **参数与规则**：`catalog.gd` 只读 `data/art_world_templates.csv`、`cult_visual_rules.csv`、`portrait_*_rules.csv` 和 `prayer_space_cases.csv`。输出世界描述与受约束的人物背景。`algorithms/people.gd` 用独立具名随机流构建人物 recipe，保留既有职业、衣物、遮脸下性别表达和手势。
2. **绘画算法**：`algorithms/` 中的教团、人物、服装和环境规则生成有顺序的二维绘画命令。`rendering/surface_painter.gd` 是命令记录器：曲线路径、材质、褶皱场、面朝向、光源、遮挡、裁切及画幅变换。这里不分配视口、不读成品图、不产生三维人物或建筑。
3. **像素渲染**：`rendering/surface_renderer.gd` 消费命令。Godot 内置 SVG 栅格器把运行时曲线转为局部蒙版；`field_compiler.gd` 将原生字段描述编译为 shader 函数；`surface.gdshader` 合成材料颜色、相关高度、湿度、反光、定向光与点光。输出 `material`、`form`、`lit` 三张独立 Image。SVG 字符串只是运行时路径蒙版，不是预制成品图或浏览器接口。
4. **原作星球适配器**：`rendering/world_renderer.gd` 调用 `source/generator.gd`。原作 3D 星球保持原有算法，天空独立留作二维立绘背景。原始 GLB 网格无几何修改地序列化为 Godot 原生 `celestial_meshes.res`，运行不依赖编辑器导入缓存。移植副本的 `class_name` 改为局部 preload、资源路径重定位、全局 shader 参数改为每材质参数；原作参考目录不动。
5. **后期**：`post/npr_pipeline.gd.apply(image, world, sky, illustration)` 单独拥有天空合成、bloom down、bloom blur、原作 NPR 视口。可更换整个后期实现，也可逐个换 shader。人物／教团的已有受光不会被再当作未受光材料重新照明。星球使用原作像素尺度，二维立绘使用当前经验值 0.68。
6. **调用与展示**：`service.gd` 编排生成、参数校验、当前世界缓存与导出；三个 renderer/post Node 可以在入树前注入替代实现。`workbench/` 只负责参数控件、展示生成结果、阶段切换、放大与导出。未来游戏展示应消费 Image／ImageTexture 与元数据，不能依赖工作台控件，也不能在卡片绘制回调中启动生成。

`service.generate(request, options)` 是异步方法。成功返回 `context`（世界图、天空、教团图、三阶段图、世界参数、候选教团规则）、`people`（最终图、三阶段图、recipe、features）、版本、耗时和是否复用世界；输入错误返回 `{error: String}`。同一实例不允许并发生成。缓存仅保留当前世界／教团，键包含实现版本与四个世界参数；只换人物不重建它们。“同参重绘”主动清缓存。当前无持久化生成缓存，不污染游戏存档。

# 正式对象绘画身份 · v1

- **世界**：只接受公开投影中带文明 profile 的世界；仅有请求线索时留中性图槽。用 `data/art_world_templates.csv` 的 `civilization_id` 唯一索引选取原型和固定画风 sid，色板取同原型的 `cult_visual_rules.csv:default_palette`。每世界的种子取 SHA-256（JSON 数组 `["world", 开局种子字符串, 世界 ID]`）首 32 位模 1,000,000。配方使用原玩法稳定 ID，不用显示名、排序或观察次数。
- **教团**继承其公开所属世界的原型、种子、sid 和色板；仅已知仍可展示的组织可绑定。图像由本世界的场所绘画规则生成，领袖变化不替换其场所图。
- **人物**仅给公开已识别的真实角色画图，继承其出生世界画法；人物种子从 SHA-256（`["person", 开局种子字符串, 人物 ID]`）首 32 位取 uint32。人物根据不可变的 `identity_source` 得到已知出生世界；未知出生世界不提前显示其画风。背景以 `data/art_person_profiles.csv` 的 profile 选择同模板已有裁剪/衣帽基型，使用中性姿势和材质、去掉具体病况及道具，不把样板处境当正式事实。缺少可靠对应保留中性图槽。祈求页用同一身份，当前祈求处境不重抽外貌。尚未知身份、仅有线索的对象不触发渲染。
- 以上种子仅用于绘画，取自 Session 已保存的生成种子，不读取随机流位置或消耗任何玩法随机数。v1 兼容旧档，不增加存档字段。若未来改变已分配的原型或画风，须保留 v1 的还原规则并明确选择配方版本。
- `generate_subject(kind, request, options)` 产出一张带天空的最终 960×960 Image，不为世界卡额外画教团或人物。正式调用只渲染 lit 和最终 NPR，不生成工作台专用的 material／form 两张诊断图；工作台 `generate` 默认仍交付三阶段。纯二维构图在 WorkerThreadPool 中建立，场景节点、材质和 GPU 渲染仍在主线程，按约 4 ms 的命令构建时间片让出帧。同一 service 串行生成。
- 正式呈现根持有唯一 `ObjectPortraits`。新局、读档、回合交接及行动更新公开投影后，按世界分组准备当前全部可展示的世界、教团与已识别人物；不预生成未知身份或未知出生世界。内存命中直接就绪，其余在过渡页完成读盘／生成和 GPU 纹理上传，再交还牌桌。可见图槽请求仅作为漏项的防御回退，正常翻牌不得依赖它。回调检查弱引用、仍在树中和当前绑定键；离场或更换对象不贴回迟到的图。
- 持久缓存键包含视觉身份版本、生成实现版本、对象 ID、完整绘画参数和背景键；磁盘缓存是可丢弃的 PNG（128 MiB 上限），读解码和原子写盘在工作线程。当前公开对象纹理驻留，不受原 24 张上限淘汰；额外闲置纹理最多保留 24 张。换轮只补新增或缺失图，不重复生成。缓存损坏只重画该图；生成失败结束该项等待并显示静态不可用状态，缺参仍保留中性图槽。不因悬停、切页或读档重抽绘画身份。

# 替换策略与约束

- 改人物构造／教团结构：改对应 `algorithms/` 文件，继续输出绘画计划；消费者不改。实际修改配方语义时升级 recipe／实现版本，不静默复用旧缓存。
- 改材质或照明：替换 `SurfaceRenderer.render(plan)`，保留三阶段 Image 合同。世界材料场与衣料材料场分离，不能将一种石纹铺满所有对象。
- 改 NPR：替换 `Post.apply`，保留独立参数、世界与二维尺度区分；不改规则、构图或游戏展示。
- 改最终展示：从生成结果构造 Texture2D，展示者决定裁切、尺寸、过渡与释放。透明 `lit` 阶段可供未来新合成器使用；当前 `image` 是带天空的最终方图。
- 首次进入及轮间允许有明确进度的准备过渡；过渡只读取玩家已掌握的诸界情报，不造推演结果、不泄露隐藏指标、不推进额外回合。全部当前公开立绘就绪后恢复原本的事件／行动交接。缓存全命中时不显示过渡；不对所有未发现世界做全量预生成。
- 原始 2D 方法已移植为可直接编辑的 GDScript 与 Godot shader，不加载旧 JS、不解释 JavaScript、不调用旧服务器，也不调用浏览器截图。

# 迁移差异与证据边界

二维 CPU 逐像素画法改为 GPU 材质求值，曲线结构、绘制顺序、种子流和材料关系保留。原浏览器栅格抗锯齿、模糊和随机笔触与 Godot 不逐像素等价；当前 GPU 使用屏幕导数扰动法线，笔触随受光强度沉积，原作 NPR 继续提供主要厚涂组织。不能把本次迁移描述为全部像素无差异或新审美通过。

必要检查与原生图放在 `docs/art/visual-generation/procedural-study/native-evidence/`。`tools/art-native-port/check_rules.gd` 仅检查 11 原型构造及对应人物背景，不作审美结论；`capture.gd` 生成有界代表样本及种子不变量；`capture_workbench.gd` 截取实际 Godot 工作台。最终视觉取舍归制作人。
