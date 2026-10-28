# Prayer dispatch independent QA

This suite accepts the bounded `TASK-PRAYER-DISPATCH` work, not its parent `TASK-PRAYER-ORIGINS`.

Run from the repository root with the actual installed Godot executable:

```powershell
python tools/prayer-dispatch/verify.py --godot 'E:\Program Files\Godot\Godot_v4.7.2-stable_win64.exe'
```

Add `--development` for diagnostics without replacing this suite's formal `results.json`. Every invocation gets a fresh `runs/dispatch-*` directory. Raw JSON, process output, Godot log and menu smoke output are preserved. The wrapper requires all 55 exact unique behavior IDs, process success, no Godot `ERROR` or `SCRIPT ERROR`, unchanged source hashes during execution and a two-frame project/menu parse smoke. Wrapper success cannot turn a failed behavior into a pass. On this Windows host, restricted certificate-store access may cause a genuine process error; preserve that diagnostic and rerun with the authorized unsandboxed executable rather than filtering the error.

## What the fixtures mean

- All scheduling assertions execute the actual `Turn -> World.evolve -> Events` production route. The only World override rejects publication for a rollback test; it does not implement or replace generation.
- Current published `prayer_situation` facts are explicit consumer prerequisites. Their legal people, family relations, harm/conditions and deadlines are fixtures. They prove handling of already-published sources, not that a natural accident/relationship/root producer exists.
- Capacity fillers are admitted through `World.fix_prayer_source`; target sources are fixed only by actual evolution. Free space comes from an actual failed response, which consumes the request without conflating capacity priority with membership effects.
- The pagination case uses 27 existing lawful named people/sources, then an actual managed deadline marks 24 people detained. It checks that a later page remains reachable and its cursor survives restore.
- Automatic identity notices start from an actual successful dream and explicit existing relationship/route/population prerequisites. No test supplies a target notice selection, candidate or successful identity receipt. The finite search preserves sampled seeds/turns; it does not measure frequency or balance.
- The newly discovered first-member regression is separately covered by real shallow/deep PR08, all four outcomes, with no existing cult. Successful recognition must cite its actual `member_enrolled`; current save and unchanged normalized re-sign succeed before semantic corruptions are tested. The same-turn/different-receipt counterexample also requires the intended Knowledge context error.
- Save negatives alter both the tick and corresponding current projection where needed, including RNG and scan position, so a stale copied ledger cannot be the sole rejection reason. Sampling cutoffs and commit sequences must match real Turn receipt boundaries.
- Three missing-binding fault cases check this concrete coordinator protocol only; they do not claim the later general capability guard/audit is implemented.

## Explicit exclusions

The four old BG templates remain a labeled legacy source path. This suite does not accept new raw-root -> call production, the four direction/mode production cells, atomic PR08 bootstrap, action-window handling, minimal player information projection, full Session restore, natural new-game reachability or balance. The empty Session must continue to reject unsupported CULT consumers. The no-cult PR08 regression tests its current legacy bootstrap consumer; it does not establish the future bootstrap producer contract.

The previous Knowledge suite is rerun in formal mode with the original 72 behavior and 5 wrapper assertions unchanged. Its runner only adds `--report-output` to select a fresh repository output path, `docs/qa/prayer-dispatch-knowledge-results.json`; the original formal Knowledge report is preserved. Earlier `--development` archives remain diagnostics and are not relabeled.
