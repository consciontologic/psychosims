import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;

import '../shared/l10n.dart';

/// Authored fictional dialogue only: the resolved core state remains authority.
/// Uses the saved turn and recent transcript, so reloads need no extra state.
String practiceDialogue({
  required InteractionPattern action,
  required core.SimState before,
  required core.SimState after,
  required bool isTerminal,
  required Iterable<String> recentReplies,
}) {
  if (isTerminal) return L10n.browserPracticeClosing;
  final guarded =
      after.activeDefense != DefenseState.none ||
      after.trustScore < before.trustScore ||
      after.agitationLevel > before.agitationLevel;
  final replies = L10n.browserPracticeReplies(action, guarded: guarded);
  final recent = recentReplies.take(2).toSet();
  final start = (after.turn - 1) % replies.length;
  for (var offset = 0; offset < replies.length; offset++) {
    final reply = replies[(start + offset) % replies.length];
    if (!recent.contains(reply)) return reply;
  }
  return replies[start];
}
