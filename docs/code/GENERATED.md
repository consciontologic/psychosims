# Generated output

`app/build/web/` and the review ZIP are generated, ignored artifacts. The web
build owns that directory and removes stale files before compiling. Its finalizer
produces `offline-manifest.json` and embeds the hashed resource inventory in the
copied worker. Edit source under `app/web/`, not generated build copies.

Dart tool state and Flutter build caches are not source. Dependency lockfiles,
content manifests, canonical fixtures and the reviewed dependency inventory are
version-controlled inputs/evidence. Do not regenerate golden gameplay fixtures
merely to clear a regression; investigate changed behavior first.

The inventory in `docs/reports/dependency-inventory.cdx.json` is refreshed only
through the explicit SBOM command. Pure-core showcase reports are reproducible
with `scripts/showcase.sh`; retain their scope and evidence date.
