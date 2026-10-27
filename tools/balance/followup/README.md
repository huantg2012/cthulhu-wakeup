# 第二轮单一策略修订

明确授权的seed19/expansion诊断，仍是真实新局60轮、原规则/CSV/骰流。只将公开EVENT04的B分支排在A前，其余策略完全继承首轮。首轮A实付5使faith6→1，后续无法支付4的祭仪；本轮观察选择B后的实际原资格和后果，不预置异端对象或信众收益。

run.gd是根runner的副本，把Policy preload路径改成本目录，并仅在首次建团轮末额外写first-cult.json（完整Turn.snapshot、campaign身份与已知集合的纯观测）；其余执行不变。根runner的已知temporary诊断字段无效，本轮同样只用decision_view.public.attention读取P/N/F/身份占用；round实际回合用after.turn。若形成教团，原runner随后真实提交expand计划，保留原资格拒绝/降为hold的经济预览。

执行`python -X utf8 tools/balance/followup/verify.py --godot <引擎路径>`；必须待首轮12局结束后串行运行。新报告独立保存根来源和followup来源指纹，不覆盖首轮。该诊断与首轮12局失败分布分开统计，不能算第13个首轮样本。

若真实形成首团，`replay.py`用同种同策略再跑到首团轮；只规范化campaign时钟身份，比对整个Turn.snapshot与已知来源/人物/域集合，作为实际重放。它不增加新策略修订，也不声称跨版本或跨平台确定性。
