# Photo Editor for macOS

Photo Editor is a native macOS app for opening photographs and supported camera RAW files, saving non-destructive adjustments, and exporting full-resolution rendered TIFF or JPEG images. Rendering uses Metal when a compatible device is available and falls back to Core Image's default context.

## Original RAW and saved edits

Use **Save edits…** to save a `.photoedit` project or an XMP sidecar. These documents reference the original and store every adjustment, the export setting, a format/pipeline version, and a SHA-256 fingerprint. **Open edits…** restores the original and adjustments; opening a photograph also checks adjacent `photo.xmp` and `photo.nef.xmp` sidecars. The original file remains unchanged. Keep the original and edit document together when moving them. A document stored beside the original uses a relative filename; one stored elsewhere uses an absolute reference.

**Export rendered image…** writes the finished pixels separately. The default is uncompressed **32-bit floating-point TIFF**, with an embedded extended linear Display P3 profile. This retains floating-point precision and extended-range pixel values from the rendering pipeline. **16-bit TIFF** is also available for broader editing compatibility; it preserves a suitable source RGB profile or uses Display P3. JPEG is an optional 8-bit sRGB delivery format at maximum encoder quality. Increasing output bit depth cannot restore detail missing from the original.

RAW validation checks the detected file type and actually renders sensor data with Apple's RAW decoder. Camera support depends on the installed macOS version. A readable embedded thumbnail is insufficient. XMP uses a Photo Editor namespace and preserves existing third-party fields; other applications do not automatically understand Photo Editor's adjustment recipe.

Exports retain standard capture/descriptive EXIF, TIFF, IPTC, and GPS fields supported by ImageIO, including location when present. Orientation and pixel dimensions are updated for the rendered image. Proprietary MakerNotes, embedded source thumbnails, sensor data, and conflicting layout/color tags are not copied into rendered files. The unchanged original retains all original metadata. See [RAW workflow](docs/RAW_WORKFLOW.md) for the precision and compatibility details.

## Run locally

```sh
swift run PhaseOnePhotoEditor
```

The app requires macOS 14 or newer. It has no third-party Swift package dependencies.

## Test and package

```sh
swift test
./scripts/validate_repository.sh
./scripts/package_macos.sh
./scripts/smoke_test_macos.sh
```

The packaging script creates an ad-hoc-signed `dist/PhotoEditor.app` for local use on this Mac. Public downloadable distribution is outside the current product scope; that future path would require an Apple Developer identity, hardened-runtime signing, and notarization.

For opt-in performance measurements, run `./scripts/benchmark_macos.sh`. Results and measurement caveats are recorded in [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Optional automation API

The loopback action API is off by default. Set `PHOTO_EDITOR_ENABLE_ACTION_API=1` before launching from a terminal to enable it. The app binds to `127.0.0.1`, generates a new bearer token for that launch, and prints the token to standard error. Send it as `Authorization: Bearer <token>` for every request except `GET /health`; never publish or reuse the token.

## License

Copyright 2026 Gaurav Dama. Licensed under the Apache License 2.0; see [LICENSE](LICENSE).

See [release readiness](docs/RELEASE_READINESS.md) for verified scope and remaining publication decisions.
