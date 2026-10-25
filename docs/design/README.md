# Design and architecture decisions

- [Current game design](STARTER.md): retained gameplay, presentation and scope.
- [Visual direction](VISUAL_DIRECTION.md): painterly noir interface, original art, local fonts and asset provenance.
- [Centralized configuration](DESIGN-centralized-configuration.md): shared typed settings.
- [Threat model](THREAT-MODEL.md): browser, static cache and API boundaries.
- [GitHub Actions decision](ADR-0004-ci-provider.md): CI and separate publication.

The old server, desktop distribution, GetX and native model ADRs were retired
with their implementation under explicit user authorization. Current technical
behavior lives in [architecture](../code/ARCHITECTURE.md); the
[roadmap](../planning/ROADMAP.md) owns sequenced work.
Generic templates: [ADR](ADR.template.md), [design](DESIGN.template.md).
