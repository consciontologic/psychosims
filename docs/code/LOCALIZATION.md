# Localization and copy

Current player-facing copy is centralized in
[`app/lib/shared/l10n.dart`](../../app/lib/shared/l10n.dart); original patient
content remains in the bundled manifest. The app currently ships English copy.
Do not claim translated locales or generated ARB integration that is absent.

Core values and action identifiers remain locale-independent. Resolve labels in
the UI and preserve stable serialized values for saves/replay. New copy should
follow the existing fictional-game terminology, avoid real diagnostic advice,
and remain readable with text scaling and narrow layouts.

`scripts/check_hardcoded_strings.sh` runs in the current source gate. Changes to
copy ownership must update its checks rather than bypass them.
