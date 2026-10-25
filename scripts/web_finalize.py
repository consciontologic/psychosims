#!/usr/bin/env python3
"""Audit the public Flutter artifact and compile its offline inventory."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import quote

EXTENSIONS = {".html", ".js", ".css", ".json", ".wasm", ".frag", ".bin", ".ttf", ".otf", ".woff", ".woff2", ".png", ".svg", ".ico", ".webp", ".jpg", ".jpeg", ".mp3", ".ogg", ".wav", ".txt"}
SPECIAL = {"CNAME", ".nojekyll", "NOTICES", "LICENSE", "Roboto_LICENSE.txt"}
EXCLUDED = {"service_worker.js", "offline-manifest.json"}
KEY_PATTERN = re.compile(rb"sk-or-v1-[a-zA-Z0-9]{32,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")


def clean_output(repo: Path) -> None:
    """Remove only the generated web tree, never follow linked output paths."""
    for relative in ("app", "app/build", "app/build/web"):
        if (repo / relative).is_symlink():
            raise ValueError(f"Refusing linked build directory: {relative}")
    output = repo / "app/build/web"
    if output.exists():
        shutil.rmtree(output)


def inventory(root: Path) -> dict[str, str]:
    resources = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise ValueError(f"Symlink forbidden in Pages artifact: {relative}")
        if not path.is_file() or relative in EXCLUDED:
            continue
        if (path.suffix not in EXTENSIONS and path.name not in SPECIAL) or any(
            part.startswith(".env") or part.lower() in {"secrets.json", "credentials.json", "server", "node_modules"}
            for part in path.relative_to(root).parts
        ):
            raise ValueError(f"Non-public/static file in Pages artifact: {relative}")
        data = path.read_bytes()
        if KEY_PATTERN.search(data):
            raise ValueError(f"Potential credential in Pages artifact: {relative}")
        resources["/" + quote(relative, safe="/")] = hashlib.sha256(data).hexdigest()
    return resources


def finalize(root: Path, template: Path) -> dict:
    # Flutter emits build bookkeeping and engine symbol tables; neither is read
    # by this release app. Keep diagnostics/source information out of publication.
    metadata = [root / ".last_build_id", *root.glob("canvaskit/**/*.symbols")]
    for path in metadata:
        if path.is_symlink():
            raise ValueError("Linked metadata is not a generated build artifact")
        if path.is_file():
            path.unlink()
    resources = inventory(root)
    required = {"/index.html", "/main.dart.js", "/flutter_bootstrap.js", "/manifest.json", "/CNAME", "/icons/Icon-192.png", "/icons/Icon-512.png"}
    if not required.issubset(resources):
        raise ValueError(f"Missing required static resources: {sorted(required - resources.keys())}")
    manifest = json.loads((root / "manifest.json").read_text())
    if manifest["scope"] != "/" or manifest["start_url"] != "/#/":
        raise ValueError("Manifest must use root scope and hash navigation")
    if '<base href="/">' not in (root / "index.html").read_text():
        raise ValueError("Production shell must use root base path")
    if (root / "CNAME").read_text().strip() != "psychosim.com":
        raise ValueError("Unexpected custom domain")
    template_source = template.read_text()
    build_id = hashlib.sha256((json.dumps(resources, sort_keys=True) + template_source).encode()).hexdigest()[:24]
    worker = template_source.replace("__BUILD_ID__", build_id).replace("__STATIC_RESOURCES__", json.dumps(resources, sort_keys=True))
    (root / "service_worker.js").write_text(worker)
    audit = {"build_id": build_id, "resource_count": len(resources), "total_bytes": sum((root / path.relative_to(root)).stat().st_size for path in root.rglob("*") if path.is_file()), "resources": resources}
    (root / "offline-manifest.json").write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    return audit


if __name__ == "__main__":
    repo = Path(__file__).resolve().parent.parent
    if sys.argv[1:] == ["--clean"]:
        clean_output(repo)
        print("Cleaned generated app/build/web output; other artifacts preserved")
        sys.exit(0)
    result = finalize(Path(sys.argv[1]) if len(sys.argv) > 1 else repo / "app/build/web", repo / "app/web/service_worker.js")
    print(f"Static artifact audited: {result['resource_count']} cached resources, {result['total_bytes']} bytes, build {result['build_id']}")
