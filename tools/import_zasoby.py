#!/usr/bin/env python3
"""Check and stage user-owned Bijatyka source assets without publishing them.

Usage:
    python3 tools/import_zasoby.py /path/to/source --check-only
    python3 tools/import_zasoby.py /path/to/source
    python3 tools/import_zasoby.py /path/to/source --only brackeys_vfx_bundle.zip

Raw archives are kept out of Git by Zasoby/.gitignore. This intentionally does
not extract archives or publish third-party sources to a public repository.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "Zasoby" / "manifest.json"
LOCAL = ROOT / "Zasoby" / "local"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Directory of your original asset files")
    parser.add_argument("--check-only", action="store_true", help="Validate without copying")
    parser.add_argument("--only", action="append", default=[], metavar="FILE",
                        help="Only process this exact asset filename (repeatable)")
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    if not source.is_dir():
        parser.error(f"Source directory does not exist: {source}")

    items = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    known = {item["filename"] for item in items}
    unknown = set(args.only) - known
    if unknown:
        parser.error(f"Unknown asset(s): {', '.join(sorted(unknown))}")

    wanted = [item for item in items if not args.only or item["filename"] in args.only]
    found = 0
    missing = []
    errors = []

    for item in wanted:
        name = item["filename"]
        candidate = source / name
        if not candidate.is_file():
            missing.append(name)
            continue
        size = candidate.stat().st_size
        if size != item["size_bytes"]:
            errors.append(f"{name}: size mismatch ({size} != {item['size_bytes']})")
            continue
        actual = sha256_file(candidate)
        expected = item.get("sha256")
        if expected and actual.lower() != expected.lower():
            errors.append(f"{name}: SHA-256 mismatch")
            continue

        found += 1
        status = "VERIFIED" if expected else "SIZE OK / SHA-256 COMPUTED"
        print(f"{status}: {name} [{actual}]")
        if args.check_only:
            continue

        LOCAL.mkdir(parents=True, exist_ok=True)
        destination = LOCAL / name
        # Copy atomically and verify destination bytes; never alter the source.
        temp = LOCAL / (name + ".part")
        try:
            shutil.copy2(candidate, temp)
            if sha256_file(temp) != actual:
                raise OSError("copy SHA-256 mismatch")
            os.replace(temp, destination)
        except OSError as exc:
            errors.append(f"{name}: copy failed: {exc}")
        finally:
            if temp.exists():
                temp.unlink()

    print(f"\nChecked {len(wanted)} entries, found valid {found}, "
          f"missing {len(missing)}, errors {len(errors)}.")
    if not args.only and missing:
        print("Still in Library / absent from this local directory:")
        for name in missing:
            print(f"  - {name}")
    if errors:
        print("Validation errors:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    if not found:
        print("No matching archives were found.", file=sys.stderr)
        return 2
    if not args.check_only:
        print("Staged locally in Zasoby/local/ (gitignored).")
        print("No assets were published to GitHub or integrated into Godot scenes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
