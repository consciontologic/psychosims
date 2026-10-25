# Build and dependency caching

The current product uses the Dart/Flutter pub cache and repository-local
`.dart_tool/` directories. Browser acceptance uses the pinned npm lockfile and
Playwright browser cache. All are development caches, excluded from the release.

`app/build/web/` is a generated static production build; its runtime cache policy
is documented in [the hosting guide](../docs/guides/STATIC_HOSTING.md).
Golden game traces in `test_fixtures/` remain committed source evidence.

No native engine, model download, Go game server or server build cache is needed.
Flaky tests fail the gate; investigate failures instead of retrying until green.
