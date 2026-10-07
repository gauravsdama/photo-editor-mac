#!/usr/bin/env python3
"""Create/check an exact Markdown inventory of visible SwiftUI string literals."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


CALLS = (
    "Text", "Label", "Button", "Picker", "Toggle", "TextField", "DatePicker",
    "ContentUnavailableView", "navigationTitle", "accessibilityLabel", "help",
    "StatusRow", "ComparisonPane", "Menu",
)
DYNAMIC_LINE_CONTEXTS = (
    "window.title", "selectedImageName =", "actionAPIStatus =", "exportStatus =",
    "recordCommand(", "editsStatus =", "alert.messageText", "alert.informativeText",
    "addButton(withTitle:", "throw PhotoWorkflowError(",
)
VISIBLE_VALUE_ARGUMENTS = ("deviceName:", "recommendedRenderingBackend:")
LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')
BEGIN = "<!-- BEGIN EXTRACTED_UI_TEXTS -->"
END = "<!-- END EXTRACTED_UI_TEXTS -->"


def extract(source: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in sorted(source.rglob("*.swift")):
        if any(part.startswith(".") or part in {"build", "SourcePackages"} for part in path.parts):
            continue
        relative_path = str(path.relative_to(source))
        in_adjustment_titles = False
        in_export_errors = False
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if relative_path in {"AdjustmentState.swift", "PhotoSource.swift"}:
                if "var title: String" in line:
                    in_adjustment_titles = True
                elif in_adjustment_titles and ("var range:" in line or "var fileExtension:" in line):
                    in_adjustment_titles = False
            if relative_path == "ImageExporter.swift":
                if "var errorDescription:" in line:
                    in_export_errors = True
                elif in_export_errors and line.startswith("struct ImageExportResult"):
                    in_export_errors = False

            visible_value_argument = any(argument in line for argument in VISIBLE_VALUE_ARGUMENTS)
            include_line = (
                any(call in line for call in CALLS)
                or any(context in line for context in DYNAMIC_LINE_CONTEXTS)
                or in_adjustment_titles
                or in_export_errors
                or (relative_path == "GPUStatus.swift" and visible_value_argument)
            )
            if not include_line:
                continue
            literals = LITERAL.findall(line)
            if relative_path == "GPUStatus.swift" and visible_value_argument and literals:
                literals = literals[-1:]
            for literal in literals:
                if re.search(rf"systemImage\s*:\s*{re.escape(literal)}", line):
                    continue
                if "keyboardShortcut" in line or "specifier:" in line:
                    continue
                value = literal[1:-1]
                if not value.strip():
                    continue
                rows.append({"file": relative_path, "line": line_number, "literal": literal, "value": value})
    return rows


def render(name: str, rows: list[dict[str, object]]) -> str:
    payload = json.dumps(rows, ensure_ascii=False, indent=2)
    return f"""# {name} UI text inventory

This file is an exact, source-extracted inventory of visible SwiftUI text, dynamic status text, adjustment labels, and first-party errors. Runtime messages supplied by macOS are system-owned and are not enumerated. This is a review record, not a writing prompt: preserve wording, punctuation, capitalization, and interpolation exactly unless the owner approves a specific change. Do not add promotional headings, eyebrows, AI signposting, or explanatory copy without an explicit product decision.

{BEGIN}
```json
{payload}
```
{END}
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rows = extract(args.source)
    expected = render(args.name, rows)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != expected:
            print(f"UI text inventory is stale; regenerate {args.output}", file=sys.stderr)
            return 1
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(expected, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
