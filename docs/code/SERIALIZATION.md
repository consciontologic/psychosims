# Canonical serialization

Manifests, reusable receipt fixtures, and structured deltas use a byte-stable JSON encoding so
that checksums and golden fixtures are reproducible across runs and
machines.

## Rules

1. **Field order is fixed** — `toJson()` uses a literal `Map` in declaration order;
   serialization libraries must preserve insertion order.
2. **No extra whitespace** in canonical form.
3. **Numeric encoding is explicit**; ordinary safe integers remain JSON numbers.
   Full-width derived seeds use decimal strings where required to avoid
   JavaScript precision loss; fixed-point values use scaled integer units.
4. **No platform locale** in number or date formatting.
5. **Null optional fields are omitted** unless the schema marks them required.
6. **Unknown fields are ignored on parse** but preserved only if the owning
   schema allows `additionalProperties`.

## Canonical form

```json
{"id":"ent_...","schemaVersion":"0.1.0","rulesetVersion":"0.1.0","nameKey":"...","presentationKey":"..."}
```

## Golden fixtures

Every schema change that alters canonical output must update:

- `test_fixtures/manifests/sample_patient.json`
- `test_fixtures/receipts/sample_receipt.json`
- Determinism tests in `packages/psycore/`

A green test suite is the proof that serialization is stable.

## Contract compatibility

- Parse compatibility is defined by each typed schema; do not infer that arbitrary
  unknown or malformed fields are valid local-save input.
- Removing or retyping a field requires a new schema version.
- The `ruleset_version` registry records supported ranges.

Browser snapshots additionally validate types, bounds, checksum, replayed state
and terminal history before restore. Full transcripts are intentionally saved
locally, separately from structured core deltas; credentials are excluded.
See [data lifecycle](../project/DATA-LIFECYCLE.md).
