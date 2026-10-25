import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart' show InteractionPattern;
import 'package:psychosims/browser/browser_app.dart';
import 'package:psychosims/browser/browser_session.dart';
import 'package:psychosims/browser/browser_store.dart';
import 'package:psychosims/shared/l10n.dart';
import 'package:psychosims/shared/openrouter_client.dart';

import 'test_manifest_data.dart';

class _RejectingRouter extends OpenRouterClient {
  _RejectingRouter() : super(isOnline: () => true);
  static const message =
      'The selected provider is unavailable. Retry explicitly.';
  @override
  bool get hasApiKey => true;
  @override
  List<OpenRouterModel> get models => const [
    OpenRouterModel(id: 'test/free', name: 'Test', contextLength: 32000),
  ];
  @override
  Stream<OpenRouterUpdate> complete({
    required String modelId,
    required List<OpenRouterMessage> messages,
    required OpenRouterCancellation cancel,
    int? outputTokens,
  }) async* {
    yield const OpenRouterUpdate(
      text: '',
      failure: OpenRouterFailure('provider', message),
    );
  }
}

void main() {
  testWidgets('bounded goals and preserved legacy rules are explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = BrowserSession(
      store: MemoryBrowserStore(),
      isOnline: () => false,
      manifestLoader: () async => testManifest(),
    );
    await game.initialize();
    await tester.pumpWidget(
      PsychosimsApp(session: game, initialPath: '/session'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Turn 0 / 16'), findsOneWidget);
    expect(find.text(L10n.browserSessionGoal), findsOneWidget);
    game.sessionRulesetVersion = '0.1.0';
    await game.setPracticeMode(true);
    await tester.pumpAndSettle();
    expect(find.text(L10n.browserLegacySession), findsOneWidget);
    expect(find.text('Turn 0 · original rules'), findsOneWidget);
    expect(find.text(L10n.browserSessionGoal), findsNothing);
    await game.submitAction(InteractionPattern.validate);
    await tester.pumpAndSettle();
    expect(find.text(L10n.browserLegacySession), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
  testWidgets(
    'failed AI request keeps its reason and retry visible on a short phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 585);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => true,
        manifestLoader: () async => testManifest(),
        client: _RejectingRouter(),
      );
      await game.initialize();
      game.selectModel('test/free');
      await tester.pumpWidget(
        PsychosimsApp(session: game, initialPath: '/session'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Open question'));
      await tester.pumpAndSettle();
      expect(game.state.turn, 0);
      expect(game.transcript, isEmpty);
      expect(find.text(_RejectingRouter.message).hitTestable(), findsOneWidget);
      expect(find.text('Retry Open question').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  for (final size in [const Size(360, 585), const Size(1440, 845)]) {
    testWidgets(
      'conversation choices stay reachable after each turn at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = BrowserSession(
          store: MemoryBrowserStore(),
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await game.initialize();
        await game.setPracticeMode(true);
        await tester.pumpWidget(
          PsychosimsApp(session: game, initialPath: '/session'),
        );
        await tester.pumpAndSettle();
        for (var turn = 0; turn < 6; turn++) {
          final action = find.widgetWithText(OutlinedButton, 'Validate');
          expect(action, findsOneWidget);
          final bounds = tester.getRect(action);
          expect(
            bounds.top,
            greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
          );
          expect(
            bounds.bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
          );
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(game.state.turn, turn + 1);
          final reply = find.text(game.transcript.last.text).last;
          expect(
            reply.hitTestable(),
            findsOneWidget,
            reason: 'latest reply must be visible without scrolling',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      },
    );
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(800, 600), const Size(360, 900)]) {
    testWidgets('Home New game is visible without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      await tester.pumpWidget(PsychosimsApp(session: game));
      await tester.pumpAndSettle();
      final button = find.ancestor(
        of: find.text('New game'),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      expect(button, findsOneWidget);
      final bounds = tester.getRect(button);
      final bodyTop = tester.getRect(find.byType(AppBar)).bottom;
      final bodyBottom = tester.getRect(find.byType(NavigationBar)).top;
      final detail = 'New game $bounds; body y=$bodyTop..$bodyBottom at $size';
      expect(bounds.left, greaterThanOrEqualTo(0), reason: detail);
      expect(bounds.right, lessThanOrEqualTo(size.width), reason: detail);
      expect(bounds.top, greaterThanOrEqualTo(bodyTop), reason: detail);
      expect(bounds.bottom, lessThanOrEqualTo(bodyBottom), reason: detail);
      expect(button.hitTestable(), findsOneWidget, reason: detail);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });
  }

  for (final highContrast in [false, true]) {
    testWidgets('app title is readable (high contrast $highContrast)', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(highContrast: highContrast);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      await tester.pumpWidget(PsychosimsApp(session: game));
      await tester.pumpAndSettle();
      final target = find.text(L10n.appTitle);
      expect(target, findsOneWidget);
      final text = tester.widget<Text>(target);
      final style = DefaultTextStyle.of(
        tester.element(target),
      ).style.merge(text.style);
      final foreground = style.foreground?.color ?? style.color;
      expect(foreground, isNotNull);
      final material = tester.widget<Material>(
        find.ancestor(of: target, matching: find.byType(Material)).first,
      );
      final background = material.color;
      expect(background, isNotNull);
      final inkLuminance = Color.alphaBlend(
        foreground!,
        background!,
      ).computeLuminance();
      final backgroundLuminance = background.computeLuminance();
      final lighter = inkLuminance > backgroundLuminance
          ? inkLuminance
          : backgroundLuminance;
      final darker = inkLuminance < backgroundLuminance
          ? inkLuminance
          : backgroundLuminance;
      expect(
        (lighter + 0.05) / (darker + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground on $background (high contrast $highContrast)',
      );
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    });

    for (final label in [
      L10n.browserSaveFailure,
      L10n.browserRetrySaving,
      'focus outline',
    ]) {
      testWidgets(
        'storage notice $label has readable contrast (high contrast $highContrast)',
        (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(highContrast: highContrast);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final game = BrowserSession(
            store: MemoryBrowserStore(),
            isOnline: () => false,
            manifestLoader: () async => testManifest(),
          );
          await game.initialize();
          game.storageFailed = true;
          game.notice = L10n.browserSaveFailure;
          await tester.pumpWidget(
            PsychosimsApp(session: game, initialPath: '/settings'),
          );
          await tester.pumpAndSettle();
          final checkingFocus = label == 'focus outline';
          final target = find.text(
            checkingFocus ? L10n.browserRetrySaving : label,
          );
          expect(target, findsOneWidget);
          if (checkingFocus) {
            Focus.of(tester.element(target)).requestFocus();
            await tester.pumpAndSettle();
            expect(Focus.of(tester.element(target)).hasFocus, isTrue);
          }
          final text = tester.widget<Text>(target);
          final style = DefaultTextStyle.of(
            tester.element(target),
          ).style.merge(text.style);
          Color? foreground = style.foreground?.color ?? style.color;
          if (checkingFocus) {
            final material = tester.widget<Material>(
              find.ancestor(of: target, matching: find.byType(Material)).first,
            );
            expect(material.shape, isA<OutlinedBorder>());
            final side = (material.shape! as OutlinedBorder).side;
            expect(side.style, BorderStyle.solid);
            expect(side.width, greaterThan(0));
            foreground = side.color;
          }
          expect(foreground, isNotNull);
          final notice = tester.widget<Card>(
            find.ancestor(of: target, matching: find.byType(Card)).first,
          );
          final background = notice.color;
          expect(background, isNotNull);
          final ink = Color.alphaBlend(foreground!, background!);
          final inkLuminance = ink.computeLuminance();
          final backgroundLuminance = background.computeLuminance();
          final lighter = inkLuminance > backgroundLuminance
              ? inkLuminance
              : backgroundLuminance;
          final darker = inkLuminance < backgroundLuminance
              ? inkLuminance
              : backgroundLuminance;
          final contrast = (lighter + 0.05) / (darker + 0.05);
          expect(
            contrast,
            greaterThanOrEqualTo(checkingFocus ? 3 : 4.5),
            reason:
                '$label: $foreground on $background (high contrast $highContrast)',
          );
          await tester.pumpWidget(const SizedBox());
          game.dispose();
        },
      );
    }
  }

  testWidgets('new game entry on Home prepares a fresh session', (
    tester,
  ) async {
    final game = BrowserSession(
      store: MemoryBrowserStore(),
      isOnline: () => false,
      manifestLoader: () async => testManifest(),
    );
    await game.initialize();
    await tester.pumpWidget(PsychosimsApp(session: game));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
    await reveal(tester, find.text('New game'));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare Session'), findsOneWidget);
    expect(find.text('Start a new game?'), findsNothing);
    expect(game.state.turn, 0);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });

  for (final path in ['/', '/session']) {
    testWidgets(
      'new game at $path confirms replacement and retains completed career',
      (tester) async {
        final store = MemoryBrowserStore();
        final game = BrowserSession(
          store: store,
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await game.initialize();
        await game.setPracticeMode(true);
        for (var turn = 0; turn < 100 && !game.completed; turn++) {
          await game.submitAction(InteractionPattern.validate);
        }
        expect(game.completed, isTrue);
        final completed = jsonDecode(jsonEncode(game.completedSessions));
        final balances = {
          for (final currency in ['xp', 'study', 'cash'])
            currency: game.balance(currency),
        };
        await game.startNextSession();
        await game.submitAction(InteractionPattern.validate);
        final activeState = game.state;
        final activeTranscript = game.transcript
            .map((t) => t.toJson())
            .toList();
        final snapshot = store.value;
        await tester.pumpWidget(
          PsychosimsApp(session: game, initialPath: path),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.text('New game'));
        await tester.tap(find.text('New game'));
        await tester.pumpAndSettle();
        expect(find.text('Start a new game?'), findsOneWidget);
        await tester.tap(find.text('Keep playing'));
        await tester.pumpAndSettle();
        expect(game.state, activeState);
        expect(
          game.transcript.map((t) => t.toJson()).toList(),
          activeTranscript,
        );
        expect(store.value, snapshot);
        expect(find.text('Start a new game?'), findsNothing);

        await tester.tap(find.text('New game'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start new game'));
        await tester.pumpAndSettle();
        expect(find.text('Prepare Session'), findsOneWidget);
        expect(game.state.turn, 0);
        expect(game.transcript, isEmpty);
        expect(game.completedSessions, completed);
        for (final entry in balances.entries) {
          expect(game.balance(entry.key), entry.value, reason: entry.key);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        game.dispose();
        final restored = BrowserSession(
          store: store,
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await restored.initialize();
        expect(restored.state.turn, 0);
        expect(restored.transcript, isEmpty);
        expect(restored.completedSessions, completed);
        for (final entry in balances.entries) {
          expect(restored.balance(entry.key), entry.value, reason: entry.key);
        }
        restored.dispose();
      },
    );

    for (final condition in ['busy', 'storage failure']) {
      testWidgets('new game at $path is unavailable during $condition', (
        tester,
      ) async {
        final game = BrowserSession(
          store: MemoryBrowserStore(),
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await game.initialize();
        game.busy = condition == 'busy';
        game.storageFailed = condition == 'storage failure';
        await tester.pumpWidget(
          PsychosimsApp(session: game, initialPath: path),
        );
        await tester.pumpAndSettle();
        final newGame = find.ancestor(
          of: find.text('New game'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(newGame, findsOneWidget);
        expect(tester.widget<ButtonStyleButton>(newGame).onPressed, isNull);
        expect(find.text('Start a new game?'), findsNothing);
        expect(game.state.turn, 0);
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      });
    }
  }

  testWidgets(
    'transcript and partial response bodies remain accessible and selectable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1440, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = BrowserSession(
          store: MemoryBrowserStore(),
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await game.initialize();
        await game.setPracticeMode(true);
        await game.submitAction(InteractionPattern.validate);
        game.partialText = 'I need another moment.';
        game.partialStatus = L10n.browserInterrupted;
        await tester.pumpWidget(
          PsychosimsApp(session: game, initialPath: '/session'),
        );
        await tester.pumpAndSettle();
        for (final turn in game.transcript) {
          final speaker = turn.isPlayer
              ? L10n.browserPlayerAction
              : L10n.browserPatientResponse;
          final node = tester.getSemantics(
            find.bySemanticsLabel(
              RegExp(
                '${RegExp.escape(speaker)}[\\s\\S]*${RegExp.escape(turn.text)}',
              ),
            ),
          );
          expect(node.getSemanticsData().flagsCollection.isTextField, isFalse);
        }
        final partial = tester.getSemantics(
          find.bySemanticsLabel(RegExp(RegExp.escape(game.partialText))),
        );
        expect(partial.getSemanticsData().flagsCollection.isTextField, isFalse);
        // Selection remains available even though read-only text is no longer
        // exposed to assistive technology as an empty, disabled text field.
        expect(find.byType(SelectionArea), findsNWidgets(3));
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('AI key field has an isolated localized accessible label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      await tester.pumpWidget(
        PsychosimsApp(session: game, initialPath: '/settings'),
      );
      await tester.pumpAndSettle();
      List<SemanticsData> data() {
        final nodes = <SemanticsData>[];
        void visit(SemanticsNode node) {
          nodes.add(node.getSemanticsData());
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester
              .binding
              .renderViews
              .single
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return nodes;
      }

      final nodes = data();
      final keyField = nodes.singleWhere(
        (node) => node.flagsCollection.isTextField,
      );
      expect(keyField.label, L10n.browserKeyLabel);
      expect(nodes.any((node) => node.label == L10n.browserKeyAbsent), isTrue);
      expect(nodes.any((node) => node.label == L10n.browserAiPrivacy), isTrue);
      expect(
        nodes.any((node) => node.label == L10n.browserPatientModel),
        isTrue,
      );
      expect(
        nodes.any(
          (node) =>
              node.label == L10n.browserAiSettings &&
              node.flagsCollection.isHeader,
        ),
        isTrue,
      );
      game.setApiKey('fixture-key-only');
      await tester.pumpAndSettle();
      final updated = data();
      expect(
        updated.singleWhere((node) => node.flagsCollection.isTextField).label,
        L10n.browserKeyLabel,
      );
      expect(
        updated.any((node) => node.label == L10n.browserKeyPresent),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    } finally {
      semantics.dispose();
    }
  });

  for (final width in [360.0, 480.0, 600.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'all routes fit ${width.toInt()}px and resize without losing transcript',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final game = BrowserSession(
          store: MemoryBrowserStore(),
          isOnline: () => false,
          manifestLoader: () async => testManifest(),
        );
        await game.initialize();
        await game.setPracticeMode(true);
        for (final path in [
          '/',
          '/loadout',
          '/session',
          '/history',
          '/settings',
        ]) {
          await tester.pumpWidget(
            PsychosimsApp(
              key: ValueKey(path),
              session: game,
              initialPath: path,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$path at $width');
        }
        await game.submitAction(InteractionPattern.validate);
        await tester.pumpWidget(
          PsychosimsApp(
            key: const ValueKey('resizing'),
            session: game,
            initialPath: '/session',
          ),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.text(game.transcript.last.text));
        expect(find.text(game.transcript.last.text), findsOneWidget);
        tester.view.physicalSize = const Size(510, 900);
        await tester.pumpAndSettle();
        await reveal(tester, find.text(game.transcript.last.text));
        expect(find.text(game.transcript.last.text), findsOneWidget);
        expect(game.state.turn, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        game.dispose();
      },
    );
  }
  testWidgets(
    '360px supports 200 percent text, high contrast and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            disableAnimations: true,
            highContrast: true,
          );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      for (final path in [
        '/',
        '/loadout',
        '/session',
        '/history',
        '/settings',
      ]) {
        await tester.pumpWidget(
          PsychosimsApp(key: ValueKey(path), session: game, initialPath: path),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets(
    'production root and session deep link load actual bundled case',
    (tester) async {
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
      );
      await game.initialize();
      expect(game.ready, isTrue);
      await tester.pumpWidget(
        PsychosimsApp(session: game, initialPath: '/session'),
      );
      await tester.pumpAndSettle();
      expect(find.text('The Restless Hour'), findsOneWidget);
      await reveal(tester, find.text('Choose an approach'));
      expect(find.text('Choose an approach'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );
  testWidgets(
    'navigation reports paths to Flutter and accepts browser history updates',
    (tester) async {
      Future<void> pushBrowserPath(String path) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/navigation',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('pushRouteInformation', {'location': path}),
          ),
          (_) {},
        );
      }

      final reports = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add((call.arguments as Map)['uri'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          null,
        ),
      );
      final game = BrowserSession(
        store: MemoryBrowserStore(),
        isOnline: () => false,
        manifestLoader: () async => testManifest(),
      );
      await game.initialize();
      await tester.pumpWidget(PsychosimsApp(session: game));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('New game'));
      await tester.tap(find.text('New game'));
      await tester.pumpAndSettle();
      expect(reports.last, '/loadout');
      await pushBrowserPath('/settings');
      await tester.pumpAndSettle();
      expect(find.text('AI settings'), findsOneWidget);
      await pushBrowserPath('/loadout');
      await tester.pumpAndSettle();
      expect(find.text('Prepare Session'), findsOneWidget);
      await pushBrowserPath('/session');
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Choose an approach'));
      expect(find.text('Choose an approach'), findsOneWidget);
      await pushBrowserPath('/history');
      await tester.pumpAndSettle();
      expect(find.text('Session history'), findsOneWidget);
      await pushBrowserPath('/');
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Local practice career'));
      expect(find.text('Local practice career'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      game.dispose();
    },
  );

  testWidgets('keyboard and touch navigation preserve local session', (
    tester,
  ) async {
    final game = BrowserSession(
      store: MemoryBrowserStore(),
      isOnline: () => false,
      manifestLoader: () async => testManifest(),
    );
    await game.initialize();
    await game.setPracticeMode(true);
    await tester.pumpWidget(PsychosimsApp(session: game));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await reveal(tester, find.text('New game'));
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Start Session'));
    await tester.tap(find.widgetWithText(FilledButton, 'Start Session'));
    await tester.pumpAndSettle();
    await reveal(tester, find.widgetWithText(OutlinedButton, 'Validate'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Validate'));
    await tester.pumpAndSettle();
    expect(game.state.turn, 1);
    expect(find.text(game.transcript.last.text), findsOneWidget);
    expect(game.transcript.last.isPlayer, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
}
