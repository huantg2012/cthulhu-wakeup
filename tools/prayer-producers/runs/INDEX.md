# Prayer producers run archive

Acceptance is the post-wrapper-fix formal run `producers-20261028T112537Z-a3d55dfa/results.json` (56 behavior + 5 wrapper checks). Its matching fresh current report is `docs/qa/prayer-producers-final-results.json`.

Matching current regressions:

- `tools/prayer-knowledge/runs/knowledge-20261028T112534Z-aefacfe9/results.json`: 72 + 5, adapted initial prerequisites, original assertions unchanged.
- `tools/prayer-dispatch/runs/dispatch-20261028T112537Z-6177791a/results.json`: 55 + 5, explicit bootstrap and the disclosed same-institution competitor input, original assertions unchanged.

The producers/knowledge/dispatch formal reports at 11:16 UTC are superseded, not edited: all then-existing assertions passed, but independent review subsequently found the missing wrapper-proof causal parent in EVENT12B. They do not establish the final fix. The new final reports bind the changed runtime and two added checks.

Earlier failures remain intact:

- 10:27 producers: missing StateView sourced-call readers.
- 10:33:55 producers: missing local test preload (parse failure).
- 10:34:07 producers: inconsistent in-progress World/index signature; conservative implementation handoff.
- 10:46 producers: fixture setup, invalid zero-faith negative and non-stable passage prerequisite; raw environment ERROR retained.
- 10:50 producers: duplicate start ownership in fixture registration; test-tool handoff to main.
- 11:03 producers: capacity fixture assumed bootstrap ID8 was offered; final case releases capacity through actual original expiry.
- 11:03 dispatch: original same-institution twelve-turn input did not deliver; `notice-competition-20261028T1110Z/` preserves its pool/choice diagnostic. Added unrelated messenger is an explicit later component prerequisite, not a frequency result.

The 11:12 producers/dispatch and 11:03 knowledge runs are development diagnostics, not formal acceptance. Raw logs, raw results and artifact hashes are preserved for all runs. Code/test execution after handoff belongs to the main session; QA performs independent read-only final review.
