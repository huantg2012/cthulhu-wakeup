# TASK-FOUNDATION-ROUTES-DESIGN — First Cult, Isolated Character, Record, and Ritual Route Design

本项交付首团和三类文明扎根的八条**设计路线**，尚未接入游戏。新增活动、费用和实施责任已写回原系统规则及CSV；当前安装阻塞和两个原问题仍保留。

这次首先补上了“有第一位信徒，却未必能成立教团”的缺口。原来的开局献身只能得到一个具名成员，不能自动凑出六名无名信众或八点本域实际支出。新设计允许信徒组织秘密集会；已有祭仪职能的人也可主持当前秘密祭仪。二者分别按实际参加人数从本域非信众池转化，最多三人，不模拟逐个人的传播过程。两次成功各付四点信仰，才可能达到原六人、八实付门槛；真实领袖、人口和容量仍须满足。这是条件预算，不能读成两轮必定成团。

八条路线的差异如下：

| 目标 | 路线一 | 路线二 |
| --- | --- | --- |
| 首次建团 | 具名信徒实际组织秘密集会 | 真实祭仪主持者实际举行秘密祭仪 |
| CIV01记录型文明扎根 | 不同的人在不同回合亲历神迹，保留各自独立证言 | 同一记录者在不同回合实际使用超自然记录，形成持续依赖 |
| CIV02历法型文明扎根 | 不同回合实际举行祭仪，留下两次实践 | 记录者实际利用同一超常节律组织不同回合的周期活动 |
| CIV04仪式型文明扎根 | 真实祭仪主持者亲自承续仪式 | 当下真实教习后，学徒在后来回合亲自完成实践 |

第二列和第三列须分别禁用其独有活动来核验替代，不能只换路线名称。传递旧证言不能变出第二位亲历者；普通记账和排日期不是神迹；教习成功也不等于学徒已经实践。材料、知晓材料的人、实际持有人和目标结构仍分别核对。原有教团、媒介、费用和锚定条件继续适用，不增加官方传教许可。

已有但孤立的开局祈求人，也有了当下促成途径。已经真实认识邪神、达到有限意愿门槛的人可以实际私祷；未绑定者仍须通过正式成员准入和容量检查。私祷为零信仰、一低语，并占本人行动机会。另一项共同工作要求真实共同关切与当前接触条件，成功后才记一条合作关系。二者都不补过去的朋友、亲属、身份知识或职业。开局人物原本是记录者，不能直接当祭仪主持者。

三轮断联规则没有放宽。轮末只能用下一确定行动窗的同一实际准入检查，判断是否确有可执行的私祷；不能用旧成员身份、已消费的私祷事实、未来收入或目标待办续命。绑定后可以再次具备条件并实际私祷，每次仍要重查人物、知晓、忠诚、容量、关注和预算。入梦仍依赖原有效联系及冷却：开局忠诚十五的人两次普通成功只到三十五，不能据此声称已达四十。失败、人物失格或完全断联仍可导致寂灭。

本项增加七种有限活动，已经拆成以下五项待实施任务；共享核心和原下游同时追加责任：

- TASK-FOUNDATION-CONTACT-OPERATIONS — Present Contact and First Cult Gathering Operations
- TASK-FOUNDATION-RECORD-OPERATIONS — Record Practice Operations
- TASK-FOUNDATION-RITUAL-OPERATIONS — Calendar and Ritual Practice Operations
- TASK-FOUNDATION-INTERFACE-DESIGN — Foundation Route Operation Interface Design
- TASK-FOUNDATION-OPERATION-UI — Foundation Route Operation Interface Integration

独立审查与静态工具分别核对路线因果、规则接口和正式数据/任务引用/必要预算。它们不执行生产、支付、入团、关系写入、材料、保存或自然新局，也不能证明好玩。当前直接行动的等待值零，仅指未来安装后输入已经齐备的单步不用等随机卡；整条路线的耗时、成功率及自然节奏尚未验证。旧源码、旧数据和历史报告保持原样，共用路线表只追加本批行。

规则正文：`docs/specs/system-events.md` §14.11、`docs/specs/system-civilizations.md` §9.7、`docs/specs/system-progression.md` §12.2。静态结果：`tools/foundation-routes/results.json`；独立审查记录：`docs/qa/foundation-routes-results.json`。完整路线父任务仍未完成，下一项为 **TASK-MEMORY-CONTRACT-ROUTES — Memory and Contract Civilization Route Design**。
