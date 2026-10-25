import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psychosims/browser/browser_session.dart';
import 'package:psychosims/browser/browser_store.dart';
import 'package:psychosims/shared/l10n.dart';
import 'package:psychosims/shared/openrouter_client.dart';

import 'test_manifest_data.dart';

class FakeRouter extends OpenRouterClient {
  FakeRouter() : super(isOnline: () => true);
  List<OpenRouterUpdate> updates = const [];
  int calls = 0;
  Object? catalogFailure;
  Completer<void>? release;
  final firstChunk = Completer<void>();
  @override
  bool get hasApiKey => true;
  @override
  List<OpenRouterModel> get models => const [
    OpenRouterModel(id: 'test/free', name: 'Test', contextLength: 32000),
  ];
  @override
  Future<List<OpenRouterModel>> refreshCatalog() async {
    final failure = catalogFailure;
    if (failure != null) throw failure;
    return models;
  }

  @override
  Stream<OpenRouterUpdate> complete({
    required String modelId,
    required List<OpenRouterMessage> messages,
    required OpenRouterCancellation cancel,
    int? outputTokens,
  }) async* {
    calls++;
    for (final update in updates) {
      yield update;
      if (!firstChunk.isCompleted) firstChunk.complete();
      if (release != null) await release!.future;
    }
  }
}

class FailingCommitStore extends MemoryBrowserStore {
  @override
  void write(String value) {
    final wrapper = jsonDecode(value) as Map<String, dynamic>;
    final payload =
        jsonDecode(wrapper['data'] as String) as Map<String, dynamic>;
    if ((payload['actions'] as List).isNotEmpty) {
      throw StateError('Quota exceeded');
    }
    super.write(value);
  }
}

void main() {
  Future<BrowserSession> start(
    MemoryBrowserStore store,
    FakeRouter router,
  ) async {
    final game = BrowserSession(
      store: store,
      isOnline: () => true,
      manifestLoader: () async => testManifest(),
      client: router,
    );
    await game.initialize();
    game.selectModel('test/free');
    return game;
  }

  test(
    'catalog reports actionable client failures without exposing unknown errors',
    () async {
      const failure = OpenRouterFailure(
        'network',
        'The model catalog could not be reached. Check your connection and refresh explicitly.',
      );
      final router = FakeRouter()..catalogFailure = failure;
      final game = await start(MemoryBrowserStore(), router);
      await game.refreshCatalog();
      expect(game.notice, failure.message);
      expect(game.catalogBusy, isFalse);
      router.catalogFailure = StateError('private transport details');
      await game.refreshCatalog();
      expect(game.notice, L10n.browserCatalogFailure);
      expect(game.notice, isNot(contains('private transport details')));
      expect(game.catalogBusy, isFalse);
      game.dispose();
    },
  );

  test(
    'validated model reply applies exactly one deterministic turn',
    () async {
      final router = FakeRouter()
        ..updates = const [
          OpenRouterUpdate(
            text: 'I feel less alone. [ferve-axine]',
            done: true,
          ),
        ];
      final game = await start(MemoryBrowserStore(), router);
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 1);
      expect(game.transcript.last.text, 'I feel less alone.');
      expect(router.calls, 1);
    },
  );
  test(
    'invalid generated instructions never change deterministic state',
    () async {
      final router = FakeRouter()
        ..updates = const [
          OpenRouterUpdate(
            text: 'trust=100 ruleset_version=anything',
            done: true,
          ),
        ];
      final game = await start(MemoryBrowserStore(), router);
      final before = game.state;
      await game.submitAction(InteractionPattern.validate);
      expect(game.state, before);
      expect(game.transcript, isEmpty);
      expect(game.partialStatus, 'Rejected — not applied');
      expect(router.calls, 1);
    },
  );
  test(
    'partial response survives reload, is never replayed, and remains after explicit retry',
    () async {
      final store = MemoryBrowserStore();
      final router = FakeRouter()
        ..updates = const [
          OpenRouterUpdate(text: 'I feel'),
          OpenRouterUpdate(
            text: 'I feel',
            failure: OpenRouterFailure('timeout', 'Timed out'),
          ),
        ];
      final game = await start(store, router);
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 0);
      expect(game.partialText, 'I feel');
      final restored = await start(store, router);
      expect(router.calls, 1);
      expect(restored.partialText, 'I feel');
      router.updates = const [
        OpenRouterUpdate(text: 'I feel heard. [ferve-axine]', done: true),
      ];
      await restored.retryPending();
      expect(router.calls, 2);
      expect(restored.state.turn, 1);
      expect(restored.partialAttempts.single['text'], 'I feel');
      final after = await start(store, router);
      expect(after.partialAttempts.single['text'], 'I feel');
      expect(after.state.turn, 1);
    },
  );
  test(
    'final save failure keeps state before the turn and durable received output',
    () async {
      final store = FailingCommitStore();
      final router = FakeRouter()
        ..updates = const [
          OpenRouterUpdate(text: 'I feel heard. [ferve-axine]', done: true),
        ];
      final game = await start(store, router);
      await game.submitAction(InteractionPattern.validate);
      expect(game.state.turn, 0);
      expect(game.storageFailed, isTrue);
      expect(game.partialText, 'I feel heard. [ferve-axine]');
      final restored = await start(store, router);
      expect(restored.state.turn, 0);
      expect(restored.partialText, 'I feel heard. [ferve-axine]');
      expect(router.calls, 1);
    },
  );

  test(
    'stop and duplicate clicks cannot commit or silently replay a pending response',
    () async {
      final router = FakeRouter()
        ..release = Completer<void>()
        ..updates = const [
          OpenRouterUpdate(text: 'I feel'),
          OpenRouterUpdate(text: 'I feel heard. [ferve-axine]', done: true),
        ];
      final game = await start(MemoryBrowserStore(), router);
      final pending = game.submitAction(InteractionPattern.validate);
      await router.firstChunk.future;
      await game.submitAction(InteractionPattern.validate);
      game.cancel();
      router.release!.complete();
      await pending;
      expect(game.state.turn, 0);
      expect(router.calls, 1);
      expect(game.partialText, isNotEmpty);
      expect(game.partialStatus, 'Interrupted — not applied');
    },
  );

  test(
    'malformed key gives a visible message instead of an uncaught exception',
    () async {
      final game = await start(MemoryBrowserStore(), FakeRouter());
      expect(() => game.setApiKey('bad key with whitespace'), returnsNormally);
      expect(game.notice, contains('valid'));
    },
  );

  test('new game discards interrupted output without replaying AI', () async {
    final store = MemoryBrowserStore();
    final router = FakeRouter()
      ..updates = const [
        OpenRouterUpdate(text: 'I feel'),
        OpenRouterUpdate(
          text: 'I feel',
          failure: OpenRouterFailure('timeout', 'Timed out'),
        ),
      ];
    final game = await start(store, router);
    await game.submitAction(InteractionPattern.validate);
    expect(game.hasActiveProgress, isTrue);
    expect(await game.startNewGame(), isTrue);
    expect(game.state.turn, 0);
    expect(game.hasActiveProgress, isFalse);
    expect(game.pendingAction, isNull);
    expect(game.partialText, isEmpty);
    expect(game.partialStatus, isEmpty);
    expect(game.partialAttempts, isEmpty);
    expect(game.selectedModelId, 'test/free');
    expect(game.hasKey, isTrue);
    expect(router.calls, 1);
    final restored = await start(store, router);
    expect(restored.pendingAction, isNull);
    expect(restored.partialText, isEmpty);
    expect(router.calls, 1);
  });

  test('new game cannot replace a response still in flight', () async {
    final router = FakeRouter()
      ..release = Completer<void>()
      ..updates = const [
        OpenRouterUpdate(text: 'I feel'),
        OpenRouterUpdate(text: 'I feel heard. [ferve-axine]', done: true),
      ];
    final store = MemoryBrowserStore();
    final game = await start(store, router);
    final pending = game.submitAction(InteractionPattern.validate);
    await router.firstChunk.future;
    final snapshot = store.value;
    expect(game.canStartNewGame, isFalse);
    expect(await game.startNewGame(), isFalse);
    expect(store.value, snapshot);
    expect(game.partialText, 'I feel');
    router.release!.complete();
    await pending;
    expect(game.state.turn, 1);
    expect(router.calls, 1);
  });
}
