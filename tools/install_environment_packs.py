#!/usr/bin/env python3
"""Install curated uploaded GLBs locally; no license/redistribution claim.

Requires system libarchive for RAR. Never publishes or commits the original art.
"""
import argparse
import ctypes as ct
import ctypes.util
import hashlib
import json
import struct
from pathlib import Path

LIGHT = (
    ("Metro_PSX.rar", "Metro_PSX/Models/Metro.glb", "metro/Metro.glb"),
    ("FantasyStylizedPack.rar", "RocksPack.rar", "rocks/RocksPack.glb", "RocksPack.glb"),
    ("FantasyStylizedPack.rar", "CementeryPack.rar", "cemetery/CementeryPack.glb", "CementeryPack.glb"),
)
HEAVY = (
    ("Abandoned_House.rar", "Abandoned_House/Models/Abandoned_House.glb", "abandoned_house/Abandoned_House.glb"),
    ("FantasyStylizedPack.rar", "TreesPack.rar", "trees/TreesPack.glb", "TreesPack.glb"),
)
MAX_SOURCE_BYTES = 40_000_000
MAX_SCENE_TRIANGLES = 180_000


def _rar_member(archive: bytes, member: str) -> bytes:
    libname = ctypes.util.find_library("archive")
    if not libname:
        raise RuntimeError("libarchive is required to read RAR packs")
    lib = ct.CDLL(libname)
    signatures = {
        "archive_read_new": ([], ct.c_void_p),
        "archive_read_support_format_all": ([ct.c_void_p], ct.c_int),
        "archive_read_support_filter_all": ([ct.c_void_p], ct.c_int),
        "archive_read_open_memory": ([ct.c_void_p, ct.c_void_p, ct.c_size_t], ct.c_int),
        "archive_read_next_header": ([ct.c_void_p, ct.POINTER(ct.c_void_p)], ct.c_int),
        "archive_entry_pathname": ([ct.c_void_p], ct.c_char_p),
        "archive_entry_size": ([ct.c_void_p], ct.c_int64),
        "archive_entry_filetype": ([ct.c_void_p], ct.c_uint),
        "archive_read_data": ([ct.c_void_p, ct.c_void_p, ct.c_size_t], ct.c_ssize_t),
        "archive_read_data_skip": ([ct.c_void_p], ct.c_int),
        "archive_read_free": ([ct.c_void_p], ct.c_int),
    }
    for name, (argtypes, restype) in signatures.items():
        fn = getattr(lib, name)
        fn.argtypes, fn.restype = argtypes, restype
    handle = lib.archive_read_new()
    backing = ct.create_string_buffer(archive)
    output = None
    try:
        lib.archive_read_support_format_all(handle)
        lib.archive_read_support_filter_all(handle)
        if lib.archive_read_open_memory(handle, backing, len(archive)) != 0:
            raise ValueError("Cannot open RAR archive")
        while True:
            entry = ct.c_void_p()
            result = lib.archive_read_next_header(handle, ct.byref(entry))
            if result == 1:
                break
            if result != 0:
                raise ValueError("Corrupt or unsupported RAR archive")
            filename = lib.archive_entry_pathname(entry).decode("utf-8", errors="replace")
            if filename != member:
                lib.archive_read_data_skip(handle)
                continue
            size = lib.archive_entry_size(entry)
            if lib.archive_entry_filetype(entry) != 0o100000:
                raise ValueError("Archive member is not a regular file")
            if size < 0 or size > MAX_SOURCE_BYTES:
                raise ValueError("Selected member exceeds size limit")
            buffer = ct.create_string_buffer(128 * 1024)
            parts = []
            current = 0
            while True:
                n = lib.archive_read_data(handle, buffer, len(buffer))
                if n < 0:
                    raise ValueError("Corrupt RAR content")
                if n == 0:
                    break
                current += n
                if current > size:
                    raise ValueError("Archive member size mismatch")
                parts.append(buffer.raw[:n])
            if current != size:
                raise ValueError("Truncated archive member")
            output = b"".join(parts)
            break
        if output is None:
            raise FileNotFoundError(f"Archive member not found: {member}")
        return output
    finally:
        lib.archive_read_free(handle)


def _validate_glb(content: bytes) -> dict:
    if len(content) < 20:
        raise ValueError("GLB is too short")
    magic, version, file_bytes = struct.unpack_from("<4sII", content, 0)
    if magic != b"glTF" or version != 2 or file_bytes != len(content):
        raise ValueError("Invalid glTF 2 binary header")
    json_bytes, chunk_type = struct.unpack_from("<I4s", content, 12)
    if chunk_type != b"JSON" or json_bytes > len(content) - 20:
        raise ValueError("Missing GLB JSON chunk")
    doc = json.loads(content[20:20 + json_bytes])
    if any("uri" in node for node in doc.get("images", []) + doc.get("buffers", [])):
        raise ValueError("Selected GLB depends on external images or buffers")
    accessors = doc.get("accessors", [])
    triangles = 0
    for mesh in doc.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) != 4:
                continue
            idx = primitive.get("indices")
            if idx is not None:
                triangles += accessors[idx]["count"] // 3
    if triangles > MAX_SCENE_TRIANGLES:
        raise ValueError("GLB exceeds static-scene triangle budget")
    return {
        "nodes": len(doc.get("nodes", [])),
        "meshes": len(doc.get("meshes", [])),
        "triangles_approx": triangles,
        "textures": len(doc.get("textures", [])),
        "animations": len(doc.get("animations", [])),
    }


def install(source: Path, output: Path, include_heavy: bool = False) -> dict:
    selected = LIGHT + (HEAVY if include_heavy else ())
    inventory = []
    contents = []
    for spec in selected:
        archive_name, member_name, output_name, *inside = spec
        archive = source / archive_name
        if not archive.is_file():
            raise FileNotFoundError(f"Required source archive missing: {archive}")
        if archive.stat().st_size > 100_000_000:
            raise ValueError(f"Unexpectedly large source archive: {archive_name}")
        source_bytes = archive.read_bytes()
        extracted = _rar_member(source_bytes, member_name)
        if inside:
            extracted = _rar_member(extracted, inside[0])
        info = _validate_glb(extracted)
        inventory.append({
            "source_archive": archive_name,
            "archive_sha256": hashlib.sha256(source_bytes).hexdigest(),
            "asset_path": output_name,
            "sha256": hashlib.sha256(extracted).hexdigest(),
            "bytes": len(extracted),
            **info,
        })
        contents.append((output_name, extracted))
    if sum(len(blob) for _, blob in contents) > 45_000_000:
        raise ValueError("Import exceeds local asset budget")
    if output.exists() and any(output.iterdir()):
        raise FileExistsError("Destination is not empty; refusing to overwrite assets")
    output.mkdir(parents=True, exist_ok=True)
    for name, blob in contents:
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(blob)
    result = {
        "purpose": "local optional environment props for Godot 4.7.2",
        "license_status": "UNVERIFIED - NOT CLEARED FOR PUBLIC REDISTRIBUTION",
        "activation_setting": "gameplay/enable_community_environment_packs",
        "assets": inventory,
    }
    (output / "asset_manifest.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Folder with ORIGINAL RAR archives")
    parser.add_argument("--output", type=Path, required=True, help="Target: game/assets/environment/community")
    parser.add_argument("--include-heavy", action="store_true", help="Stage house/trees for profiling only")
    args = parser.parse_args()
    print(json.dumps(install(args.source, args.output, args.include_heavy), indent=2))


if __name__ == "__main__":
    main()
