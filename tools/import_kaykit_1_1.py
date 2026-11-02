#!/usr/bin/env python3
"""Download the exact free KayKit 1.1 files recorded in the supplied ZIP.

This is a repository asset import only; files are kept outside game/ so Godot and
the Android export do not automatically consume the entire library.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "third_party" / "kaykit_character_animations_1_1"
MANIFEST = DEST / "manifest.json"


def git_blob_sha1(content: bytes) -> str:
    return hashlib.sha1(
        b"blob " + str(len(content)).encode("ascii") + b"\0" + content
    ).hexdigest()


def verify(content: bytes, entry: dict) -> bool:
    return len(content) == entry["size"] and git_blob_sha1(content) == entry["git_sha1"]


def download(url: str) -> bytes:
    last_error = None
    for attempt in range(4):
        try:
            request = Request(url, headers={"User-Agent": "Bijatyka-KayKit-asset-import/1.1"})
            with urlopen(request, timeout=120) as response:
                return response.read()
        except Exception as exc:
            last_error = exc
            if attempt != 3:
                time.sleep(attempt + 2)
    raise RuntimeError(f"Failed to download {url}: {last_error}")


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert manifest["version"] == "1.1"
    assert manifest["upstream_binary_mirror"] == "GeorgeQLe/assets-kaykit-3d-characters"
    files = manifest["files"]
    assert len(files) == manifest["file_count"] == 33
    assert sum(f["size"] for f in files) == manifest["total_bytes"] == 42940665

    root_url = (
        "https://raw.githubusercontent.com/"
        + manifest["upstream_binary_mirror"]
        + "/"
        + manifest["upstream_commit"]
        + "/"
        + manifest["upstream_path"]
        + "/"
    )
    downloaded = 0
    for entry in files:
        name = entry["path"]
        posix_path = PurePosixPath(name)
        if (posix_path.is_absolute() or ".." in posix_path.parts or
                not name.startswith(("Animations/", "Mannequin Character/")) or
                not name.endswith((".glb", ".fbx", ".png"))):
            raise ValueError(f"Unsafe asset path in manifest: {name}")

        destination = DEST.joinpath(*posix_path.parts)
        if destination.is_file() and verify(destination.read_bytes(), entry):
            print(f"VERIFIED (existing): {name}", flush=True)
            continue

        url = root_url + quote(name, safe="/")
        content = download(url)
        if not verify(content, entry):
            raise RuntimeError(f"Asset checksum/size mismatch: {name}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        downloaded += 1
        print(f"VERIFIED ({len(content)} bytes): {name}", flush=True)

    print(f"PASS: {len(files)} verified files; {downloaded} downloaded; "
          f"{manifest['total_bytes']} source bytes", flush=True)


if __name__ == "__main__":
    main()
