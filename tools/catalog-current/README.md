# TASK-CATALOG — Formal Simulation Content Loading and World Generation

Current bounded revalidation covers three acceptance groups:

- **ACC-CATALOG:** load the complete current Catalog, including the original ten CSV tables; reject three temporary malformed copies representing a bad field, reference and value, without replacing the loaded Catalog.
- **ACC-WORLD:** generate fixed seeds **200 and 201** and check authored counts, institutions, lawful profiles, reachable bidirectional routes, references and population conservation.
- **ACC-GENERATION-BOUND:** remove cosmic civilization candidates from a separate in-memory Catalog and require one generation call to fail with a reason while preserving the prior world and constrained Catalog.

`scenarios.json` preserves the original three acceptance statements. This is a small current sample, not a rerun or re-signing of the historical 32-seed, simulation or load suite.

## Retained executions

- `outputs/formal-01`: editor-wide import crashed with exit `3221226356` (`0xC0000374`) after approximately 30.91 seconds. Core and startup did not run. Full editor import did **not** pass. The original wrapper is archived under `executed-source/formal-01/verify.py` and matches its recorded input SHA.
- `outputs/formal-02`: targeted Godot script parsing, all core checks and actual startup passed in **6.362 seconds**, with unchanged execution inputs. Raw logs, payload, input fingerprints and execution metadata are retained in that directory.

The three malformed-CSV rejection checks asserted nonempty errors during execution, but their saved diagnostic arrays were later cleared through shared-array aliasing. Therefore the payload does not preserve the three specific error texts. QA records this limitation; no further run was performed.

## Command and execution boundary

From the repository root, choose a new, unused attempt name:

```powershell
python tools/catalog-current/verify.py --godot 'E:/Program Files/Godot/Godot_v4.7.2-stable_win64.exe' --attempt example-new-attempt
```

The wrapper shares one **60-second** deadline across targeted `--check-only` parsing, core checks and a short startup smoke test. It stops at the first failure, retains raw output and checks input hashes before and after execution. It refuses to overwrite an existing attempt directory and does not write historical or QA reports. The command above documents reproduction; adding this README did not trigger another execution.
