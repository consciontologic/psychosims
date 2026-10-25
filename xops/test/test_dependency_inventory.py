"""Dependency gates must reject missing evidence, stale inventory and tool errors."""
import importlib.util
import base64
import hashlib
import io
import json
from pathlib import Path
import tempfile
import tarfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('inventory', ROOT / 'scripts/sbom.py')
inventory = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir='/tmp/agent-runs', prefix='sbom-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_license_classifier_cannot_succeed_with_unclassified_files(self):
        a, b = self.root / 'a', self.root / 'b'
        a.write_text('MIT fixture')
        b.write_text('Unknown fixture')
        with self.assertRaisesRegex(ValueError, 'unclassified'):
            inventory.parse_licenses(f'{a}: MIT (confidence: 1, offset: 0, extent: 11)\n', [a, b])

    def test_incompatible_and_low_confidence_licenses_fail(self):
        path = self.root / 'LICENSE'
        path.write_text('license fixture')
        for name, confidence in [('GPL-3.0', '1'), ('MIT', '0.89')]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                inventory.parse_licenses(
                    f'{path}: {name} (confidence: {confidence}, offset: 0, extent: 15)\n', [path])

    def test_multilicense_file_cannot_hide_incompatible_license(self):
        path = self.root / 'LICENSE'
        path.write_text('mixed license')
        output = ''.join(f'{path}: {name} (confidence: 1, offset: 0, extent: 13)\n'
                         for name in ['MIT', 'AGPL-3.0'])
        with self.assertRaisesRegex(ValueError, 'policy'):
            inventory.parse_licenses(output, [path])

    def test_component_review_is_bound_to_exact_license_bytes_and_path(self):
        path, other = self.root / 'LICENSE', self.root / 'OTHER'
        path.write_text('MPL fixture')
        other.write_text('MPL fixture')
        review = {path: {'additional_ids': ['MPL-2.0'], 'license_sha256': inventory.digest(path)}}
        output = f'{path}: MPL-2.0 (confidence: 1, offset: 0, extent: 11)\n'
        self.assertEqual(inventory.parse_licenses(output, [path], review)[path]['ids'], ['MPL-2.0'])
        with self.assertRaises(ValueError):
            inventory.parse_licenses(output.replace(str(path), str(other)), [other], review)
        path.write_text('MPL fixture plus new restriction')
        with self.assertRaises(ValueError):
            inventory.parse_licenses(output, [path], review)

    def test_classifier_reports_are_deterministic_and_bind_exact_bytes(self):
        path = self.root / 'LICENSE'
        path.write_text('license fixture')
        output = f'{path}: MIT (confidence: 1, offset: 0, extent: 15)\n'
        evidence = inventory.parse_licenses(output, [path])[path]
        self.assertEqual(evidence['ids'], ['MIT'])
        self.assertEqual(evidence['sha256'], inventory.digest(path))
        path.write_text('license fixture plus new restriction')
        self.assertNotEqual(evidence['sha256'], inventory.digest(path))

    def test_inventory_check_is_read_only_and_detects_lock_or_license_drift(self):
        path = self.root / 'sbom.json'
        original = {'components': [{'version': '1.0', 'license_sha256': 'aaa'}]}
        inventory.write_or_check(path, original, write=True)
        before = path.read_bytes()
        inventory.write_or_check(path, original, write=False)
        for field, value in [('version', '1.1'), ('license_sha256', 'bbb')]:
            changed = json.loads(json.dumps(original))
            changed['components'][0][field] = value
            with self.assertRaisesRegex(ValueError, 'drift'):
                inventory.write_or_check(path, changed, write=False)
            self.assertEqual(path.read_bytes(), before)

    def test_missing_inventory_is_not_implicitly_approved(self):
        with self.assertRaisesRegex(ValueError, 'missing'):
            inventory.write_or_check(self.root / 'missing.json', {}, write=False)

    def test_resolver_failure_propagates_diagnostics(self):
        with self.assertRaisesRegex(RuntimeError, 'resolver fixture'):
            inventory.command(['bash', '-c', 'echo "resolver fixture" >&2; exit 23'], self.root)

    def npm_archive(self, name='example', version='1.0.0', license_type=None):
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w:gz') as archive:
            for filename, contents in [('package/package.json', json.dumps({'name': name, 'version': version}).encode()),
                                       ('package/LICENSE', b'MIT fixture')]:
                info = tarfile.TarInfo(filename)
                info.size = len(contents)
                if filename.endswith('LICENSE') and license_type:
                    info.type = license_type
                archive.addfile(info, io.BytesIO(contents))
        blob = data.getvalue()
        entry = {'version': '1.0.0', 'resolved': 'https://registry.npmjs.org/example/-/example-1.0.0.tgz',
                 'integrity': 'sha512-' + base64.b64encode(hashlib.sha512(blob).digest()).decode()}
        return blob, entry

    def test_npm_licenses_bind_archive_integrity_and_exact_identity(self):
        blob, entry = self.npm_archive()
        self.assertEqual(inventory.npm_archive_licenses(blob, 'example', entry), {'LICENSE': b'MIT fixture'})
        with self.assertRaisesRegex(ValueError, 'integrity'):
            inventory.npm_archive_licenses(blob + b'changed', 'example', entry)
        with self.assertRaisesRegex(ValueError, 'identity'):
            inventory.npm_archive_licenses(blob, 'different', entry)

    def test_npm_license_link_and_untrusted_registry_are_rejected(self):
        blob, entry = self.npm_archive(license_type=tarfile.SYMTYPE)
        with self.assertRaisesRegex(ValueError, 'regular'):
            inventory.npm_archive_licenses(blob, 'example', entry)
        for host in ['http://registry.npmjs.org', 'https://registry.npmjs.org.attacker.example']:
            entry['resolved'] = host + '/example.tgz'
            with self.assertRaisesRegex(ValueError, 'registry'):
                inventory.validate_npm_entry('example', entry)

    def test_npm_graph_includes_optional_packages_without_installing_them(self):
        manifest = {'name': 'qa', 'devDependencies': {'example': '1.0.0'}}
        _, entry = self.npm_archive()
        entry['optionalDependencies'] = {'darwin-only': '1.0.0'}
        optional = dict(entry, resolved='https://registry.npmjs.org/darwin-only/-/darwin-only-1.0.0.tgz')
        optional.pop('optionalDependencies')
        lock = {'lockfileVersion': 3, 'packages': {
            '': manifest, 'node_modules/example': entry, 'node_modules/darwin-only': optional}}
        graph = inventory.npm_lock_graph(manifest, lock)
        self.assertEqual(graph['']['dependencies'], {'node_modules/example'})
        self.assertEqual(graph['node_modules/example']['dependencies'], {'node_modules/darwin-only'})
        del lock['packages']['node_modules/darwin-only']
        with self.assertRaisesRegex(ValueError, 'missing'):
            inventory.npm_lock_graph(manifest, lock)

    def test_npm_manifest_lock_drift_and_external_link_fail_closed(self):
        manifest = {'name': 'qa', 'devDependencies': {'example': '1.0.0'}}
        _, entry = self.npm_archive()
        lock = {'lockfileVersion': 3, 'packages': {
            '': json.loads(json.dumps(manifest)), 'node_modules/example': entry}}
        lock['packages']['']['devDependencies']['example'] = '2.0.0'
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            inventory.npm_lock_graph(manifest, lock)
        lock['packages'][''] = manifest
        entry['link'] = True
        with self.assertRaisesRegex(ValueError, 'identity'):
            inventory.npm_lock_graph(manifest, lock)

    def test_hosted_identity_requires_public_registry_and_matching_name_version(self):
        package = {'name': 'crypto', 'source': 'hosted', 'version': '3.0.7'}
        lock = {'packages': {'crypto': {'source': 'hosted', 'version': '3.0.7',
                                      'description': {'name': 'crypto', 'url': 'https://pub.dev'}}}}
        inventory.validate_hosted_identity(package, lock)
        for field, bad in [('url', 'https://private.example'), ('url', 'https://pub.dev.attacker.example'),
                           ('name', 'different')]:
            with self.subTest(field=field, bad=bad):
                changed = json.loads(json.dumps(lock))
                changed['packages']['crypto']['description'][field] = bad
                with self.assertRaises(ValueError):
                    inventory.validate_hosted_identity(package, changed)
        lock['packages']['crypto']['version'] = '3.0.6'
        with self.assertRaises(ValueError):
            inventory.validate_hosted_identity(package, lock)


if __name__ == '__main__':
    unittest.main()
