# 可玩结构原型（当前）

双击仓库根目录 **`体验原型.cmd`**，或执行：

```powershell
powershell -NoProfile -File tools/ui-experience/play.ps1
```

当前入口为 `src/presentation/experience_root.tscn`，使用现有正式 Session、CSV、选源、随机结算和保存接口。Godot 4.7.2；脚本优先读取 `-GodotPath` 或 `GODOT_EXECUTABLE`，本机路径可自动找到。不修改项目默认旧界面入口。

默认1600×900固定研究画布。顶部全局及祈求摘要；左侧教团、右侧圣物、底部12权能与最新编年史常驻。主区只有总览与同级子页，一次“回到总览”返回默认信息。普通查看保留当前行动；切换权能直接替换，关闭一次收起，没有浏览/行动返回栈或旧目标缓存。无行动时主体占满中央区域；有行动才并置资料和操作，费用与执行按钮固定可见。祈求直接选择浅触/深应并回应，细节按需展开。事件、确认、编年史深层详情与暂停使用临时窗口。

开始菜单提供真实新局、独立存档和真实首团局面。首团案例来自 `tools/startup-balance/runs/calibration-02/natural-2/1793428405-9608508.json`；读取前复制到独立目录，不覆盖QA原件。原保存点是第3轮结算后，恢复自动进入第4轮；只有1个教团、1位成员、无圣物。正常结束回合也自动完成内部结算并衔接下一轮，遇必要事件或终局停下。原型存档在 `user://ui-experience-campaigns`；正式局保持独立。

本轮专项验证记录在 `docs/qa/ui-experience-interaction-audit.md` 与 `docs/game-state/ui-experience-native-checks.json`，覆盖实际回应路径、导航、焦点、固定提交、取消、保存恢复及人物范围。实际引擎画面为 `ui-experience-native.png`（祈求浅触）、`ui-experience-preview.png`（深应）、`ui-experience-unavailable.png`（未解锁）、`ui-experience-subject.png`（无行动完整主体）。每轮至少一项有效祈求的正式供给修订单列 `docs/qa/ui-experience-prayer-supply.md`；不能把UI检查当供给通过。未进行整局、全部成熟路线、平衡或人工验收。

DEC-041扩展自查还补了策略预先比较、当前页实际结果、临时双对象对照、人物检索、准确对象历史及事件/活动身份。概念图只约束信息关系与交互意图，原型布局按验证需要简化，不复刻场景结构。

维护工具：`native_smoke.gd` 做32项有限交互回归；`semantic_check.gd` 做156项CSV表达与语义断言，`subject_check.gd` 做15项明确UI夹具，后两者不证明自然成熟局。`capture_native.gd` 使用真实新局及首团副本生成上述四图和 `ui-experience-result.png`（实际回应后）、`ui-experience-comparison.png`（临时对照），合计六张引擎画面。测试/截图用仓库忽略目录 `.godot` 的隔离存档。不要为了例行修改重跑历史整局验收。

## 旧版 HTML 线框（归档对照）

交付：`docs/game-state/ui-experience.html`，浏览器直接打开，无网络依赖。

这是 DEC-038 的旧灰阶结构走查材料，已被上方真实运行原型替代，不再作为可玩交付。游戏规则的唯一正文仍在 `docs/specs/`；本目录不另立规则。人物、库存、局势与执行结果为构造样例，权能、祈求、事件、圣物类型、路线与参数从正式 CSV 构建输入。

## 重建

```powershell
python tools/ui-experience/build.py
node --check tools/ui-experience/app.js
```

## 流程检查

```powershell
npm install --prefix .godot/ui-experience-test --no-audit --no-fund --ignore-scripts linkedom@0.18.12
node tools/ui-experience/check.cjs
```

测试依赖只放在忽略目录 `.godot/ui-experience-test`。检查脚本使用 DOM 模拟器，输出 `docs/game-state/ui-experience-checks.json`，不验证浏览器排版、真实引擎规则、随机结果、自然生成可达性或人类验收。

## 走查

页面最上方的情境选择与“流程与覆盖”属于原型导览，不是游戏内菜单。默认进入多成员教团的中期局面；可切换初醒、轮初事件、首团之前、祈求已回应、数量超屏、零资源、失能、降临和终局等 14 个情境。

游戏画面采用固定 1600×900 研究画布，默认整幅缩放，也可选 100% 浏览；不会修改正式项目的逻辑分辨率。演示保存使用独立 localStorage 键 `cthulhu-ui-experience-v1`。预览四档概率与机会费用有示意标记，不可作为数值依据。

当前验证边界：自动流程检查已执行；预览窗口的自动访问被环境拒绝，尚未获得浏览器实际排版检查证据。三张既有生图继续作为视觉参考，本原型不落实其美术。
