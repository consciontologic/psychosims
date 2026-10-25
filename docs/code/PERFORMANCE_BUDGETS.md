# Browser performance and resource bounds

The static artifact is audited as a complete resource inventory, including local
CanvasKit and fonts. The [PWA report](../reports/2026-10-23-static-pwa.md) records
the measured artifact/cache size and build identity. Those are local build
measurements, not a mobile-network latency promise.

The core uses deterministic bounded rules and headless sandbox tests. The
browser caps prompt context, response size and network deadlines; see
[architecture](ARCHITECTURE.md). Responsive checks cover 360–1440 px with
intermediate widths and resizing while preserving state.

A complete first download is required before offline readiness. Failed caching
must remain visible and preserve an older complete version. Browser quota and
storage eviction are external constraints. Physical-device frame rate, battery,
and slow-network installation measurements remain separate acceptance work;
removed native-model latency/RAM budgets do not describe this app.
