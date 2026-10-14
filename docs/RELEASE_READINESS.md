# Photo Editor release readiness

Updated: 2026-10-14

## Product and audience

Photo Editor provides a local workflow: open a photograph or supported camera RAW, preview adjustments, save an editable project or XMP sidecar, and export a full-resolution TIFF or JPEG. The native SwiftUI shell uses a shared Core Image adjustment graph, debounced rendering off the main actor, and a floating-point wide-gamut working context.

## Provenance and ownership

- Canonical first-party app inspected: this `PhotoEditorMac` repository.
- The owner confirmed that Photo Editor is original first-party work on 2026-09-15. The canonical project is initialized as its own Git repository and connected to the owner's GitHub account.
- OmniGen, RapidRAW, and TUI Image Editor are sibling upstream research references, not bundled app code or runtime integrations. `NOTICE.md` records that boundary.
- The owner selected Apache License 2.0. `LICENSE` and the README copyright notice record that decision.

## Release controls

- The app target has no third-party Swift package dependency or lockfile requirement.
- Build outputs, runtime photos, and exports are ignored. Personal photos must never enter source control or a release archive.
- The automation API is off by default and binds only to `127.0.0.1`. When enabled, it generates a per-launch bearer token for every non-health request. Request headers are limited to 16 KiB, bodies to 1 MiB, and incomplete requests time out after five seconds. API state, log, error, and export payloads do not echo complete local filesystem paths.
- Source no longer embeds the developer's absolute checkout path or requires sibling project checkouts.
- `scripts/package_macos.sh` builds a self-contained Apple-silicon app bundle, enables the hardened runtime, and supports either ad-hoc development signing or a configured Developer ID Application identity. It includes `LICENSE` and `NOTICE.md`, strips build-machine paths from the executable, validates bundle identity and contents, and restores the previous bundle if packaging fails.
- `scripts/release_macos.sh` requires an installed Developer ID Application identity and a `notarytool` keychain profile. It signs with a secure timestamp, submits the archive to Apple, staples and validates the ticket, runs Gatekeeper assessment, recreates the final ZIP, and writes its SHA-256 checksum.

## Verification evidence

Verified on macOS arm64:

```text
swift test
40 portable tests passed; the additional real-RAW test passes when PHOTO_EDITOR_RAW_FIXTURE is supplied

swift build -c release
release build succeeded

swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
strict concurrency build succeeded

./scripts/validate_repository.sh
tracked privacy and dependency boundary passed

./scripts/package_macos.sh
codesign --verify --deep --strict passed
scripts/validate_macos_app.sh passed

python3 scripts/inventory-swift-ui-copy.py --check \
  --source Sources/PhaseOnePhotoEditor \
  --output docs/product/UI_COPY_FULL.md \
  --name PhotoEditorMac
inventory matched source

dist/PhotoEditor.app/Contents/MacOS/PhaseOnePhotoEditor --ui-smoke-test
native UI smoke test passed
```

The packaged-app smoke harness creates the real window, verifies resizing and keyboard focus, opens a generated image with a long filename, changes an adjustment, saves and reopens the project, exports a floating-point TIFF, compares before/after, resets, clears, and confirms corrupt-input recovery. Fixtures live only in a temporary directory. Integration tests cover orientation, bounded previews, full-resolution export, source preservation, atomic replacement, JPEG quality, 16/32-bit TIFF precision, extended highlights, profiles, capture/GPS metadata, saved-edit restoration, foreign XMP fields, changed originals, stale imports, every adjustment, API validation/authentication, and server lifecycle. Export uses a deferred Core Graphics image and ImageIO to write a temporary file before replacement. High-precision export still requires substantial encoder/decoder memory; it does not promise preview-sized memory use.

Canon CR2, Nikon NEF, Sony ARW, and Fujifilm RAF public-domain fixtures passed the real-file workflow on macOS 26.6.2. A legacy Fujifilm RAF was correctly rejected when the system decoder could not produce sensor output. `docs/RAW_COMPATIBILITY.md` records provenance, hashes, coverage, timing, and memory evidence. Camera compatibility remains dependent on macOS's RAW decoder.

Performance evidence, including 12, 24, and 50 megapixel bounded imports, preview and export timing, repeated open/clear cycles, launch timing, renderer comparison, and measurement caveats, is recorded in `docs/PERFORMANCE.md`.

## Status

**Ready for local-build use after the automated checks pass.** Source provenance, recovery integrity, licensing, privacy, large/corrupt image behavior, source preservation, export failure handling, API authentication, and the core native workflow are covered. Public downloadable distribution is prepared but not complete on this machine: no Developer ID Application identity or `notarytool` keychain profile is installed. A second compatible Apple-silicon Mac is also required before claiming clean-machine compatibility.
