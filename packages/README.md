# packages/

Pure Dart schemas and deterministic gameplay shared by the Flutter browser app
and headless tools. The same definitions govern cards, loadouts, manifests,
structured outcomes, progression and canonical serialization.

- `psychemas/`: shared schemas and validation.
- `psycore/`: deterministic simulation, prompt assembly, progression and balance.

These packages have no application backend or native inference dependency.
Their regression tests and exact VM/JavaScript traces remain part of `make verify`.
