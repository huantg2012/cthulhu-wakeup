# TASK-SOURCE-EXCEPTION — Current Anomaly Observation Sources

状态：本族限定验收完成，2026-10-30。不代表完整新局、完整扎根路线或有限等待保障通过。

## 做成了什么

法则型文明现在能通过现有来源抽签，产生异常发现和另一节点对同一异常的独立观察。每次观察记录稳定异常ID、真实观察者及原节点；不模拟仪器、读数或逐步复核。没有玩家关注、没有初始具名人物的宇宙域，也能沿原人口、身份和主体容量准入提名观察者，生成PR12。

发现异常、普通观察、实际回应留下的材料分别记录。材料独立性解回原观察：同一观察的复制、递交或深回应产生的多个包装只算一份；另一节点的另一观察者才可产生第二份独立材料。Anchors和Events的原消费者共用这个判断，不用新记录编号冒充新起源。

来源优先尚无观察的节点。是否停止向某节点提供同异常机会，要看这个原节点实际保有的合格材料；深回应仅把材料交到别处，不能据此永久封掉原节点。请求失败或到期后可在后续抽样中重试；可重试不等于有限等待已实现。

## 实际schema与接口

prayer_sources新增anomalies（每域当前稳定异常）和observations（该异常各节点最近观察）。law_observation记录exception、observer、node、scene_rule及本次snapshot；PR12 facts同时引用exception和observation。实际回应材料沿该原始观察判独立性。旧观察仍保留历史，不因新观察而篡改身份。

无名观察者复用World.nominate_prayer_contact的P/K/人口预检、身份预留和原子固定；无足够展示或主体容量时不先造异常、观察者或隐藏时钟。CSV增加exception_scene_weight=1、exception_scene_cooldown=3，不改总体出现概率、费用或回应成功率。

## 实际核心检查

最终冻结代码单次运行10.93秒，退出0；3组本族加原10组直接回归，共13/13通过。

| 检查 | 实际结果 |
| --- | --- |
| SE-FIRST | 无宇宙域关注、无具名观察者，正式生成一名观察者、异常、观察和PR12；Turn保存恢复不改已固定结果，实际浅回应取得一份材料。 |
| SE-INDEPENDENCE | 实际深回应产生的两份转交包装不独立；之后另一节点、另一人物对同一异常产生新观察，并实际浅回应留下独立材料。 |
| SE-CAPACITY | 首次卡位不足不生成观察者或异常；容量释放后可生成。另一实际未回应情境到期只关闭一次，后续仍对同一稳定异常产生新观察。 |
| SLT三组 / SLC四组 / SM三组 | 原救援、冲突与记忆十组在当前共享代码下真实重跑，原断言通过。 |

控制的是初始随机数和合法前提，没有注入目标异常、观察、祈求或回应材料。独立性例预先沿已有兼容提名入口，为三个节点各提供合法人物及实际暴露；首例和容量例仍无宇宙域关注/具名人物。其他域初始随机输入控制其在短窗口不抽中普通背景，隔离无关三卡容量竞争。只计算少量随机输入，不搜索模拟世界；不据此证明自然频率。

命令：

```powershell
& 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --log-file D:/code/cthulhu-wakeup/tools/prayer-producers/source-exception-engine.log --script res://tools/prayer-producers/source-exception.gd -- D:/code/cthulhu-wakeup/tools/prayer-producers/source-exception-results.json
```

首跑9.07秒，11/13通过：二节点夹具在事务外直接申请关注，被原准入规则正确拒绝；容量例首次阻断通过，但随后被其他域候选竞争且未正确捕获中间机会。保留首败原始结果与执行记录；第二次只改测试合法初始前提及逐次记录，不改生产概率、规则或原断言。最终仍有Windows证书存储环境ERROR，无SCRIPT ERROR。

## 边界与后续

本项只接轻量来源、实际PR12及原材料独立性消费者，没有完成CIV07双节点/单节点全路线，没有验证所有节点组合、失败类型或自然等待时间。保存仅覆盖Turn组件；完整Session及密教兼容、自然新局、必要机会概率修正、目标接收者实付、全锚点和数值平衡仍由原任务承担。原两个实际阻塞未关闭，视听与发布继续锁定。

当前证据：docs/qa/source-exception-results.json；原始结果source-exception-runtime-results.json，执行source-exception-execution.json。首败文件source-exception-first-failed-results.json及source-exception-first-failed-execution.json保留。旧来源报告不重签，当前追踪换绑本轮真实回归。

下一项：TASK-SOURCE-CONTRACT — Current Agreement and Obligation Sources。

当前复核（2026-10-30）：五族共享来源最终17组运行中，原相关短例已真实重跑；当前追踪见docs/qa/source-contract-results.json。策略的当前文档/任务状态另由SC-STRATEGY-REVIEW人工复核，不计引擎测试。本文原运行/旧JSON保留为历史，不重签。
