"""Tests for make git's local artifact cleanup."""
import tempfile
import unittest
from pathlib import Path
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "xops" / "makefile"))
import git_ops


class GitOpsTests(unittest.TestCase):
    def test_remove_test_runs_removes_only_test_results_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            test_results = root / "test-results"
            test_results.mkdir()
            (test_results / "run.json").write_text("{}")
            keep = root / "keep.txt"
            keep.write_text("keep")

            with patch.object(git_ops, "REPO_ROOT", root):
                git_ops._remove_test_runs()

            self.assertFalse(test_results.exists())
            self.assertEqual(keep.read_text(), "keep")

    def test_remove_test_runs_leaves_symlink_target_and_target_contents_intact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "saved-runs"
            target.mkdir()
            (target / "run.json").write_text("{}")
            (root / "test-results").symlink_to(target, target_is_directory=True)

            with patch.object(git_ops, "REPO_ROOT", root):
                git_ops._remove_test_runs()

            self.assertTrue((root / "test-results").is_symlink())
            self.assertEqual((target / "run.json").read_text(), "{}")


if __name__ == "__main__":
    unittest.main()
