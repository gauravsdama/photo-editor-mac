# Performance evidence

Run `./scripts/benchmark_macos.sh` on macOS to rebuild the release executable and execute the opt-in workflow benchmarks. The fixtures are generated in a temporary directory and are not retained.

Measurements from an arm64 Mac running macOS 26.6.2 on 2026-10-14:

| Scenario | Result |
|---|---:|
| Cold process launch to application callback | 0.46 s |
| Cold launch maximum resident set | 69 MB |
| 12 MP bounded import | 74.13 ms |
| 24 MP bounded import | 44.52 ms |
| 50 MP bounded import | 43.91 ms |
| First adjusted 24 MP preview | 318.57 ms |
| 60 rapid slider updates through settled preview | 119.28 ms |
| Full-resolution 24 MP JPEG export | 41.72 ms |
| Ten 12 MP open/clear cycles | 642.69 ms |
| Default Core Image 2400×1600 render | 5.03 ms |
| Software Core Image 2400×1600 render | 4.83 ms |
| Workflow test-process maximum resident set | 293 MB |

The synthetic JPEGs are intentionally deterministic and compress unusually well, so these figures are regression evidence rather than promises for arbitrary photographs. The export figure measures JPEG, not the larger 16-bit or 32-bit TIFF paths. Real camera-file measurements are recorded separately in [RAW compatibility verification](RAW_COMPATIBILITY.md); those tests include a full-resolution floating-point TIFF and reached 255–453 MB for the passing samples.
