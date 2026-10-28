# 祈求来源与开局准入：制作人报告

2026-10-28。TASK-PRAYER-PRODUCERS本批限定范围通过：四类既有来源现在接上正式祈求生产；六个固定种子的模块开局都有可支付的无指向请求。完整游戏新局仍未通过，教团系统兼容阻塞保留。下一项是TASK-PRAYER-INTEGRATION。

原来调度入口修好后，还有一段实际生产没有接齐：已知异常、当下祭仪、献身求援、通行诉求，必须先成为有来源的本次求告，再固定为玩家能回应的请求。本批补上这段。正式Events回合使用同一处理者表和共享机会，相关四类不再借旧BG候选绕过；没有安装Events的旧独立模拟入口仍保留，不能据此称全项目旧入口已经移除。

开局请求单独初始化：先核人口、活身份、注意力人数和成员名额、候选容量，以及浅触的实际费用，再一次性提名人物、扣除无名人口、建立无指向请求并预留成员准入。现行浅触是0信仰、1低语，本轮没有降价或修改概率。缺前提会明确失败且不留半个人物、半份请求；同一初始化不能重复领取。实际成功回应可形成一名绑定信徒并获得身份知晓，**不等于教团已经成立**。

这次修复了几类实现问题：

- 人物已经形成求告，只因候选池满而暂时不能固定时，原求告保留。后来认识邪神、撤去关注或者释放容量，不会重抽其原方向和采样依据。匿名人物则在提名前核容量，失败不扣人口。真正的事务异常会整体回滚。
- 另一份祈求里的见证人曾错误阻塞自己的独立诉求，现在只按实际求告人判断占用。已知记录按真实取得记录分页，不再因前一人的空页遗漏后来的人。
- 祈求窗口现在受原危机期限约束，并区分回合开始前到期与行动之后到期。没有实际回应机会就不固定、不付费、不占名额，不靠延长危机补救。
- 两份曝光记录若指向同一原异常，只形成一份本次求告。知道包装记录不会自动学会其父事实。审查还发现事件重开漏接包装证明的直接因果引用；现已补齐，并实际走通“生产→到期→EVENT12B重开→当前模块保存恢复→浅触回应”。

通行诉求另有一个需要继续观察的风险：若抽取依据的屏障在同批演化中已经改变，本次选择会放弃，不能偷换成新屏障或补抽。稳定屏障前提下的生产正例已通过；普通世界的请求频率可能因此降低，尚无自然频率结论。模式合同由INTEGRATION核查，实际节奏由NATURAL-VERIFY和STARTUP-BALANCE实测。

本批56项行为检查和5项运行检查通过；原知晓专项72＋5、原调度专项55＋5也以当前实现重跑通过，共198项检查。三组均无Godot ERROR，运行时源文件在执行中保持冻结，原始产物哈希匹配。主会话在两次实现闸门失败后接管代码，并在两次测试夹具闸门失败后接管工具与执行；QA随后独立只读核对断言、原始结果、指纹和范围。这里的独立复核不表示QA亲自执行了接管后的所有命令。

这些是有界模块检查。记录、角色、机构、已占容量等必要前提可明确准备；四类生产用例的目标求告、处境和固定卡由正式生产产生；PR01窗口用例准备合法situation，仅验证消费。六个开局种子为19、42、7919、2027、1981、104729，回应检查固定成功随机流，因此不提供成功率或平衡结论。通行正例明确从合法满值屏障开始。PR01期限检查使用独立期限参与者与真实消费者，不代表完整Cults.start组合或新伤害来源生产。

原72/55项断言和覆盖表未削弱，但输入适配必须说明：知晓夹具在初始化前准备原梦境资格；调度夹具实际让bootstrap消耗最后一名无名人口。仅“同机构告知”正例另加入一名真实无关信使，保留合法通行竞争来源。原输入十二轮没有送达的失败样本仍存档；当前正例不能证明不加该人物时的送达频率。旧报告继承的“旧BG bootstrap”等文字属于历史说明，不能当作当前正式路线。

当前最终证据相对路径：

- `docs/qa/prayer-producers-final-results.json`：本批61项。
- `docs/qa/prayer-producers-knowledge-final-results.json`：知晓回归77项。
- `docs/qa/prayer-producers-dispatch-final-results.json`：调度回归60项。
- `tools/prayer-producers/runs/INDEX.md`：失败、诊断、补漏前通过与最终档案索引。

11:16 UTC的三份初次正式报告通过了当时已有断言，但没有覆盖包装证明的事件重开遗漏；均保留原字节，不能作为修复后的最终证据。原38份CSV、46份既有QA JSON及两个旧工具results.json共86份基线文件保持不变；新证据另存，不给旧结果重新签名。

复演命令见`tools/prayer-producers/README.md`。最终运行使用：

```powershell
python -X utf8 tools/prayer-producers/verify.py --godot 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --timeout 600 --report-output docs/qa/another-fresh-producers.json
python -X utf8 tools/prayer-knowledge/verify.py --godot 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --script tools/prayer-producers/knowledge_regression.gd --report-output docs/qa/another-fresh-knowledge.json
python -X utf8 tools/prayer-dispatch/verify.py --godot 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe' --script tools/prayer-producers/dispatch_regression.gd --report-output docs/qa/another-fresh-dispatch.json
```

输出路径须尚不存在。定向/无向×重点/后台四格、玩家最小知情投影和所有投影中的内部字段过滤归下一项INTEGRATION；五类新原根、完整Session及整链存档、自然新局与首次建团数值仍按原任务实施。两个原阻塞不关闭。本轮未修改游戏内界面、通用框架或master。
