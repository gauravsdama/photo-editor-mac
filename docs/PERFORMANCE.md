# Performance evidence

Run `./scripts/benchmark_macos.sh` on macOS to rebuild the release executable and execute the opt-in workflow benchmarks. The fixtures are generated in a temporary directory and are not retained.

Measurements from an arm64 Mac on 2026-10-06:

These measurements predate the floating-point RAW/TIFF workflow introduced on 2026-10-07. They describe the earlier JPEG pipeline and are not current RAW/TIFF performance promises. The new export path uses a deferred CGImage, but full-resolution high-precision masters still cost substantially more memory and disk space than JPEG.

| Scenario | Result |
|---|---:|
| Cold process launch to application callback | 0.10 s |
| 12 MP bounded import | 79.37 ms |
| 24 MP bounded import | 45.91 ms |
| 50 MP bounded import | 45.13 ms |
| First adjusted 24 MP preview | 187.07 ms |
| 60 rapid slider updates through settled preview | 149.13 ms |
| Full-resolution 24 MP JPEG export | 59.00 ms |
| Ten 12 MP open/clear cycles | 661.12 ms |
| Default Core Image 2400×1600 render | 5.45 ms |
| Software Core Image 2400×1600 render | 6.45 ms |

The synthetic JPEGs are intentionally deterministic and compress unusually well, so these figures are regression evidence rather than promises for arbitrary photographs. Earlier process-isolated decode measurements showed peak footprint changing from approximately 291 to 151 MB at 12 MP, 532 to 142 MB at 24 MP, and 1,016 to 126 MB at 50 MP after bounded ImageIO thumbnails replaced full-resolution display images.
