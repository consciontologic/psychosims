# Prompt assembly and response bounds

The pure `PromptAssembler` owns the fictional roleplay frame, manifest context,
required clues, bounded history and recent dialogue. Mandatory frame content is
never dropped to make space; oldest conversation turns are removed first.
An over-budget fixed frame fails before a request is sent.

The browser uses a conservative UTF-8 byte counter, a **32,000-unit input budget**
and **1,024-unit reserved output allowance** in the assembler. It takes at most
`manifest.maxHistoryTurns` recent non-practice dialogue entries. These are local
sizing limits, not measured tokens from the selected provider's tokenizer.

The transport separately checks a conservative byte-based context estimate
against validated catalog context length, using its own default **2,048-token
output allowance** when no explicit output limit is requested. The current game
does not send a `max_tokens` field. A catalog/context rejection is visible and
never silently substitutes another model. The transport has independent response
size/time limits; accepted patient dialogue must satisfy the existing quality
contract, including the **600-character** maximum.

Tests cover mandatory content, deterministic truncation, refusal/clue/roleplay
checks, malformed streams, partial preservation and no silent replay. Old local
GGUF/tokenizer measurements are retired; they do not characterize an online model.
See [architecture](../code/ARCHITECTURE.md) for current transport limits.
