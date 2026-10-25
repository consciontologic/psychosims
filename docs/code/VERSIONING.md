# Versioned contracts

[`config/ruleset_registry.yaml`](../../config/ruleset_registry.yaml) pins
the current session ruleset `0.2.0` and manifest schema registry `0.1.0`.
Bundled manifests keep their existing identities/checksums. New games select
`0.2.0` separately; saved sessions keep their stored `0.1.0` or `poc-1.0.0`
profile. New game explicitly adopts the current rules while retaining career
and completed transcripts. An optional `approach_mask` is serialized only when
nonzero, preserving the original canonical replay bytes. Saved
state has its own version/checksum validation and may not silently reinterpret
old actions under changed rules.

Use major versions for incompatible contracts, minor versions for compatible
additions, and patches only when serialized behavior remains compatible. Any
change to serialized outcomes must deliberately update the relevant canonical,
replay and deterministic fixtures after reviewing the behavior change.

Reusable receipt schemas still record ruleset identity, but no server validates
or certifies browser progression. See [schemas](SHARED_SCHEMAS.md) and
[serialization](SERIALIZATION.md). A static cache build ID identifies public
resource bytes and worker policy; it is distinct from a gameplay ruleset version.
