#!/usr/bin/env python3
"""Inspect and stage user-supplied asset archives outside the Godot export root.

Staging does not change gameplay or imply the pack is licensed for redistribution.
ZIP works with the standard library. RAR needs: pip install rarfile, plus a
supported unrar/unar/bsdtar tool available on PATH.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import stat
import tempfile
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
STAGING_ROOT = ROOT / "third_party" / "candidate_asset_packs"
PACK_NAMES = {
    "MeleeWeaponsPack.rar": "melee_weapons",
    "PSX Graveyard Demo.zip": "psx_graveyard",
    "Humane-Basics.rar": "humane_basics",
    "KayKit_FantasyWeaponsBits_1.0_FREE.zip": "kaykit_fantasy_weapons",
}
MAX_FILES = 4000
MAX_FILE_BYTES = 128 * 1024 * 1024
MAX_TOTAL_BYTES = 512 * 1024 * 1024
# Keep potentially unsafe executables and nested archives out of source control.
DENIED_EXTENSIONS = {
    ".exe", ".dll", ".so", ".dylib", ".apk", ".aab", ".jar", ".zip",
    ".rar", ".7z", ".tar", ".gz", ".sh", ".bat", ".cmd", ".ps1",
}


def _safe_path(filename: str) -> PurePosixPath:
    if not filename or "\x00" in filename or "\\" in filename:
        raise ValueError(f"Unsafe archive path: {filename!r}")
    path = PurePosixPath(filename)
    if (
        path.is_absolute()
        or not path.parts
        or any(part in ("", ".", "..") for part in path.parts)
        or ":" in path.parts[0]
    ):
        raise ValueError(f"Unsafe archive path: {filename!r}")
    if len(path.parts) == 1 and path.name.casefold() == "manifest.json":
        raise ValueError("Archive cannot supply the staging manifest file")
    return path


def _open_archive(archive: Path):
    if archive.suffix.lower() == ".zip":
        return ZipFile(archive)
    if archive.suffix.lower() == ".rar":
        try:
            import rarfile
        except ImportError as exc:
            raise RuntimeError(
                "RAR support requires 'pip install rarfile' and unrar/unar/bsdtar"
            ) from exc
        return rarfile.RarFile(archive)
    raise ValueError("Expected a .zip or .rar archive")


def inspect(archive: Path):
    checked = []
    seen = set()
    total = 0
    with _open_archive(archive) as source:
        for item in source.infolist():
            if item.is_dir():
                continue
            name = item.filename
            rel = _safe_path(name)
            size = item.file_size
            is_link = (
                stat.S_ISLNK(item.external_attr >> 16)
                if archive.suffix.lower() == ".zip"
                else bool(getattr(item, "is_symlink", lambda: False)())
            )
            if is_link:
                raise ValueError(f"Archive contains a symbolic link: {name}")
            if size < 0 or size > MAX_FILE_BYTES:
                raise ValueError(f"Unexpected member size: {name} ({size})")
            total += size
            if total > MAX_TOTAL_BYTES:
                raise ValueError("Archive exceeds 512 MiB uncompressed limit")
            key = str(rel).casefold()
            if key in seen:
                raise ValueError(f"Duplicate or case-conflicting asset: {name}")
            seen.add(key)
            if len(seen) > MAX_FILES:
                raise ValueError("Archive has too many files")
            if rel.suffix.lower() in DENIED_EXTENSIONS:
                raise ValueError(f"Executable or nested archive is not staged: {name}")
            checked.append((rel, size, name))
    if not checked:
        raise ValueError("Archive has no regular files")
    return checked, total


def stage(archive: Path, destination_root: Path, dry_run: bool = False) -> dict:
    archive = archive.resolve(strict=True)
    if archive.name not in PACK_NAMES:
        raise ValueError(
            "Unrecognized pack; expected one of: " + ", ".join(PACK_NAMES)
        )
    entries, total = inspect(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    slug = PACK_NAMES[archive.name]
    destination = destination_root / slug
    manifest = {
        "pack": archive.name,
        "archive_sha256": digest,
        "file_count": len(entries),
        "uncompressed_bytes": total,
        "license_review_required": True,
        "godot_gameplay_integrated": False,
        "files": [],
    }
    if dry_run:
        manifest["files"] = [
            {"path": str(rel), "size": size} for rel, size, _name in entries
        ]
        return manifest

    if destination.exists():
        raise FileExistsError(
            f"{destination} already exists: refusing to overwrite reviewed assets"
        )
    destination_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=f".{slug}-", dir=destination_root
    ) as tmp:
        temporary = Path(tmp)
        with _open_archive(archive) as source:
            for rel, size, member_name in entries:
                content = source.read(member_name)
                if len(content) != size:
                    raise ValueError(f"Decompressed member size mismatch: {rel}")
                target = temporary.joinpath(*rel.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                manifest["files"].append({
                    "path": str(rel),
                    "size": size,
                    "sha256": hashlib.sha256(content).hexdigest(),
                })
        (temporary / "manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        shutil.move(str(temporary), str(destination))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "archives", type=Path, nargs="+",
        help="One or more of the four uploaded archives, with their original filenames",
    )
    parser.add_argument(
        "--destination", type=Path, default=STAGING_ROOT,
        help="Directory to stage packs; defaults to third_party/candidate_asset_packs",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    for archive in args.archives:
        report = stage(archive, args.destination, args.dry_run)
        print(json.dumps({
            "pack": report["pack"],
            "file_count": report["file_count"],
            "uncompressed_bytes": report["uncompressed_bytes"],
            "archive_sha256": report["archive_sha256"],
            "integrated": report["godot_gameplay_integrated"],
            "dry_run": args.dry_run,
        }, indent=2))


if __name__ == "__main__":
    main()
