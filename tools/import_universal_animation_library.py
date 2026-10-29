#!/usr/bin/env python3
"""Vendor the exact user-supplied CC0 Quaternius Standard ZIP, outside game/."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
from urllib.request import Request, urlopen
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "third_party" / "universal_animation_library_standard"
MANIFEST = DEST / "manifest.json"
ZIP_SHA256 = "cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724"
ITCH_ENDPOINT = "https://quaternius.itch.io/universal-animation-library/file/17958403?source=game_download&as_props=1"
ZIP_ROOT = "Universal Animation Library[Standard]/"


def download_official() -> bytes:
    request = Request(
        ITCH_ENDPOINT, method="POST", data=b"",
        headers={"User-Agent": "Bijatyka-UAL-Verified-Importer/1.0",
                 "Accept": "application/json",
                 "Referer": "https://quaternius.itch.io/universal-animation-library"},
    )
    with urlopen(request, timeout=40) as response:
        metadata = json.loads(response.read())
    url = metadata.get("url")
    if not isinstance(url, str) or not url.startswith("https://"):
        raise RuntimeError("Publisher did not return an HTTPS signed download URL")
    with urlopen(Request(url, headers={"User-Agent": "Bijatyka-UAL-Verified-Importer/1.0"}),
                 timeout=180) as response:
        data = response.read(32 * 1024 * 1024 + 1)
    if len(data) > 32 * 1024 * 1024:
        raise RuntimeError("Unexpectedly large publisher archive")
    return data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path,
                        help="Local user-provided ZIP; omit to fetch from the publisher")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert manifest["archive_sha256"] == ZIP_SHA256
    files = manifest["files"]
    assert len(files) == manifest["file_count"] == 9
    assert sum(f["size"] for f in files) == manifest["total_bytes"] == 63648179
    data = args.archive.read_bytes() if args.archive else download_official()
    if hashlib.sha256(data).hexdigest() != ZIP_SHA256:
        raise ValueError("ZIP SHA-256 differs from the user's uploaded archive")
    with ZipFile(io.BytesIO(data)) as zf:
        actual = {name for name in zf.namelist() if not name.endswith("/")}
        expected = {ZIP_ROOT + f["path"] for f in files}
        if actual != expected:
            raise ValueError("Unexpected ZIP content (missing or extra files)")
        for f in files:
            relative = PurePosixPath(f["path"])
            if relative.is_absolute() or ".." in relative.parts or not relative.parts:
                raise ValueError("Unsafe ZIP path")
            info = zf.getinfo(ZIP_ROOT + f["path"])
            if info.file_size != f["size"] or info.file_size > 30_000_000:
                raise ValueError("Unexpected file size: " + f["path"])
            content = zf.read(info)
            if hashlib.sha256(content).hexdigest() != f["sha256"]:
                raise ValueError("File SHA-256 mismatch: " + f["path"])
            dest = DEST.joinpath(*relative.parts)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(content)
            print("VERIFIED {} ({} bytes)".format(f["path"], len(content)), flush=True)
    print("PASS: {} original publisher files ({} bytes)".format(
        len(files), manifest["total_bytes"]), flush=True)


if __name__ == "__main__":
    main()
