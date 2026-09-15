# Photo Editor for macOS

Photo Editor is a native macOS app for opening a photo, previewing non-destructive Core Image adjustments, and exporting an edited JPEG. Rendering uses Metal when a compatible device is available and falls back to Core Image's default context.

## Run locally

```sh
swift run PhaseOnePhotoEditor
```

The app requires macOS 14 or newer. It has no third-party Swift package dependencies.

## Test and package

```sh
swift test
./scripts/package_macos.sh
```

The packaging script creates an ad-hoc-signed `dist/PhotoEditor.app` for local use on this Mac. Public downloadable distribution is outside the current product scope; that future path would require an Apple Developer identity, hardened-runtime signing, and notarization.

## Optional automation API

The loopback action API is off by default. Set `PHOTO_EDITOR_ENABLE_ACTION_API=1` before launch only for a trusted local automation session. It binds to `127.0.0.1` and intentionally has no authentication because the supported boundary is one user's local Mac; do not enable it on a shared or untrusted machine. OmniGen command previews also require `PHOTO_EDITOR_PHASE_ROOT` to point at the local `phase1` checkout; OmniGen itself is not bundled or executed by the app.

## License

Copyright 2026 Gaurav Dama. Licensed under the Apache License 2.0; see [LICENSE](LICENSE).

See [release readiness](docs/RELEASE_READINESS.md) for verified scope and remaining publication decisions.
