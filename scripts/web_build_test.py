"""Static output policy tests; no Flutter or network required."""
import importlib.util
from pathlib import Path
import tempfile
import unittest


class StaticBuildPolicyTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location("web_finalize", Path(__file__).with_name("web_finalize.py"))
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ["index.html", "main.dart.js", "assets/FontManifest.json", "canvaskit/canvaskit.wasm", "assets/shaders/ink_sparkle.frag"]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")

    def test_inventory_is_complete_deterministic_and_content_addressed(self):
        first = self.module.inventory(self.root)
        self.assertEqual(set(first), {"/index.html", "/main.dart.js", "/assets/FontManifest.json", "/canvaskit/canvaskit.wasm", "/assets/shaders/ink_sparkle.frag"})
        self.assertEqual(first, self.module.inventory(self.root))
        (self.root / "main.dart.js").write_text("changed")
        self.assertNotEqual(first["/main.dart.js"], self.module.inventory(self.root)["/main.dart.js"])

    def test_rejects_secret_configuration_source_maps_and_server_binaries(self):
        for name in [".env", "private.pem", "server.exe", "main.dart.js.map", "config/secrets.json"]:
            with self.subTest(name=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture")
                with self.assertRaises(ValueError): self.module.inventory(self.root)
                path.unlink()

    def test_rejects_symlinks_outside_or_inside_build(self):
        (self.root / "linked.js").symlink_to(self.root / "main.dart.js")
        with self.assertRaises(ValueError): self.module.inventory(self.root)

    def test_only_worker_and_audit_manifest_are_excluded(self):
        (self.root / "service_worker.js").write_text("worker")
        (self.root / "offline-manifest.json").write_text("inventory")
        self.assertEqual(len(self.module.inventory(self.root)), 5)

    def test_worker_only_update_uses_separate_cache_version(self):
        import json
        for name in ["flutter_bootstrap.js", "manifest.json", "CNAME", "icons/Icon-192.png", "icons/Icon-512.png"]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        (self.root / "index.html").write_text('<base href="/">')
        (self.root / "CNAME").write_text('psychosim.com')
        (self.root / "manifest.json").write_text(json.dumps({"scope": "/", "start_url": "/#/"}))
        (self.root / ".last_build_id").write_text('build tool metadata')
        (self.root / "canvaskit/canvaskit.js.symbols").write_text('diagnostic names')
        with tempfile.TemporaryDirectory() as directory:
            template = Path(directory) / "worker.js"
            template.write_text('const cache = "__BUILD_ID__"; const resources = __STATIC_RESOURCES__;')
            first = self.module.finalize(self.root, template)
            self.assertFalse((self.root / ".last_build_id").exists())
            self.assertFalse((self.root / "canvaskit/canvaskit.js.symbols").exists())
            template.write_text(template.read_text() + '\n// A policy update')
            second = self.module.finalize(self.root, template)
            self.assertNotEqual(first["build_id"], second["build_id"])

    def test_clean_build_removes_stale_web_assets_and_preserves_other_work(self):
        output = self.root / 'app/build/web'
        output.mkdir(parents=True)
        (output / 'stale.js').write_text('old backend client')
        sibling = self.root / 'app/build/native-artifact'
        sibling.write_text('retain')
        self.module.clean_output(self.root)
        self.assertFalse(output.exists())
        self.assertEqual(sibling.read_text(), 'retain')

    def test_clean_build_refuses_symlinked_output(self):
        output = self.root / 'app/build/web'
        output.parent.mkdir(parents=True)
        other = self.root / 'other'
        other.mkdir()
        (other / 'keep.js').write_text('retain')
        output.symlink_to(other, target_is_directory=True)
        with self.assertRaises(ValueError): self.module.clean_output(self.root)
        self.assertTrue((other / 'keep.js').exists())


if __name__ == "__main__":
    unittest.main()
