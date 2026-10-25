#!/usr/bin/env python3
"""Resolved CycloneDX inventory, license evidence and read-only drift gate."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
from urllib.parse import quote, unquote, urljoin, urlparse
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
DART_PROJECTS = ('config', 'packages/psychemas', 'packages/psycore', 'tools', 'app')
ALLOWED_LICENSES = frozenset(('MIT', 'Apache-2.0', 'BSD-2-Clause', 'BSD-3-Clause',
                              'ISC', '0BSD', 'Zlib', 'BSL-1.0', 'Unicode-DFS-2016'))
MATCH = re.compile(r'^(.*): ([\w.+-]+) \(confidence: ([0-9.]+), offset: (\d+), extent: (\d+)\)$')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(args, cwd):
    print(f'[{cwd}] {args[0]} {" ".join(args[1:3])}', file=sys.stderr)
    process = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=300)
    if process.returncode:
        raise RuntimeError(f'{args[0]} exited {process.returncode}:\n{process.stdout}\n{process.stderr}')
    return process.stdout


def parse_licenses(output, paths, reviewed=None):
    reviewed = reviewed or {}
    matches = {path: [] for path in paths}
    for line in output.splitlines():
        match = MATCH.fullmatch(line)
        if not match:
            raise ValueError(f'unrecognized license classifier output: {line[:200]}')
        filename, name, confidence, offset, extent = match.groups()
        path = Path(filename)
        if path not in matches:
            raise ValueError('license classifier reported an unrequested file')
        exception = reviewed.get(path, {})
        allowed = name in ALLOWED_LICENSES or (
            name in exception.get('additional_ids', [])
            and digest(path) == exception.get('license_sha256'))
        if not allowed or float(confidence) < 0.9:
            raise ValueError(f'license policy requires review: {path}: {name} ({confidence})')
        matches[path].append({'id': name, 'confidence': float(confidence),
                              'offset': int(offset), 'extent': int(extent)})
    result = {}
    for path, evidence in matches.items():
        if not evidence:
            raise ValueError(f'unclassified license: {path}')
        result[path] = {'ids': sorted({item['id'] for item in evidence}),
                        'sha256': digest(path),
                        'matches': sorted(evidence, key=lambda item: (item['offset'], item['id']))}
    return result


def write_or_check(path, document, write=False):
    content = json.dumps(document, indent=2, ensure_ascii=False, sort_keys=True) + '\n'
    if write:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.json.tmp')
        temporary.write_text(content, encoding='utf-8')
        temporary.replace(path)
    elif not path.is_file():
        raise ValueError('reviewed inventory missing; run scripts/sbom.sh --write and review the result')
    elif path.read_text(encoding='utf-8') != content:
        raise ValueError('dependency or license drift; run scripts/sbom.sh --write and review the diff')


def license_files(directory, fallback=None):
    paths = sorted(path for path in directory.iterdir()
                   if re.fullmatch(r'(LICENSE|LICENCE|COPYING)(\..*)?', path.name, re.I)
                   and path.is_file())
    if not paths and fallback:
        paths = [fallback]
    if not paths:
        raise ValueError(f'license file missing: {directory}')
    for path in paths:
        if path.is_symlink() or path.stat().st_size > 2 * 1024 * 1024:
            raise ValueError(f'unsafe license file: {path}')
        path.read_text(encoding='utf-8')
    return paths


def property_value(name, value):
    return {'name': f'psychosims:{name}', 'value': str(value)}


def validate_hosted_identity(package, lock):
    entry = lock.get('packages', {}).get(package['name'], {})
    description = entry.get('description', {})
    if (entry.get('source') != 'hosted' or entry.get('version') != package['version']
            or not isinstance(description, dict)
            or description.get('name') != package['name']
            or description.get('url') != 'https://pub.dev'):
        raise ValueError(f'unsupported or mismatched hosted package identity: {package["name"]}')


def validate_npm_entry(name, entry):
    uri = urlparse(entry.get('resolved', ''))
    if (uri.scheme != 'https' or uri.netloc != 'registry.npmjs.org'
            or uri.query or uri.fragment or not uri.path.endswith('.tgz')):
        raise ValueError(f'unreviewed npm registry: {name}')
    if (entry.get('link') or not isinstance(entry.get('version'), str)
            or not entry['version'] or not re.fullmatch(r'(?:@[a-z0-9._-]+/)?[a-z0-9._-]+', name)):
        raise ValueError(f'unsupported npm package identity: {name}')
    integrity = entry.get('integrity', '')
    if not re.fullmatch(r'sha512-[A-Za-z0-9+/]{86}==', integrity):
        raise ValueError(f'npm SHA-512 integrity required: {name}')
    return base64.b64decode(integrity[7:], validate=True)


def npm_archive_licenses(blob, name, entry):
    expected = validate_npm_entry(name, entry)
    if hashlib.sha512(blob).digest() != expected:
        raise ValueError(f'npm archive integrity mismatch: {name}')
    licenses, metadata = {}, None
    total_size, total_files = 0, 0
    with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as archive:
        for item in archive:
            total_size += item.size
            total_files += 1
            if total_size > 256 * 1024 * 1024 or total_files > 20000:
                raise ValueError('npm archive exceeds expanded size limit')
            basename = item.name.removeprefix('package/')
            selected = item.name == 'package/package.json' or (
                item.name.startswith('package/') and '/' not in basename and
                re.fullmatch(r'(LICENSE|LICENCE|COPYING)(\..*)?', basename, re.I))
            if not selected:
                continue
            if not item.isfile() or item.size > 2 * 1024 * 1024:
                raise ValueError(f'npm license/metadata must be a bounded regular file: {name}')
            data = archive.extractfile(item).read()
            if item.name == 'package/package.json':
                if metadata is not None:
                    raise ValueError(f'duplicate npm package metadata: {name}')
                metadata = json.loads(data)
            else:
                if basename in licenses:
                    raise ValueError(f'duplicate npm license: {name}')
                data.decode('utf-8')
                licenses[basename] = data
    if not metadata or metadata.get('name') != name or metadata.get('version') != entry['version']:
        raise ValueError(f'npm archive identity mismatch: {name}')
    if not licenses:
        raise ValueError(f'npm archive license missing: {name}')
    return licenses


def npm_license_files(root, name, entry):
    expected = validate_npm_entry(name, entry)
    cache = root / '.tools/npm-license-cache' / expected.hex()
    if any(path.is_symlink() for path in (cache, cache.parent, cache.parent.parent)):
        raise ValueError('unsafe npm license cache')
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / 'package.tgz'
    if archive.is_symlink():
        raise ValueError('unsafe npm archive cache')
    if archive.is_file():
        if archive.stat().st_size > 64 * 1024 * 1024:
            raise ValueError('npm archive exceeds size limit')
        blob = archive.read_bytes()
    else:
        # Download metadata/notice bytes only; no npm lifecycle code executes.
        with urlopen(entry['resolved'], timeout=60) as response:
            if response.geturl() != entry['resolved']:
                raise ValueError('npm archive redirect requires review')
            blob = response.read(64 * 1024 * 1024 + 1)
    if len(blob) > 64 * 1024 * 1024:
        raise ValueError('npm archive exceeds size limit')
    contents = npm_archive_licenses(blob, name, entry)
    archive.write_bytes(blob)
    paths = []
    for filename, data in sorted(contents.items()):
        path = cache / filename
        if path.is_symlink():
            raise ValueError('unsafe npm license cache file')
        path.write_bytes(data)
        paths.append(path)
    return paths


def npm_lock_graph(manifest, lock):
    entries = lock.get('packages', {})
    if lock.get('lockfileVersion') != 3 or '' not in entries:
        raise ValueError('npm lockfile v3 required')
    for field in ('name', 'dependencies', 'devDependencies', 'optionalDependencies'):
        if manifest.get(field) != entries[''].get(field):
            raise ValueError(f'npm manifest/lock mismatch: {field}')
    graph = {}
    for location, entry in entries.items():
        if location:
            if (not location.startswith('node_modules/') or '\\' in location
                    or '..' in location.split('/') or '.' in location.split('/')):
                raise ValueError('unsupported npm lock path')
            name = location.rsplit('node_modules/', 1)[-1]
            validate_npm_entry(name, entry)
        else:
            name = manifest['name']
        graph[location] = {'name': name, 'entry': entry, 'dependencies': set()}
    for location, package in graph.items():
        entry = package['entry']
        dependencies = {**entry.get('dependencies', {}), **entry.get('optionalDependencies', {})}
        if not location:
            dependencies.update(entry.get('devDependencies', {}))
        for name in dependencies:
            current = location
            while True:
                candidate = f'{current}/node_modules/{name}' if current else f'node_modules/{name}'
                if candidate in graph:
                    package['dependencies'].add(candidate)
                    break
                if not current:
                    raise ValueError(f'npm locked dependency missing: {location}: {name}')
                current = current.rsplit('/node_modules/', 1)[0] if '/node_modules/' in current else ''
    return graph


def collect(root):
    components, edges, inputs, licenses = {}, {}, {}, {}
    policy_path = root / 'scripts/license_policy.json'
    policy = json.loads(policy_path.read_text(encoding='utf-8'))
    if policy['schema_version'] != 1:
        raise ValueError('unsupported license policy version')
    inputs['scripts/license_policy.json'] = digest(policy_path)

    def add(ref, name, version, source, files, purl=None):
        if ref not in components:
            components[ref] = {'type': 'library', 'bom-ref': ref, 'name': name,
                               'version': version, 'properties': [property_value('source', source)]}
            if purl:
                components[ref]['purl'] = purl
            edges[ref] = set()
            licenses[ref] = files
        elif {digest(path) for path in licenses[ref]} != {digest(path) for path in files}:
            raise ValueError(f'conflicting license bytes for {ref}')
        return ref

    for project in DART_PROJECTS:
        directory = root / project
        lock = directory / 'pubspec.lock'
        # Missing lock fails before a resolver can create one.
        before = digest(lock)
        tool = 'flutter' if project == 'app' else 'dart'
        command([tool, 'pub', 'get', '--enforce-lockfile'], directory)
        if digest(lock) != before:
            raise ValueError(f'lockfile changed during enforced resolution: {project}')
        inputs[f'{project}/pubspec.lock'] = before
        inputs[f'{project}/pubspec.yaml'] = digest(directory / 'pubspec.yaml')
        graph = json.loads(command([tool, 'pub', 'deps', '--json'], directory))
        lock_metadata = json.loads(command(['dart', str(root / 'config/tool/lockfile_metadata.dart'),
                                            str(lock)], root))
        if not graph.get('packages') or not graph.get('root'):
            raise ValueError(f'empty resolved graph: {project}')
        config_path = directory / '.dart_tool/package_config.json'
        package_paths = {}
        for package in json.loads(config_path.read_text())['packages']:
            uri = urlparse(urljoin(config_path.as_uri(), package['rootUri']))
            if uri.scheme != 'file' or uri.netloc:
                raise ValueError('non-local resolved package configuration')
            package_paths[package['name']] = Path(unquote(uri.path)).resolve()
        sdk_versions = {sdk['name'].lower(): sdk['version'] for sdk in graph['sdks']}
        refs = {}
        for package in graph['packages']:
            name, source = package['name'], package['source']
            location, fallback = package_paths[name], None
            if source in ('root', 'path'):
                if not location.is_relative_to(root):
                    raise ValueError(f'unreviewed external path dependency: {name}')
                version = package['version']
                ref, source = f'local:{name}@{version}', 'workspace'
                fallback, purl = root / 'LICENSE', None
            elif source == 'sdk':
                version = sdk_versions['flutter']
                ref, purl = f'sdk:flutter/{name}@{version}', None
                flutter_root = Path(shutil.which('flutter')).resolve().parents[1]
                if not location.is_relative_to(flutter_root):
                    raise ValueError(f'unexpected SDK package location: {name}')
                fallback = flutter_root / 'LICENSE'
            elif source == 'hosted':
                validate_hosted_identity(package, lock_metadata)
                version = package['version']
                purl = f'pkg:pub/{quote(name, safe="")}@{quote(version, safe="")}'
                ref = purl
            else:
                raise ValueError(f'unreviewed dependency source: {name}: {source}')
            refs[name] = add(ref, name, version, source, license_files(location, fallback), purl)
        for package in graph['packages']:
            edges[refs[package['name']]].update(refs[name] for name in package['dependencies'])

    for filename in ('package.json', 'package-lock.json'):
        inputs[filename] = digest(root / filename)
    npm_graph = npm_lock_graph(json.loads((root / 'package.json').read_text()),
                               json.loads((root / 'package-lock.json').read_text()))
    npm_refs = {}
    for location, package in npm_graph.items():
        name, entry = package['name'], package['entry']
        version = entry.get('version', 'workspace')
        purl = f'pkg:npm/{quote(name, safe="/")}@{quote(version, safe="")}' if location else None
        ref = purl or f'local:{name}@{version}'
        files = npm_license_files(root, name, entry) if location else [root / 'LICENSE']
        npm_refs[location] = add(ref, name, version, 'npm' if location else 'workspace', files, purl)
        if location:
            components[ref]['properties'].append(property_value('npm-integrity', entry['integrity']))
    for location, package in npm_graph.items():
        edges[npm_refs[location]].update(npm_refs[name] for name in package['dependencies'])

    classifier = root / '.tools/bin/identify_license'
    if not classifier.is_file():
        raise ValueError('identify_license missing; run scripts/bootstrap.sh --tools-only')
    paths = sorted({path.resolve() for files in licenses.values() for path in files})
    output = command([str(classifier), '-threshold', '0.9', '-timeout', '120s', *map(str, paths)], root)
    reviewed = {}
    for ref, entry in policy['reviewed_components'].items():
        if ref not in licenses:
            raise ValueError(f'stale license review: {ref}')
        for path in licenses[ref]:
            if digest(path) == entry['license_sha256']:
                reviewed[path.resolve()] = entry
        if not any(path.resolve() in reviewed for path in licenses[ref]):
            raise ValueError(f'license changed since review: {ref}')
        components[ref]['properties'].append(property_value('distribution-obligation', entry['obligation']))
        components[ref]['properties'].append(property_value('source-reference', entry['source']))
    evidence = parse_licenses(output, paths, reviewed)
    for ref, files in licenses.items():
        ids = sorted({identifier for path in files for identifier in evidence[path.resolve()]['ids']})
        components[ref]['licenses'] = [{'license': {'id': name}} for name in ids]
        for path in sorted(files):
            value = {'file': path.name, **evidence[path.resolve()]}
            components[ref]['properties'].append(property_value('license-evidence', json.dumps(value, sort_keys=True)))
        components[ref]['properties'].sort(key=lambda value: (value['name'], value['value']))
    properties = [property_value(f'input:{path}', sha) for path, sha in sorted(inputs.items())]
    properties.extend([
        property_value('license-classifier', 'google/licenseclassifier@3cfbab2d0e0d; threshold=0.9'),
        property_value('coverage', 'Resolved Dart packages including dev/SDK packages and all locked npm QA dependencies, including optional platform packages. No game backend, native inference or bundled model dependencies. Flutter engine internals and downloaded browser test binaries are not enumerated by package-level metadata.'),
    ])
    return {'bomFormat': 'CycloneDX', 'specVersion': '1.6', 'version': 1,
            'metadata': {'properties': properties},
            'components': [components[key] for key in sorted(components)],
            'dependencies': [{'ref': key, 'dependsOn': sorted(edges[key])} for key in sorted(edges)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='update inventory for review')
    options = parser.parse_args()
    try:
        document = collect(ROOT)
        target = ROOT / 'docs/reports/dependency-inventory.cdx.json'
        write_or_check(target, document, options.write)
        print(f'{"Updated" if options.write else "Verified"} {len(document["components"])} components: {target.relative_to(ROOT)}')
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, tarfile.TarError, subprocess.TimeoutExpired) as error:
        print(f'Dependency gate failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
