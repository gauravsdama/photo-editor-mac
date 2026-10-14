# RAW compatibility verification

Photo Editor delegates camera-file decoding to the RAW support included with macOS. Compatibility therefore depends on both the camera format and the installed macOS release. The application still verifies actual sensor decoding; an embedded JPEG thumbnail is not treated as a successful RAW import.

The repository does not contain camera files. Optional compatibility tests accept local fixtures through `PHOTO_EDITOR_RAW_FIXTURE`, and `scripts/test_raw_fixtures.sh` rejects fixtures stored inside the repository.

## Public test matrix

Verified on macOS 26.6.2 on 2026-10-14 using public-domain files from [raw.pixls.us](https://raw.pixls.us/). Its upload terms require contributors to own the file and release it under CC0. The files were downloaded to a temporary directory, matched against the repository's published SHA-256 manifest, and were not added to Git or the application bundle.

| Camera | Format | SHA-256 | Result | Peak test-process memory |
| --- | --- | --- | --- | ---: |
| Canon PowerShot S90 | CR2 | `aff72063aacf6efb224544a2e62c1edd10b3f50bcf73f2bb0ef5d3f3c6c3d894` | Passed | 370 MB |
| Nikon D1 | NEF | `7886d8b0e1257897faa7404b98fe1086ee2d95606531b6285aed83a0939b768f` | Passed | 255 MB |
| Sony SLT-A33 | ARW | `1a59856394f10d4fadb40f5ab9c6d1c89f473f4dbcdefd216fbbbbf1ad8d21f9` | Passed | 421 MB |
| Fujifilm X20 | RAF | `ccb4fad836f1561b52859c3ee01db0fef7db770980d4a84e95595da1eda72b2a` | Passed | 453 MB |
| Fujifilm FinePix E550 | RAF | `82d1010a1eb8cdf4b2de7ca30a3a4db4e96f290536f06ed2798a67c1fe81e6ae` | Rejected by the macOS decoder | 58 MB |

Each passing fixture was checked for sensor decoding, bounded preview generation, oriented full-resolution dimensions, visible adjustment output, 32-bit floating-point TIFF export, embedded color profile, normalized export orientation, non-destructive project persistence, source hash preservation, corrupt/truncated-input rejection, and temporary-file cleanup. Portable generated fixtures separately cover metadata retention, JPEG quality, 16-bit TIFF output, extended-range color, all adjustments, atomic replacement, and repeated open/clear behavior.

The measured peak includes Swift's test runner and framework loading as well as the image pipeline. It is evidence for these files on this Mac, not a fixed memory requirement or a promise that every file from the named manufacturers will decode.
