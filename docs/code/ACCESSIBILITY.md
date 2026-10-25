# Accessibility baseline

The browser app provides semantic labels, readable transcript semantics,
keyboard navigation and visible focus, touch controls, safe areas and scrollable
layouts. The existing purple Material theme adapts to high contrast and reduced
motion. Large text must reflow without hiding controls or losing state.

Current automated evidence covers six widths (360, 480, 600, 768, 1024, 1440 px),
resizing, 200% text, high contrast, reduced motion, labels and keyboard actions.
[Production screenshots and test results](../reports/2026-10-23-static-pwa.md)
show the current acceptance scope. They do not establish physical screen-reader
or every-device certification.

Keep presentation/accessibility logic outside deterministic rules. Preserve
stable action identifiers while improving spoken and displayed labels.
