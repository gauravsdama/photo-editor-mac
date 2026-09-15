# Photo Editor release readiness

Updated: 2026-09-15

## Product and audience

Photo Editor is for Mac users who want a small, local workflow: open a photo, preview non-destructive adjustments, reset or clear the workspace, and export a JPEG copy. The employer-facing story is a native SwiftUI shell around a Core Image adjustment graph, with debounced preview rendering off the main actor and a Metal-backed export path.

## Provenance and ownership

- Canonical first-party app inspected: `/Users/gauravsdama/git/photoEditor/phase1/PhotoEditorMac`.
- The owner confirmed that Photo Editor is original first-party work on 2026-09-15. The canonical project is initialized as its own Git repository and connected to the owner's GitHub account.
- OmniGen, RapidRAW, and TUI Image Editor are sibling upstream reference checkouts, not bundled app code. `NOTICE.md` records that boundary.
- The owner selected Apache License 2.0. `LICENSE` and the README copyright notice record that decision.

## Release controls

- The app target has no third-party Swift package dependency or lockfile requirement.
- Build outputs, runtime photos, and exports are ignored. Existing `.runtime/` files include personal photos and must never enter source control or a release archive.
- The automation API is off by default and binds only to `127.0.0.1`. The owner accepted unauthenticated access for an explicitly enabled, trusted single-user local session. Enabling it on a shared or untrusted Mac is unsupported.
- Source no longer embeds the developer's absolute checkout path. Optional OmniGen previews require an explicit `PHOTO_EDITOR_PHASE_ROOT` environment value.
- `scripts/package_macos.sh` builds and ad-hoc signs a self-contained Apple-silicon app bundle. The release decision is local build only, so Developer ID signing and notarization are not current requirements.

## Verification evidence

Verified on macOS arm64:

```text
swift test
5 tests passed, including corrupt input, large-image preview/export, source preservation, and export write failure

swift build -c release
release build succeeded

./scripts/package_macos.sh
codesign --verify --deep --strict passed

/Users/gauravsdama/git/scripts/inventory-swift-ui-copy.py --check \
  --source Sources/PhaseOnePhotoEditor \
  --output docs/product/UI_COPY_FULL.md \
  --name PhotoEditorMac
inventory matched source
```

The packaged app was also exercised through macOS accessibility on 2026-09-15: it opened an 8192×5362 PNG, changed exposure to `0.80`, rendered the adjusted preview, exported an 8192×5362 JPEG to `/tmp`, and displayed the export success state. Automated integration tests repeatedly render a 6000×4000 source under a 1200-pixel preview bound, export at full resolution, reject corrupt input, preserve the source file, and surface an unwritable target. A current empty-state screenshot and adjusted-preview screenshot were captured and visually inspected; no personal image was added to project documentation.

## Status

**Ready for local-build use after the automated checks pass.** Source provenance, licensing, large/corrupt image behavior, source preservation, and export failure handling are covered. Public downloadable distribution remains intentionally out of scope. One hardware check still cannot be completed on this machine: launch the packaged app on a second compatible Apple-silicon Mac before claiming cross-machine compatibility.
