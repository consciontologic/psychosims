# Build and verification

From the repository root, run `scripts/bootstrap.sh` for locked dependencies,
then `make verify` for the current Dart/Flutter, source/content, worker/cache,
build-policy and production-build checks. No backend, native compiler, model
weights or API credential is needed.

`scripts/web_build.sh` alone produces `app/build/web/` using the pinned Flutter
version. It cleans that generated output, builds release web with base `/`,
uses local web resources, then audits and hashes the static inventory.
Do not pass secrets through build defines or copy private files into web assets.

Use `make web.serve` to preview at `http://localhost:18763`; wait for **Ready
offline** before disconnecting. This dedicated origin separates Psychosims
caches/saves from unrelated projects on common ports. `make web.smoke` exercises
the actual production build with deterministic mocked AI and a real blocked
network. See the [hosting guide](../guides/STATIC_HOSTING.md) for dependencies,
commands, deployment workflow and domain setup.

The user explicitly authorized removal of the retired implementation and its
tests. The current product/core tests remain required; test deletion is not a
substitute for repairing a failing active gate.
