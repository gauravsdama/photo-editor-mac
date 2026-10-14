# Original RAW and edits

The working document is an original photograph plus an adjustment recipe. Save edits writes that recipe; export renders pixels. Both operations leave the original intact.

## Persistence

`.photoedit` is versioned JSON. XMP contains the same document as a base64 JSON payload in `https://gauravdama.dev/photo-editor/1.0/`, inside an RDF description. The schema includes the source reference, SHA-256 fingerprint, adjustment values, export format, document version, and pipeline version. Writes are atomic. Unknown versions, invalid values, oversized documents, missing originals, and changed originals are rejected. Source hashing and document I/O run away from the main actor.

Existing XMP fields from other applications are retained during updates. Photo Editor does not translate Adobe Camera Raw, Lightroom, or darktable recipes. Conventional same-basename `.xmp` and full-source-filename `.xmp` are recognized; the full filename wins when both exist. Sidecars are restored only when the original reference and fingerprint match. No recipe is silently applied to a different photograph.

Same-directory documents use a relative source filename. Move those documents with their originals. Documents saved in a different directory currently use an absolute source reference and require the original to remain at that location. Projects do not embed/copy RAW data. A future source-relink interface can extend this without changing the schema's integrity check.

## Decoding and color

RAW input must be recognized by ImageIO as RAW and supported by CIRAWFilter. Import renders the actual RAW output with draft mode disabled and a bounded scale. The decoder requests maximum extended dynamic range and disables gamut mapping to retain available highlight/color headroom. Export reopens the original at full resolution. Apple supplies demosaicing and camera profiles; exact supported cameras and decoder behavior depend on macOS. The current project stores the application pipeline version, but does not pin an Apple RAW decoder version across OS upgrades.

The working context uses 32-bit floating-point channels in extended linear Display P3. Adjusted previews use a bounded half-float image with an explicit profile, avoiding an 8-bit preview as the source of exported pixels. Preview display is still constrained by the screen and AppKit's presentation; the app is not a calibrated HDR proofing tool.

## Rendered masters

The default rendered master is an uncompressed 32-bit floating-point TIFF at the original oriented dimensions. Its extended linear Display P3 profile and floating-point samples retain negative and above-one pixel values supported by the pipeline. This is lossless encoding of the rendered pixels, not reconstruction of RAW sensor data. RAW development and chosen adjustments still determine those pixels. Larger channel depth does not add captured detail.

16-bit integer TIFF is uncompressed and uses a non-extended RGB source profile when available, otherwise Display P3. Its fixed integer range can clip extended-range values. It is useful when another editor cannot read floating-point TIFF. JPEG remains an 8-bit sRGB delivery option. The UI and default API export use ImageIO's maximum encoder quality (1.0), at original resolution and directly from the original source, never from a preview or prior export. The API can explicitly request lower quality. Tests inspect the encoded JPEG for all-one quantization tables and valid platform sampling. Current ImageIO emits 4:4:4 color, while macOS 15 uses 4:2:2; ImageIO does not expose a public sampling control. Quality 1 is still lossy JPEG; TIFF remains the lossless rendered master.

Some simple macOS conversion/viewing paths do not display floating-point TIFF correctly. Verification reads the actual float samples through ImageIO/Core Image and confirms the embedded ICC data. Use the 16-bit TIFF option for those viewers; keep the 32-bit file as the rendered precision master.

Capture dates, camera/exposure fields, artist/copyright information, IPTC descriptions, and GPS metadata are retained where ImageIO supports those standard dictionaries. Proprietary MakerNotes, source thumbnails, and sensor/layout tags are intentionally omitted from rendered images. Orientation is normalized and dimensions updated. Saving edits preserves the complete original file byte-for-byte, including metadata that rendered formats cannot represent.

Full-resolution floating-point TIFF requires substantially more memory and disk space than JPEG. A 24 MP RGBA float render alone is about 384 MB before decoder/context allocations. Preview bounds do not eliminate this export cost. TIFFs above the platform encoder's file-size limits report failure rather than downgrade precision.

## Verification

The portable suite generates fixtures to verify 16/32-bit output, floating-point sample flags, unclipped extended highlights, profile embedding, metadata, source preservation, project/sidecar restoration, third-party XMP preservation, invalid RAW rejection, and changed-original rejection. A real camera-file test runs when `PHOTO_EDITOR_RAW_FIXTURE` points to a local RAW; no personal or upstream photograph is copied into this repository. The multi-manufacturer evidence and fixture provenance are recorded in [RAW compatibility verification](RAW_COMPATIBILITY.md).

On 2026-10-07, an existing local Nikon NEF passed actual sensor decoding, bounded preview, oriented full-resolution TIFF export, and original SHA-256 preservation. This verifies that camera file on this Mac, not every RAW format. Native smoke testing also saves/reopens a project before exporting the floating-point TIFF.
