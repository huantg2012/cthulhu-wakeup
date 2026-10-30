# TASK-CAPABILITY-PROBES — Short Behavioral Probes and Failure Controls

状态：限定验收完成，2026-10-30。实际4组通过；独立QA核原始结果与当前输入。

本项用已有组件夹具检查一条已知异常记录的请求生产、调度与回应；准备原记录/人物知识、控制抽签和成功随机输入。请求、call、情境、固定卡、可回应状态和结果均须由正式Turn产生，不能把目标结果注入当生产。

四组检查为：正式记录进入可回应请求并实际产生浅回应材料；背景域首次生产后，关注/下一轮退焦不重置游标或复制同记录请求；本人不知道原记录时该路线合法无输出而回合仍推进；将实际_origin_candidate函数体临时换成合法空返回后，绑定检查仍接受、回合仍能前进，但实际产物断言失败。

空实现控制是另一个Godot进程执行的实际源码变异，不是修改检查结果或替换输出字典。Python包装在finally恢复事前原字节并核输入hash，随后同一短基线再次通过；输出目录必须是新目录，子进程各限18秒。原缺失/错指向绑定负例引用GUARD已运行的检查，不重复铺同一矩阵。

无前提结论只指这条目标记录路线；其他祈求族仍可能合法产生请求。此处是受控组件行为，不能作为自然频率、整条ORIGINS、全部祈求、完整Session或新局的验收。五族来源17核心在GUARD最终共享源码冻结后已实跑，本项只新增工具，因此不重复跑它。

实际命令、原始基线/空实现失败/恢复基线、耗时及复核见本批JSON。

## 实际结果

最终基线3/3，3.760秒；真正空处理者子进程退出1、2.773秒，无脚本/引擎ERROR，绑定接受且回合成功，目标call/card均0使产物断言失败，合法空前提组仍通过。finally恢复原字节后基线再次3/3、2.867秒，总计9.400秒，77个实际相关输入hash前后及当前一致。三轮实际为后台→详细→后台，同一来源每轮均一份call/card，游标next_turn保持4；这证明既存根的模式交接，不证明下次新机会的自然等待或发生率。

首轮正式基线中生产/合法空通过、模式组失败，未进入变异，无引擎ERROR，原始目录final-20261030保留。根因是测试把release_focus当成当轮生效；实际在下一轮round_start生效。第二轮同组改用背景DOMAIN-002的两个合法standalone命名前提和原已知记录，T1后台首产、T2正式focus并申请退焦、T3实际后台；未修改游戏规则。人物和原记录只是声明的前提，目标请求与结果仍由正式入口产生。

命令：`python tools/implementation/capability_probes.py --godot "E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe" --output tools/implementation/capability-probes-runs/<new-directory>`。只给新目录，避免覆盖既有结果。最终原始总报告：tools/implementation/capability-probes-runs/final2-20261030/results.json；各baseline/empty-handler/restored.json保留。
