# Photo Editor release readiness

Updated: 2026-10-07

## Product and audience

Photo Editor provides a local workflow: open a photograph or supported camera RAW, preview adjustments, save an editable project or XMP sidecar, and export a full-resolution TIFF or JPEG. The native SwiftUI shell uses a shared Core Image adjustment graph, debounced rendering off the main actor, and a floating-point wide-gamut working context.

## Provenance and ownership

- Canonical first-party app inspected: this `PhotoEditorMac` repository.
- The owner confirmed that Photo Editor is original first-party work on 2026-09-15. The canonical project is initialized as its own Git repository and connected to the owner's GitHub account.
- OmniGen, RapidRAW, and TUI Image Editor are sibling upstream research references, not bundled app code or runtime integrations. `NOTICE.md` records that boundary.
- The owner selected Apache License 2.0. `LICENSE` and the README copyright notice record that decision.

## Release controls

- The app target has no third-party Swift package dependency or lockfile requirement.
- Build outputs, runtime photos, and exports are ignored. Existing `.runtime/` files include personal photos and must never enter source control or a release archive.
- The automation API is off by default and binds only to `127.0.0.1`. When enabled, it generates a per-launch bearer token for every non-health request. Request headers are limited to 16 KiB, bodies to 1 MiB, and incomplete requests time out after five seconds. API state, log, error, and export payloads do not echo complete local filesystem paths.
- Source no longer embeds the developer's absolute checkout path or requires sibling project checkouts.
- `scripts/package_macos.sh` builds and ad-hoc signs a self-contained Apple-silicon app bundle. It includes `LICENSE` and `NOTICE.md`, strips build-machine paths from the executable, validates bundle identity and contents, and restores the previous bundle if installation fails. The release decision is local build only, so Developer ID signing and notarization are not current requirements.

## Verification evidence

Verified on macOS arm64:

```text
swift test
39 portable tests passed; the additional real-RAW test passes when PHOTO_EDITOR_RAW_FIXTURE is supplied

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

A real local Nikon NEF passed sensor decoding, bounded preview, full-resolution floating-point TIFF export, and source hash preservation on 2026-10-07. Camera compatibility remains dependent on macOS's RAW decoder. `docs/RAW_WORKFLOW.md` records the persistence schema, color policy, metadata boundary, and compatibility limitations.

Performance evidence, including 12, 24, and 50 megapixel bounded imports, preview and export timing, repeated open/clear cycles, launch timing, renderer comparison, and measurement caveats, is recorded in `docs/PERFORMANCE.md`.

## Status

**Ready for local-build use after the automated checks pass.** Source provenance, licensing, privacy, large/corrupt image behavior, source preservation, export failure handling, API authentication, and the core native workflow are covered. Public downloadable distribution remains intentionally out of scope. One hardware check remains manual: launch the packaged app on a second compatible Apple-silicon Mac before claiming cross-machine compatibility.
