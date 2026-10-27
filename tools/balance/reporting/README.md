# 策略证据归档

冻结的 12 局执行完成后，运行 `python -X utf8 tools/balance/reporting/report.py`。先核对实际执行时登记的所有来源与原始轨迹指纹，再以固定 mtime gzip 保存轨迹、原始结果和进程输出，生成 `docs/qa/balance-results.json`。它不修改执行时的来源指纹，也不重跑或修饰负面结果。

提交版保留 `docs/qa/balance-baseline.json`、`balance-traces/*.gz`。可执行 `python -X utf8 tools/balance/reporting/report.py --input docs/qa/balance-baseline.json --archive-only`，完全忽略本地 runs，从压缩档案验证原始字节并重算统计。局部存档和探索不进入正式分布。

静态生产闭包审阅单列 `balance-source-review.json`，注明人工独立代码审阅方法、真实失败项和来源指纹；不会伪装成自动新局通关。任何运行来源或审阅来源变化都拒绝发布，必须重新执行对应的游戏验证或独立审阅。正式样本有缺失、重复、截尾不足60轮、逐轮身份不连续或档案被改，同样拒绝。

`python -X utf8 tools/balance/reporting/test_report.py` 检查不完整运行、过期来源、缺样本、压缩损坏和越界路径均拒绝。失败验收返回1，结构或指纹错误不会发布新报告。报告执行完不等于TASK通过：首团与实际经营覆盖、自然宇宙来源、UI人工验收保持各自证据。

统计用 `round.after.turn`；`round.turn` 是进入循环前游标。P/N/F使用当轮公开 attention 数字；无效的 diagnostic temporary 字段不参与统计，identities显示的是准入占用而非全体活身份K。每阶段耗时为Session.progress总耗时（含其自动保存），仪表化整轮和行动另含全档案snapshot对照、投影及日志；活动规模和历史同时变化，不以此推断H的独立因果或发行帧率。

两个单列诊断由 `report_followup.py --iteration 2` / `--iteration 3` 归档；添加 `--archive-only` 可完全从压缩档复算。第二轮仅改EVENT04偏B；第三轮只再加“首团前不使用额外权能”的预算约束，未改数值。二者均未建立首团，因此没有任何首团重放通过记录。`last_probe/replay.py` 是冻结时未使用的复制来源，仍指向第二轮脚本，**不能作为第三轮重放入口**；已确认当前无首团时会在启动引擎前拒绝，不产生重放结果。修复该工具入口须单独更新并验证来源，不借此补造未执行的重放。
