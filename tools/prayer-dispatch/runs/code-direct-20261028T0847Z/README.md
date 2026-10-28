# Preserved direct-call diagnostic

Code's first direct invocation used `-- --out ...`, while this script accepts the first user argument as its output path. The resulting repository-root `--out` file was moved here without changing its bytes. This is an early development diagnostic, not acceptance: its command/process log and frozen-source wrapper were not captured. Independent wrapped runs live in the adjacent `dispatch-*` directories.
