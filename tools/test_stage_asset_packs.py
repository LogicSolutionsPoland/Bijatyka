"""Offline safety tests for the four-pack staging importer."""
import json
import stat
import tempfile
import unittest
import warnings
from pathlib import Path
from zipfile import ZipFile, ZipInfo

from tools.stage_asset_packs import stage


class StageAssetPacksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "PSX Graveyard Demo.zip"
        self.destination = self.root / "staged"

    def write_zip(self, names_and_contents):
        with ZipFile(self.archive, "w") as output:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                for name, content in names_and_contents:
                    output.writestr(name, content)

    def test_stage_and_sha_manifest(self):
        self.write_zip([
            ("Graveyard/stone.glb", b"sample-mesh"),
            ("Graveyard/License.txt", b"Test license"),
        ])
        report = stage(self.archive, self.destination)
        folder = self.destination / "psx_graveyard"
        self.assertEqual(report["file_count"], 2)
        self.assertFalse(report["godot_gameplay_integrated"])
        self.assertTrue(report["license_review_required"])
        self.assertEqual((folder / "Graveyard/stone.glb").read_bytes(), b"sample-mesh")
        self.assertEqual(json.loads((folder / "manifest.json").read_text())["file_count"], 2)

    def test_inspection_does_not_extract(self):
        self.write_zip([("Scene/mesh.obj", b"v 0 0 0")])
        report = stage(self.archive, self.destination, dry_run=True)
        self.assertEqual(report["file_count"], 1)
        self.assertFalse(self.destination.exists())

    def test_prevents_path_traversal(self):
        self.write_zip([("../outside.glb", b"bad")])
        with self.assertRaises(ValueError):
            stage(self.archive, self.destination)
        self.assertFalse((self.root / "outside.glb").exists())

    def test_rejects_duplicate_member(self):
        self.write_zip([("A.glb", b"one"), ("A.glb", b"two")])
        with self.assertRaises(ValueError):
            stage(self.archive, self.destination)

    def test_rejects_executables(self):
        self.write_zip([("setup.exe", b"program")])
        with self.assertRaises(ValueError):
            stage(self.archive, self.destination)

    def test_rejects_symlink(self):
        item = ZipInfo("linked.glb")
        item.create_system = 3
        item.external_attr = (stat.S_IFLNK | 0o777) << 16
        with ZipFile(self.archive, "w") as output:
            output.writestr(item, "elsewhere")
        with self.assertRaises(ValueError):
            stage(self.archive, self.destination)

    def test_never_overwrites_existing_reviewed_pack(self):
        self.write_zip([("prop.glb", b"sample")])
        stage(self.archive, self.destination)
        with self.assertRaises(FileExistsError):
            stage(self.archive, self.destination)


if __name__ == "__main__":
    unittest.main()
