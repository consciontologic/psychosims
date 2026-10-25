# Toolchain

The current web build pins **Flutter 3.38.5 / Dart 3.10.4**. Verification also
uses Python 3 and Node.js; CI selects Node 22. Project dependency lockfiles are
committed and consumed by the bootstrap/build commands.

Browser acceptance uses the project's pinned Playwright dependency and Chromium.
GitHub-hosted CI provisions Chromium and OS dependencies in its disposable
runner. Local work must follow [AGENTS.md](../../AGENTS.md) system-change rules;
do not install workstation OS packages implicitly.

There is no Go, CMake, native inference or database prerequisite for the active
product. The pure Dart core and schemas remain shared with the Flutter app.
See [build](BUILD.md) and [hosting](../guides/STATIC_HOSTING.md).
