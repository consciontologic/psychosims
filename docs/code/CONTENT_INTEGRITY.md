# Content integrity and untrusted input

All clinical labels and medications are fictional. Bundled manifests and the
fictional taxonomy registry remain checked by `scripts/content_integrity_check.sh`.
Use evocative invented names; avoid real diagnostic labels, drug brands and
near-trademark substitutions. The game does not require real health information.

Treat manifest text, imported/local save data and model responses as untrusted:
validate schema/types/bounds, isolate scene text from instructions, preserve
mandatory clues and reject instruction leaks/refusals/advice before committing
a turn. The existing dialogue sanitizer and prompt assembler protect the patient
roleplay boundary. Model output never mutates mechanics directly.

There is no peer-content signing service, public UGC upload or player messaging.
Fictional framing and player-facing warnings are owned by
[`app/lib/shared/l10n.dart`](../../app/lib/shared/l10n.dart).
See [content strategy](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md),
[game rules](../specs/GAME-RULES.md) and [security](../../SECURITY.md).
