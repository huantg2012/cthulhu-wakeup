# 表现重构对比课

**当前设计交付：**打开 `docs/art/presentation-rebuild/interaction-slice.html` 体验诸界→当地→人物/媒介准备→演示结果→后续责任；设计唯一正文为同目录 `interface-design.md` §10–§11。它是离线HTML交互夹具，“预演成功分支”仅改本页状态，不执行游戏规则或写存档。重建：`python3 tools/presentation-rebuild/build_interaction_slice.py`。目录/费用来自正式CSV，局势来自 `interaction_fixture.csv`。旧结构阅览器 `interface-review.html` 仍保留，可用 `build_interface_review.py` 重建。旧 `visual-system.md` 只读，下方Godot三卡属于原批次问题样本。

本轮成果位于 `codex/visual-interaction-exploration` 的独立worktree；功能开发继续在原目录 `cthulhu-wakeup` 分支。请从本worktree启动此入口，避免在功能目录切分支。分支建立于 `cd4fbd9`。2026-11-07 合入功能分支 `3ac9ba2`，探索与正式界面继续使用各自入口。

运行根目录 表现重构对比.command。Godot 4.7.2；1280×720逻辑、1920×1080输出。

- 1 / 2 / 3 或顶栏按钮切换完整候选，保留同一 Session、模式、选择和已执行结果。
- Esc与页面返回按钮遵守同一来处：世界资料、人物、完整后果回到原任务；确认页取消回到回应准备。
- 开始在真实 seed 1、T1 神意行动：困惑的记录者，PRAYER_08「让我的声音被听见」。
- 点祈求、比较浅触/深应，查看人物并返回；提交沿原不可逆确认、原随机、原付费和原实际结果。
- 重置同一局面：重新载入独立起点。换种子：使用正式生成建立审阅局，不改正式存档。
- 旧版补立绘：单开真正生产场景，同一种子及真实祈求，仅在运行时将原 SceneSlot 替换为候选立绘；不保存覆盖、不复制旧布局。这是素材补齐对照。
- A/C 底部十二权能可查原CSV规则；B从「十二权能·查阅」进入。样本只执行祈求，不把权能查阅冒充全玩法新UI。
- 人物和文化图像为候选诠释，不声明正式设定或制作人审美通过。其他表现表面尚未迁移。

新入口使用同一 GameRoot / Presentation / CanvasLayer / OverlayRoot 路径。独立renderer是本轮破坏性结构探索的明确例外；共享原Session、ActionCatalog、ExperienceActions/Semantics、ExperienceViews、ExperienceFeedback，不复制规则、费用或模拟。没有改变生产默认入口与现有生产文件。

制作人最新要求为不直接改开发中的游戏布局，正式接入须按后续指示安排。启动器先核对候选专用 `docs/art/presentation-rebuild/design-sync.json`；现有生产入口的路径管理范围不接收候选布局。当前交付证据见 `docs/qa/presentation-rebuild/qa.md`，85项限定输入/机制检查通过，审美和方向待制作人。

机器核查：

    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://src/presentation/reconstruction/lesson.gd --check-only
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/presentation-rebuild/layout_probe.gd
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/presentation-rebuild/probe.gd -- /tmp/presentation-rebuild-check

去掉最后一条的 --headless 并给出证据绝对目录，可重取15张实机PNG。捕获通过 RenderingServer.force_draw 同步读取，避免 macOS 窗口遮挡后 frame_post_draw 无限等待；整个probe有75秒硬上限。

已知边界：首批验证seed1；换种子可生成真实局面，但未验证全部内容及原轮初事件处理；可选协助根据真实字段显示，seed1无候选，未构造假协助；未做大字模式、整局自然推进、声音、其他玩法页面或最终审美验收。

第二轮默认先显示轮初事件，处理后查看四维/权能准备；底部开关可标注资产位置尺寸。扩展层为 `interaction_refinements.js/.css`，UI字段与情报示例分别为 `power_preparation_fields.csv` / `world_observation_fixture.csv`。仍用同一生成命令，规范见探索正文§12。

场景化权能与立绘版见正文§13：先处理轮初，再选十二权能→入梦→选伊弥→施展；当地祈求和人物档案可看同一角色。新增 `ritual_experience.js/.css` 与 `ritual-assets/`（完整prompt/manifest随资产保存）。带图版本离线需同时保留相对资产目录。
