# Research results

Every sub-directory is one run: `<experiment>/<run-id>/` containing `experiment.json` (the frozen design),
`environment.json` (host and Docker snapshot), `raw.jsonl` (every trial, append-only),
`summary.json` / `summary.csv` (statistics) and `report.md` (human-readable).

Regenerate this index with `python -m research.harness index`.

Interpretation of the committed runs: [FINDINGS.md](FINDINGS.md).

| Experiment | Run | Trials | Failed | Host | Report |
|---|---|---:|---:|---|---|
| `exp01_base_image_footprint` | `20260927T053920Z` | 20 | 0 | macOS-26.6.2-arm64-arm-64bit-Mach-O | [report](exp01_base_image_footprint/20260927T053920Z/report.md) |
| `exp02_layer_cache_effectiveness` | `20260927T054055Z` | 14 | 0 | macOS-26.6.2-arm64-arm-64bit-Mach-O | [report](exp02_layer_cache_effectiveness/20260927T054055Z/report.md) |
| `exp03_multistage_vs_single` | `20260927T054136Z` | 10 | 0 | macOS-26.6.2-arm64-arm-64bit-Mach-O | [report](exp03_multistage_vs_single/20260927T054136Z/report.md) |
| `exp04_buildkit_cache_mount` | `20260927T054512Z` | 14 | 0 | macOS-26.6.2-arm64-arm-64bit-Mach-O | [report](exp04_buildkit_cache_mount/20260927T054512Z/report.md) |
