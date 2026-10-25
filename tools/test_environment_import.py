"""Offline safety checks for the local GLB installer."""
import tempfile
import unittest
from pathlib import Path
from tools.install_environment_packs import _validate_glb, install

class EnvironmentImportTests(unittest.TestCase):
    def test_corrupt_glb_rejected(self):
        for blob in (b"", b"hello", b"glTF" + b"\x00" * 25):
            with self.assertRaises(ValueError):
                _validate_glb(blob)

    def test_missing_archives_leave_destination_untouched(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaises(FileNotFoundError):
                install(root, root / "output")
            self.assertFalse((root / "output").exists())

if __name__ == "__main__":
    unittest.main()
