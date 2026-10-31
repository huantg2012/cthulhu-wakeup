# TASK-CAPABILITY-GUARD — Declared Responsibility and Production Wiring Checks

状态：限定验收完成，2026-10-30。独立QA只读核对当前源码、冻结输入及原始结果。

本项只检查候选生成这条正式链的接线。simulation_responsibilities.csv声明的详细/后台生产者，必须对应Events实际持有的模式函数；Turn只有一个candidate_generation负责人；World阶段四经同一Events/Dispatch入口调用，原根处理者从现有Producers/Sources定义绑定。检查不维护另一份“已实现能力”清单。

首批12个直接请求/告知处理者有缺失和错指向检查。根表中的初始关系、共同见闻支撑根有自己的生产责任，不因未直接注册为祈求处理者而误报。

Python工具6项通过，进程墙时0.089秒（内部0.0147秒）；Godot组件6组通过，1.847秒，含12根逐项删/错绑定检查和正式CSV与代码列表共同遗漏的检查。职责表递归只读，预览替换整个策略表会被原保护拒绝并恢复。源码重构可能需要同步结构检查；函数可调用仍不证明它会生产正确结果，行为由下一项探针负责。正式入口也调用同一绑定校验，不能只修改制作检查的白名单放行。

合法零候选仍允许；无前提、资源或容量不足不能因此制造请求。没有新增普通社会模拟、费用、人口或材料规则。

## 证据与边界

最终冻结批命令、耗时、退出及12项输入登记在 tools/implementation/capability-guard-frozen-execution.json，当前hash全部匹配，运行中无输入变化。原17组来源核心最终冻结复验14.349秒；检查期间的代码复核修正曾产生早期通过批次，保留原始文件，最终证据只采用frozen批。另Godot脚本解析2.634秒、菜单启动1.572秒，各退出0、无engine ERROR。早期sandbox环境证书/默认日志路径噪声见原日志，不计为最终通过。旧QA报告保持。本项不验收完整Session、自然频率、材料转交、09A或八文明扎根。

原整改规划仅复核当时的设计/实施分工和本轮依赖。行为工具可以检查未完成实现，原ORIGINS的全范围验收仍保持原任务，不能把本项接线检查当作它已通过。

后继：TASK-CAPABILITY-PROBES — Short Behavioral Probes and Failure Controls；TASK-CAPABILITY-AUDIT — Core Capability Omission Audit。
