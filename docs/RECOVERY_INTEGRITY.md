# Recovery integrity

Checked on 2026-10-14 after restoring the Photo Editor repository.

- The working branch points to `51bd44cdd87f66a781fd5318044e6f71375fba6c`, the recovered non-destructive RAW workflow commit.
- The recovery bundle in `Downloads/photo-editor-mac-recovered-20261007.bundle` verifies as complete and records the same branch tip and public parent `a8a676a2405586a4e958b1d7897b6b73e063f62c`.
- The source tree, tests, resources, package manifest, licensing files, release scripts, and UI-copy inventory referenced by the recovered commit are present.
- Git's unreachable objects contain an earlier pre-commit index snapshot. The recovered commit contains all of that snapshot plus additional API authentication and concurrent-shutdown assertions; it does not omit files found there.
- `IntegrationSource.swift`, `OmniGenService.swift`, and the generic setup script were deliberately removed by the recovered commit. They represented sibling-checkout or unused integration scaffolding and are not runtime requirements.
- No camera RAW fixture survives in the repository, Git history, bundle, Spotlight index, or normal user media folders. Tests therefore use temporary CC0 fixtures with recorded hashes and provenance. Personal camera files remain outside Git.
- The restored ignored `.build` directory initially retained module-cache paths from the deleted recovery checkout. `swift package clean` removed that generated state; a fresh build and test run no longer depend on the old path.

The bundle remains the recovery backstop. It should be retained until the new commit is pushed and remote CI passes.
