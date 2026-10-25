import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psychosims/browser/browser_session.dart';
import 'package:psychosims/browser/browser_store.dart';
import 'package:psychosims/shared/l10n.dart';
import 'package:psychosims/shared/openrouter_client.dart';

import 'test_manifest_data.dart';

void main() {
  BrowserSession session(MemoryBrowserStore store) => BrowserSession(
    store: store,
    isOnline: () => false,
    manifestLoader: () async => testManifest(),
  );

  Map<String, dynamic> savedPayload(MemoryBrowserStore store) {
    final envelope = jsonDecode(store.value!) as Map<String, dynamic>;
    return jsonDecode(envelope['data'] as String) as Map<String, dynamic>;
  }

  test(
    'new sessions use bounded rules and repetitive choices cannot win',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      expect(savedPayload(store)['ruleset'], '0.2.0');
      for (var turn = 0; turn < 16; turn++) {
        await game.submitAction(InteractionPattern.validate);
      }
      expect(game.completed, isTrue);
      expect(game.state.turn, 16);
      expect(game.lastOutput!.outcome, SessionOutcome.fail);
      expect(game.completedSessions, hasLength(1));
      expect(game.balance('xp'), 0);
      final snapshot = store.value;
      await game.submitAction(InteractionPattern.openQuestion);
      expect(store.value, snapshot);
      final reloaded = session(store);
      await reloaded.initialize();
      expect(reloaded.ready, isTrue);
      expect(reloaded.completedSessions, game.completedSessions);
      expect(reloaded.state, game.state);
      expect(reloaded.canAct, isFalse);
      game.dispose();
      reloaded.dispose();
    },
  );

  test(
    'legacy saves replay unchanged and New game opts into bounded rules',
    () async {
      final store = MemoryBrowserStore();
      final seed = session(store);
      await seed.initialize();
      await seed.setPracticeMode(true);
      final payload = savedPayload(store);
      payload['ruleset'] = '0.1.0';
      payload['actions'] = List.filled(20, 'validate');
      payload['transcript'] = [
        for (var i = 0; i < 20; i++) ...[
          {'player': true, 'text': 'Validate', 'practice': true},
          {
            'player': false,
            'text': 'Original saved reply $i',
            'practice': true,
          },
        ],
      ];
      final data = jsonEncode(payload);
      store.value = jsonEncode({
        'data': data,
        'digest': sha256.convert(utf8.encode(data)).toString(),
      });
      final original = store.value;
      final legacy = session(store);
      await legacy.initialize();
      expect(legacy.ready, isTrue);
      expect(legacy.storageFailed, isFalse);
      expect(legacy.state.turn, 20);
      expect(legacy.state.sessionProgress, 20);
      expect(legacy.completed, isFalse);
      expect(legacy.transcript.last.text, 'Original saved reply 19');
      expect(store.value, original);
      store.failWrites = true;
      expect(await legacy.startNewGame(), isFalse);
      expect(legacy.state.turn, 20);
      expect(store.value, original);
      store.failWrites = false;
      await legacy.retrySave();
      expect(savedPayload(store)['ruleset'], '0.1.0');
      expect(await legacy.startNewGame(), isTrue);
      expect(savedPayload(store)['ruleset'], '0.2.0');
      expect(legacy.state.turn, 0);
      expect(legacy.transcript, isEmpty);
      seed.dispose();
      legacy.dispose();
    },
  );

  test(
    'new game persists a fresh session and requires initialization',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      expect(game.canStartNewGame, isFalse);
      expect(game.hasActiveProgress, isFalse);
      expect(await game.startNewGame(), isFalse);
      expect(store.value, isNull);
      await game.initialize();
      expect(game.canStartNewGame, isTrue);
      expect(game.hasActiveProgress, isFalse);
      expect(await game.startNewGame(), isTrue);
      expect(game.state.turn, 0);
      expect(game.transcript, isEmpty);
      final reloaded = session(store);
      await reloaded.initialize();
      expect(reloaded.state, game.state);
      expect(reloaded.completedSessions, isEmpty);
    },
  );

  test(
    'new game replaces only current progress and preserves career and setup',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      await game.setControllers(
        const TherapyControllerSettings(focus: FocusAxis.workspace),
      );
      game.setApiKey('test-memory-only-key');
      for (var i = 0; i < 12; i++) {
        await game.submitAction(
          i < 6 ? InteractionPattern.validate : InteractionPattern.openQuestion,
        );
      }
      expect(game.completed, isTrue);
      expect(game.lastOutput!.outcome, SessionOutcome.succeed);
      expect(game.balance('xp'), 100);
      expect(game.hasActiveProgress, isFalse);
      final completed = savedPayload(store);
      expect(await game.startNewGame(), isTrue);
      final initial = game.state;
      await game.submitAction(InteractionPattern.validate);
      expect(game.hasActiveProgress, isTrue);
      expect(game.state.turn, 1);
      expect(await game.startNewGame(), isTrue);
      expect(game.state, initial);
      expect(game.transcript, isEmpty);
      expect(game.hasActiveProgress, isFalse);
      expect(game.hasKey, isTrue);
      final fresh = savedPayload(store);
      for (final field in [
        'completed_sessions',
        'balances',
        'history',
        'loadout',
        'controllers',
        'practice',
      ]) {
        expect(fresh[field], completed[field], reason: field);
      }
      expect(store.value, isNot(contains('test-memory-only-key')));
      final reloaded = session(store);
      await reloaded.initialize();
      expect(reloaded.state, initial);
      expect(reloaded.completedSessions, game.completedSessions);
      expect(reloaded.controllers.focus, FocusAxis.workspace);
      expect(reloaded.practiceMode, isTrue);
      expect(reloaded.hasKey, isFalse);
    },
  );

  test('new game rolls back when saving the replacement fails', () async {
    final store = MemoryBrowserStore();
    final game = session(store);
    await game.initialize();
    await game.setPracticeMode(true);
    await game.submitAction(InteractionPattern.validate);
    final snapshot = store.value;
    final state = game.state;
    final transcript = game.transcript.map((t) => t.toJson()).toList();
    store.failWrites = true;
    expect(await game.startNewGame(), isFalse);
    expect(game.state, state);
    expect(game.transcript.map((t) => t.toJson()).toList(), transcript);
    expect(store.value, snapshot);
    expect(game.storageFailed, isTrue);
    expect(game.canStartNewGame, isFalse);
    expect(game.notice, L10n.browserSaveFailure);
  });

  test('new game cannot replace progress saved by a different tab', () async {
    final store = MemoryBrowserStore();
    final first = session(store);
    await first.initialize();
    await first.setPracticeMode(true);
    final second = session(store);
    await second.initialize();
    await first.submitAction(InteractionPattern.validate);
    final latest = store.value;
    expect(await second.startNewGame(), isFalse);
    expect(store.value, latest);
    expect(second.saveConflict, isTrue);
    expect(second.storageFailed, isTrue);
  });

  test('new game never clears corrupted saves', () async {
    final store = MemoryBrowserStore()..value = '{broken';
    final game = session(store);
    await game.initialize();
    expect(game.canStartNewGame, isFalse);
    expect(await game.startNewGame(), isFalse);
    expect(store.value, '{broken');
  });

  test(
    'reconnect clears only offline notices and never dispatches a request',
    () async {
      var online = false;
      var requests = 0;
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => online,
        manifestLoader: () async => testManifest(),
        client: OpenRouterClient(
          isOnline: () => online,
          clientFactory: () => MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        ),
      );
      await game.initialize();
      expect(game.notice, L10n.browserOfflineNotice);
      online = true;
      game.connectivityChanged();
      expect(game.notice, isEmpty);
      online = false;
      await game.submitAction(InteractionPattern.validate);
      expect(game.notice, L10n.browserOfflineAction);
      online = true;
      game.connectivityChanged();
      expect(game.notice, isEmpty);
      expect(game.state.turn, 0);
      expect(game.transcript, isEmpty);
      expect(requests, 0);
      game.dispose();
    },
  );

  test(
    'connection changes preserve storage and provider failure notices',
    () async {
      var online = true;
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => online,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      for (final message in [
        L10n.browserSaveFailure,
        L10n.browserCatalogFailure,
        L10n.browserRejectedNotice,
        L10n.browserResponseFailure,
      ]) {
        game.notice = message;
        online = false;
        game.connectivityChanged();
        expect(game.notice, message);
        online = true;
        game.connectivityChanged();
        expect(game.notice, message);
      }
      game.dispose();
    },
  );

  test(
    'offline practice saves mechanics and full transcript across reload',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      expect(game.lastOutput, isNull);
      await game.setPracticeMode(true);
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 1);
      expect(game.lastOutput?.nextState, game.state);
      expect(game.transcript, hasLength(2));
      final reloaded = session(store);
      await reloaded.initialize();
      expect(reloaded.state, game.state);
      expect(reloaded.lastOutput?.toJson(), game.lastOutput?.toJson());
      expect(reloaded.transcript.last.text, game.transcript.last.text);
      expect(reloaded.practiceMode, isTrue);
    },
  );

  test(
    'practice replies respond to the chosen approach and patient state',
    () async {
      Future<String> reply(
        InteractionPattern action, {
        bool pressured = false,
      }) async {
        final game = BrowserSession(
          store: MemoryBrowserStore(),
          isOnline: () => false,
          manifestLoader: () async => const ManifestLoader().load(
            Uint8List.fromList(
              utf8.encode(
                testManifestJson(
                  initialState: pressured
                      ? {'agitation': 85, 'resistance': 70, 'trust': 10}
                      : {'agitation': 20, 'resistance': 20, 'trust': 70},
                ),
              ),
            ),
          ),
        );
        await game.initialize();
        await game.setPracticeMode(true);
        await game.submitAction(action);
        final text = game.transcript.last.text;
        game.dispose();
        return text;
      }

      final question = await reply(InteractionPattern.openQuestion);
      final validation = await reply(InteractionPattern.validate);
      final reframe = await reply(InteractionPattern.reframe);
      expect({question, validation, reframe}, hasLength(3));
      expect(question, contains('thought'));
      expect(validation, contains('hear'));
      expect(reframe, contains('way'));
      final pressured = await reply(
        InteractionPattern.validate,
        pressured: true,
      );
      expect(pressured, isNot(validation));
      expect(pressured, contains('racing'));
      expect(await reply(InteractionPattern.validate), validation);
    },
  );

  test(
    'practice avoids recent repeats and continues identically after reload',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      final replies = <String>[];
      for (var i = 0; i < 12; i++) {
        await game.submitAction(InteractionPattern.validate);
        final reply = game.transcript.last.text;
        expect(replies.reversed.take(2), isNot(contains(reply)));
        replies.add(reply);
      }
      expect(replies.toSet().length, greaterThanOrEqualTo(4));
      final beforeReload = game.transcript.map((t) => t.toJson()).toList();
      final copyStore = MemoryBrowserStore()..value = store.value;
      final reloaded = session(copyStore);
      await reloaded.initialize();
      expect(reloaded.transcript.map((t) => t.toJson()).toList(), beforeReload);
      expect(copyStore.value, store.value);
      await game.submitAction(InteractionPattern.openQuestion);
      await reloaded.submitAction(InteractionPattern.openQuestion);
      expect(reloaded.state, game.state);
      expect(
        reloaded.transcript.map((t) => t.toJson()).toList(),
        game.transcript.map((t) => t.toJson()).toList(),
      );
      expect(copyStore.value, store.value);
      game.dispose();
      reloaded.dispose();
    },
  );

  test(
    'existing practice transcripts keep their original saved dialogue',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      await game.submitAction(InteractionPattern.validate);
      final payload = savedPayload(store);
      (payload['transcript'] as List).last['text'] =
          L10n.browserFallbackDialogue;
      final data = jsonEncode(payload);
      store.value = jsonEncode({
        'data': data,
        'digest': sha256.convert(utf8.encode(data)).toString(),
      });
      final snapshot = store.value;
      final restored = session(store);
      await restored.initialize();
      expect(restored.ready, isTrue);
      expect(restored.state, game.state);
      expect(restored.transcript.last.text, L10n.browserFallbackDialogue);
      expect(store.value, snapshot);
      game.dispose();
      restored.dispose();
    },
  );

  test(
    'AI actions pause offline without committing a turn or replaying',
    () async {
      final game = session(MemoryBrowserStore());
      await game.initialize();
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 0);
      expect(game.transcript, isEmpty);
      expect(game.notice, contains('offline'));
    },
  );

  test(
    'empty loadout is blocked and loadout settings persist before first turn',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      for (final card in game.loadout.cardIds.toList()) {
        await game.toggleCard(card);
      }
      expect(game.canStart, isFalse);
      await game.toggleCard('validate');
      await game.setControllers(
        const TherapyControllerSettings(focus: FocusAxis.workspace),
      );
      final reloaded = session(store);
      await reloaded.initialize();
      expect(reloaded.loadout.cardIds, ['validate']);
      expect(reloaded.controllers.focus, FocusAxis.workspace);
    },
  );

  test(
    'storage write failure leaves committed game state untouched and visible',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      store.failWrites = true;
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 0);
      expect(game.notice, contains('save'));
      expect(game.storageFailed, isTrue);
    },
  );

  test(
    'corrupted storage is preserved and reported without overwriting it',
    () async {
      final store = MemoryBrowserStore()..value = '{broken';
      final game = session(store);
      await game.initialize();
      expect(game.storageFailed, isTrue);
      expect(store.value, '{broken');
      await game.setPracticeMode(true);
      await game.submitAction(InteractionPattern.validate);
      expect(store.value, '{broken');
    },
  );

  test(
    'malformed saved history is rejected before rendering without overwriting',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      final wrapper = jsonDecode(store.value!) as Map<String, dynamic>;
      final payload =
          jsonDecode(wrapper['data'] as String) as Map<String, dynamic>;
      payload['completed_sessions'] = [
        {'outcome': 'succeed', 'turns': 1, 'transcript': 'invalid'},
      ];
      final data = jsonEncode(payload);
      store.value = jsonEncode({
        'data': data,
        'digest': sha256.convert(utf8.encode(data)).toString(),
      });
      final original = store.value;
      final restored = session(store);
      await restored.initialize();
      expect(restored.storageFailed, isTrue);
      expect(restored.ready, isFalse);
      expect(store.value, original);
    },
  );

  test('stale tab cannot overwrite another tab progress', () async {
    final store = MemoryBrowserStore();
    final first = session(store);
    final second = session(store);
    await first.initialize();
    await second.initialize();
    await first.setPracticeMode(true);
    await first.submitAction(InteractionPattern.validate);
    final latest = store.value;
    await second.setPracticeMode(true);
    expect(store.value, latest);
    expect(second.storageFailed, isTrue);
    expect(second.notice, contains('another tab'));
    await second.retrySave();
    expect(store.value, latest);
    await second.loadLatestSave();
    expect(second.state.turn, 1);
    expect(second.saveConflict, isFalse);
    expect(second.storageFailed, isFalse);
  });

  for (final cap in [0, -1, 99]) {
    test('restored loadout rejects inconsistent slot cap $cap', () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      final envelope = jsonDecode(store.value!) as Map<String, dynamic>;
      final data =
          jsonDecode(envelope['data'] as String) as Map<String, dynamic>;
      (data['loadout'] as Map)['slot_cap'] = cap;
      final encoded = jsonEncode(data);
      store.value = jsonEncode({
        'data': encoded,
        'digest': sha256.convert(utf8.encode(encoded)).toString(),
      });
      final original = store.value;
      final restored = session(store);
      await restored.initialize();
      expect(restored.ready, isFalse);
      expect(restored.storageFailed, isTrue);
      expect(store.value, original);
    });
  }

  test(
    'mechanics failure releases busy without leaking an exception',
    () async {
      final game = session(MemoryBrowserStore());
      await game.initialize();
      await game.setPracticeMode(true);
      game.loadout = const Loadout(cardIds: ['validate'], slotCap: 0);
      await expectLater(
        game.submitAction(InteractionPattern.validate),
        completes,
      );
      expect(game.busy, isFalse);
      expect(game.state.turn, 0);
      expect(game.notice, isNotEmpty);
    },
  );

  test(
    'terminal snapshot without matching completed history is rejected',
    () async {
      final store = MemoryBrowserStore();
      final game = session(store);
      await game.initialize();
      await game.setPracticeMode(true);
      for (var i = 0; i < 100 && !game.completed; i++) {
        await game.submitAction(InteractionPattern.validate);
      }
      expect(game.completed, isTrue);
      final envelope = jsonDecode(store.value!) as Map<String, dynamic>;
      final data =
          jsonDecode(envelope['data'] as String) as Map<String, dynamic>;
      data['completed_sessions'] = [];
      final encoded = jsonEncode(data);
      store.value = jsonEncode({
        'data': encoded,
        'digest': sha256.convert(utf8.encode(encoded)).toString(),
      });
      final original = store.value;
      final restored = session(store);
      await restored.initialize();
      expect(restored.ready, isFalse);
      expect(restored.storageFailed, isTrue);
      expect(store.value, original);
    },
  );

  test('save includes no credential fields', () async {
    final store = MemoryBrowserStore();
    final game = session(store);
    await game.initialize();
    await game.setPracticeMode(true);
    await game.submitAction(InteractionPattern.validate);
    final encoded = jsonEncode(jsonDecode(store.value!));
    expect(encoded, isNot(contains('api_key')));
    expect(encoded, isNot(contains('authorization')));
    expect(encoded, isNot(contains('Bearer')));
  });

  test('completion rewards and history survive reload exactly once', () async {
    final store = MemoryBrowserStore();
    final game = session(store);
    await game.initialize();
    await game.setPracticeMode(true);
    for (var i = 0; i < 12; i++) {
      await game.submitAction(
        i < 6 ? InteractionPattern.validate : InteractionPattern.openQuestion,
      );
    }
    expect(game.completed, isTrue);
    expect(game.state.turn, 12);
    expect(game.lastOutput!.outcome, SessionOutcome.succeed);
    expect(game.balance('xp'), 100);
    expect(game.balance('study'), 3);
    expect(game.balance('cash'), 50);
    expect(game.transcript.last.text, contains('stop here for today'));
    expect(game.completedSessions, hasLength(1));
    final xp = game.balance('xp');
    final reloaded = session(store);
    await reloaded.initialize();
    expect(reloaded.completedSessions, hasLength(1));
    expect(reloaded.balance('xp'), xp);
    await reloaded.submitAction(InteractionPattern.validate);
    expect(reloaded.balance('xp'), xp);
    await reloaded.startNextSession();
    expect(reloaded.state.turn, 0);
    expect(reloaded.completedSessions.single['transcript'], isNotEmpty);
  });
}
