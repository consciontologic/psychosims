# config/

Shared typed configuration for the deterministic game rules, progression and
browser runtime. The static app uses bundled defaults; no environment file or
server configuration is required at runtime. API credentials are managed only
in tab memory by the browser's OpenRouter client.

- `lib/` contains configuration schemas, validation and optional CLI overrides.
- `ruleset_registry.yaml` records supported rule and manifest versions.
- `test/` exercises validation and precedence.

Headless developer tools may use the existing centralized environment loader;
no module outside this package reads process environment variables directly.
See [configuration precedence](PRECEDENCE.md).
