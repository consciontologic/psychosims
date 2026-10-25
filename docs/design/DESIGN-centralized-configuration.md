# Centralized configuration authority

Shared deterministic configuration lives in [`config/`](../../config/).
Typed configuration is loaded and validated once, then passed to the core and
tools. Balance and progression values must not drift into independent UI copies.
The [balance specification](../specs/BALANCE-SPEC.md) explains numeric ownership;
source defaults and tests are the executable contract.

The browser application uses compiled public settings and bundled content.
No runtime environment variable, remote configuration service or secret file is
required. A user OpenRouter key is an in-memory credential entered in Settings;
it is never configuration source, an environment overlay or a build define.
User choices and save state are separate from shared rule configuration.

`config/` retains reusable typed contracts used by the pure-core test suite.
An unused legacy-shaped field does not activate a network service. Any future
change to these contracts must preserve consumers or deliberately update their
tests. Raw environment access outside the approved boundary is checked by
`scripts/env_read_check.sh` in the current verification gate.

See [architecture](../code/ARCHITECTURE.md) for runtime boundaries and
[versioning](../code/VERSIONING.md) for reproducible rule identities.
