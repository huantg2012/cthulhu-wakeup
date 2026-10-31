# Cult spread core verification

Run the four bounded production groups and their direct regressions from the repository root:

```powershell
python tools/cult-spread/verify.py --godot 'E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe' --output tools/cult-spread/runs/<new-run> --regressions
```

Use a new output directory for every run. The runner saves exact input hashes, raw engine/stdout/stderr logs, timings and structured results. It stops at the first failed job; missing later jobs are not passes. On this host, run outside the sandbox because its certificate-store engine errors invalidate the gate.

The core covers actual aggregate expansion, paid POWER_SEED with shared spread material and Session selection, EVENT09's fixed endpoint/receipt/basis with rollback and retry plus EVENT04's retained default, and the complete formal Session opening through one normal round. Direct regressions are material transfer (4 groups), anchor routes (4), shared source contracts (17), Godot parsing and the main-scene startup smoke.

Existing cult membership, original contact/dispute/ritual situations, initial resources and successful check seeds are explicit fixtures. Dreams, prayer responses, fees, event results, routes, material receipts, current qualifications and the formal new-game opening use production paths. This does not prove natural first-cult progression, future material producers, full anchor lifecycle, Session save/continue or human UX.

Earlier `core-*`, `repair-*` and `finish-*` outputs remain immutable evidence of their respective inputs, including failures. Current applicability and acceptance are recorded in `docs/qa/cult-spread.md`.
