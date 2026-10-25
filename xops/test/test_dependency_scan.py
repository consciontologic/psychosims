"""Require actual scanner coverage; a tool's zero exit alone is insufficient."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('dependency_scan', ROOT / 'scripts/dependency_scan.py')
scan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scan)


class DependencyScanTests(unittest.TestCase):
    def test_static_inventory_scans_pub_and_npm_exact_versions(self):
        packages = scan.packages_from_inventory({'components': [
            {'bom-ref': 'pkg:npm/playwright@1.62.1', 'name': 'playwright', 'version': '1.62.1'},
            {'bom-ref': 'pkg:pub/crypto@3.0.7', 'name': 'crypto', 'version': '3.0.7'}]})
        self.assertEqual(packages[0]['package'], {'name': 'playwright', 'ecosystem': 'npm', 'version': '1.62.1'})
        self.assertEqual(packages[1]['package']['ecosystem'], 'Pub')

    def test_retired_or_unknown_ecosystems_do_not_silently_escape_scanning(self):
        for ref in ['pkg:golang/old@1.0', 'native:llama.cpp@abc', 'pkg:unknown/a@1']:
            with self.subTest(ref=ref), self.assertRaisesRegex(ValueError, 'unsupported'):
                scan.packages_from_inventory({'components': [{'bom-ref': ref, 'name': 'a', 'version': '1'}]})

    def test_empty_or_dropped_scanner_results_fail(self):
        requested = [{'package': {'name': 'crypto', 'version': '3.0.7', 'ecosystem': 'Pub'}}]
        with self.assertRaisesRegex(ValueError, 'dropped'):
            scan.verify_coverage(requested, {})
        scan.verify_coverage(requested, {'results': [{'packages': requested}]})

    def test_wrong_version_is_not_coverage(self):
        requested = [{'package': {'name': 'crypto', 'version': '3.0.7', 'ecosystem': 'Pub'}}]
        wrong = [{'package': {'name': 'crypto', 'version': '3.0.6', 'ecosystem': 'Pub'}}]
        with self.assertRaises(ValueError):
            scan.verify_coverage(requested, {'results': [{'packages': wrong}]})


if __name__ == '__main__':
    unittest.main()
