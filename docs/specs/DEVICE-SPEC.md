# Browser and device support

The production target is a static Flutter web PWA. Runtime assets, CanvasKit,
fonts and scenario content are bundled. No native inference binary, local model
weights, platform login plugin or device-specific model tier is required.

| Surface | Current acceptance |
|---|---|
| Mobile layout | 360 and 480 px, safe areas, scrolling and touch controls. |
| Tablet/intermediate layout | 600, 768 and 1024 px with preserved navigation/state. |
| Desktop layout | 1440 px, constrained readable width, pointer and keyboard. |
| Accessibility | 200% text, high contrast, reduced motion, focus and semantics checks. |
| Offline/browser | Production Chromium reload, complete cache, save/transcript persistence, deep links and installability diagnostics. |

The [implementation report](../reports/2026-10-23-static-pwa.md) contains exact
versions and evidence. Physical Android/iOS installation and device screen-reader
acceptance remain manual; browser install UI varies. HTTPS is required except
for secure localhost development. Use the dedicated `localhost:18763` preview
origin; changing ports/hosts changes the save and cache scope.
