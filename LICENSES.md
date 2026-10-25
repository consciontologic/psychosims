# Third-party licenses

The static Flutter web app bundles no inference models or backend services. New
AI responses use the user's OpenRouter account; model weights are not distributed
with this game.

The generated [CycloneDX inventory](docs/reports/dependency-inventory.cdx.json)
records resolved Dart packages, Flutter SDK notice files, and every package in
the npm browser-verification lockfile, including optional platform packages.
It includes dependency edges, exact versions, lockfile fingerprints, and license
text hashes. npm license text is read from SHA-512-verified registry archives;
package scripts are never executed to produce the inventory.

Flutter generates the web build's `assets/NOTICES` from dependency license texts.
Keep that file in the production artifact. Flutter and Dart use BSD-family terms
and their engine contains additional third-party notices. The exact Flutter
3.38.5 engine notice bundle has a component-specific review in
[license_policy.json](scripts/license_policy.json); this does not globally approve
unknown or copyleft licenses. Preserve the full notices and upstream covered-source
availability identified by that review. The package inventory does not enumerate
all engine internals or downloaded browser binaries used only for QA.

## Bundled fonts and original artwork

The app retains its local Roboto Regular, Medium and Bold files and their
[Apache License 2.0 text](app/assets/fonts/Roboto_LICENSE.txt). The additional
Noto Serif Regular/Bold and Noto Sans Symbols Regular files were copied
without modification from the
installed Debian font package's `/usr/share/fonts/truetype/noto/` files. Their
upstream copyright and SIL Open Font License 1.1 text are preserved in
[`NotoSerif_LICENSE.txt`](app/assets/fonts/NotoSerif_LICENSE.txt). Keep both font
notice assets in the deployed bundle; no font CDN is required.

`app/assets/art/clinic-noir.png` and
`app/assets/art/restless-hour-portrait.png` are original images generated for
Psychosims with the built-in image generation tool on 2026-10-23. They use
painterly noir art direction inspired by *Disco Elysium*; no game artwork,
logos or existing characters were copied. Prompts, provenance, exact sizes and
the 6.22 MB static-cache tradeoff are recorded in
[Visual direction](docs/design/VISUAL_DIRECTION.md). These generated assets are
project artwork, not third-party packages in the dependency inventory.

## Reproducing the checks

1. Run `scripts/bootstrap.sh --tools-only` to install pinned security tools under
   `.tools/`. Go is needed only to build these development tools; it is not part
   of the game or its deployment.
2. Run `make security.dependencies` to enforce Dart lockfiles, compare the reviewed
   inventory, classify license text, and scan exact Pub/npm versions with OSV.
3. After an intentional dependency update, run `scripts/sbom.sh --write`, inspect
   the complete inventory and license-policy diff, then repeat the gate.

The read-only check fails on dependency or license drift. Never refresh an
inventory to hide an unexpected dependency, unknown license, or changed notice.
