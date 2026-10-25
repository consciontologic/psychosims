# Identifier boundaries

Patient IDs, interaction enum values, card IDs, clue tokens and ruleset/schema
versions are stable serialized identifiers. Keep them independent of display
copy, locale, current time or Dart `hashCode` so saved actions replay identically.

Full-width derived seeds use exact `BigInt` arithmetic and decimal-string JSON
boundaries where required. Never round a seed through a JavaScript number.
The browser save has its own schema/version and checksum validation; local
session/history identifiers do not confer server or multiplayer authority.

API keys are credentials, not identifiers: never place them in routes, query
strings, filenames, logs, save keys or cache keys. Static build/cache identity is
derived from public resource contents and worker policy, not user data.
See [determinism](DETERMINISM.md), [serialization](SERIALIZATION.md) and
[versioning](VERSIONING.md).
