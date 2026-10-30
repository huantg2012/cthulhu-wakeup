# Shared opportunity eligibility checks

Run from the repository root with the fixed Godot version and a new output directory:

```powershell
python tools/opportunity-eligibility/verify.py --godot 'E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe' --output tools/opportunity-eligibility/runs/repair-02
```

The runner has a 58-second batch budget. It freezes the transitive production scripts, current loaded CSVs, project configuration, test script and collector before execution, then compares their hashes afterward. It runs GDScript parsing, four behavior groups, and the actual project headless startup. A nonzero process exit, `ERROR:`, `SCRIPT ERROR`, parse error, missing check or changed input fails the batch. Run Godot on the host: the restricted environment has produced certificate-store errors and must not be treated as a valid passing run.

This is a Godot/GDScript project with no package.json, TypeScript configuration or configured npm lint/dev commands. Godot's parse check supplies the applicable language check; the four existing groups and actual project startup supply behavior and dev smoke coverage. No separate lint pass is claimed.

The four groups cover:

- `OE-CURRENT`: actual eleven-module `Session.start_new(1)`, original PR08 entry, Catalog command, original prepare/Attention and shared read-view query.
- `OE-PRIVACY`: unknown person/source, actual but unoffered request and missing player clue rejection; repeated queries leave authoritative state and input ledger unchanged.
- `OE-REDUCER`: controlled successful actual PR08 response, normal full round, original ledger/reducer agreement, duplicate command, component saved-ledger reconstruction and original rest/plan command kinds.
- `OE-REJECTIONS`: actual record-practice action followed by spent-actor rejection, actual initial phase rejection, and a copied read-view resource counterfactual compared to original prepare.

The successful roll is explicitly controlled. The unoffered-request fixture changes only a copied prayer-system list and preserves sealed archive roots with a shallow top-level state copy. Deep-copying encoded history would remove its read-only identity and create an invalid fixture. The privacy assertion also requires the reducer cursor to reach `next_fact`, so an interrupted reducer cannot satisfy it by returning the untouched empty ledger. Formal `StateView.participant` already materializes current entity/fact dictionaries; production eligibility detachment does not copy authoritative encoded archive roots.

The checks do not establish natural success rates, all twenty route combinations, complete Session save/continue, scheduling, FIFO, debt, service bounds, UI appearance or human keyboard/mouse acceptance. DREAM/PR06 aliases are explicitly static review scope.

`formal-01` and `formal-02` retain the original implementer's two failures. The first had a global-class self-reference parse failure despite process exit 0. The second had an invalid deep-copied archive fixture and a typed Nil error despite all four report rows saying pass; strict engine-error scanning correctly rejected it. The independent repair changed only this fixture and retained the privacy assertions. `repair-01` remains a prior passing execution (6.236 seconds), but its unknown-material example stopped at the person selector. `presentation-01` replaces only that query with POWER_LISTEN over a known domain and an actual unknown source, explicitly requiring rejection at the source field. It is a source-selector check, not a claim of material-transfer coverage. Final `finish-02` execution: 6.235 seconds, 87 unchanged runtime inputs, all four groups pass, parse/core/dev exit 0 with no engine errors. It follows EOF whitespace corrections in action_catalog.gd (one LF) and player_knowledge.gd (one CRLF); presentation-01 and finish-01 remain previous passing runs.

The delivery JSON is `docs/qa/opportunity-eligibility-results.json`. Its `runtimeInputHashes` come verbatim from the actual execution; `sourceHashes` separately bind the current acceptance contract after the run. Contract binding never rewrites a previous runtime report or claims those prose documents were execution inputs. All historical failure directories remain intact.
