import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:psychemas/psychemas.dart' hide Card;
import 'package:psycore/psycore.dart' as core;

import '../shared/l10n.dart';
import 'browser_platform.dart';
import 'browser_session.dart';
import 'browser_router.dart';
import 'browser_theme.dart';

class PsychosimsApp extends StatefulWidget {
  const PsychosimsApp({super.key, this.session, this.initialPath});
  final BrowserSession? session;
  final String? initialPath;
  @override
  State<PsychosimsApp> createState() => _PsychosimsAppState();
}

class _PsychosimsAppState extends State<PsychosimsApp> {
  late final BrowserSession game;
  late final BrowserRouterDelegate _router;
  late final PlatformRouteInformationProvider _routeInformation;
  String get path => _router.path;
  StreamSubscription<bool>? _online;
  final _conversationScroll = ScrollController(keepScrollOffset: false);

  @override
  void initState() {
    super.initState();
    game =
        widget.session ??
        BrowserSession(store: createBrowserStore(), isOnline: browserOnline);
    _router = BrowserRouterDelegate(pageBuilder: _buildShell);
    _routeInformation = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(
        uri: Uri.parse(
          widget.initialPath ??
              WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        ),
      ),
    );
    _online = onlineChanges().listen((_) => game.connectivityChanged());
    if (!game.ready) unawaited(game.initialize());
  }

  void navigate(String value) => _router.navigate(value);

  @override
  void dispose() {
    _online?.cancel();
    _conversationScroll.dispose();
    _routeInformation.dispose();
    _router.dispose();
    if (widget.session == null) game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: L10n.appTitle,
    routeInformationProvider: _routeInformation,
    routeInformationParser: const BrowserRouteParser(),
    routerDelegate: _router,
    debugShowCheckedModeBanner: false,
    highContrastTheme: Noir.theme(highContrast: true),
    theme: Noir.theme(),
    themeAnimationDuration: Duration.zero,
  );

  Future<void> _newGame(BuildContext context) async {
    if (!game.canStartNewGame) return;
    if (game.hasActiveProgress) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(L10n.browserNewGameQuestion),
          content: const Text(L10n.browserNewGameExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(L10n.browserKeepPlaying),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(L10n.browserConfirmNewGame),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (await game.startNewGame() && mounted) navigate('/loadout');
  }

  Widget _buildShell(BuildContext context) => AnimatedBuilder(
    animation: game,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          leading: const ExcludeSemantics(
            child: Icon(
              Icons.psychology_alt_outlined,
              color: Noir.gold,
              size: 30,
            ),
          ),
          title: const Text(L10n.appTitle, overflow: TextOverflow.ellipsis),
          actions: [
            Tooltip(
              message: game.isOnline()
                  ? L10n.browserOnline
                  : L10n.browserOffline,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(game.isOnline() ? Icons.wifi : Icons.wifi_off),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: !game.ready && !game.storageFailed
                  ? Center(
                      child: MediaQuery.disableAnimationsOf(context)
                          ? const Text(L10n.browserLoadingCase)
                          : const CircularProgressIndicator(),
                    )
                  : ListView(
                      key: ValueKey(path),
                      controller: _conversationScroll,
                      padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
                      ),
                      children: [
                        if (game.notice.isNotEmpty &&
                            (path != '/session' || !game.ready) &&
                            (path != '/' || game.storageFailed))
                          _Notice(game: game),
                        if (!game.ready)
                          _StorageRecovery(game: game)
                        else
                          ...switch (path) {
                            '/loadout' => _loadout(context),
                            '/session' => _session(context),
                            '/history' => _history(context),
                            '/settings' => [
                              const NoirEyebrow(L10n.noirSettingsLabel),
                              const SizedBox(height: 12),
                              AiSettings(game: game),
                              const SizedBox(height: 24),
                              _StorageRecovery(game: game),
                            ],
                            _ => _home(context),
                          },
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (path == '/session' && game.ready && !game.completed)
              _actionDock(context),
            NavigationBar(
              selectedIndex: switch (path) {
                '/loadout' || '/session' => 1,
                '/history' => 2,
                '/settings' => 3,
                _ => 0,
              },
              onDestinationSelected: (i) => navigate(
                [
                  '/',
                  game.ready && game.state.turn > 0 ? '/session' : '/loadout',
                  '/history',
                  '/settings',
                ][i],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: L10n.browserHome,
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: L10n.browserSession,
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: L10n.browserHistory,
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune),
                  label: L10n.browserSettings,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  List<Widget> _home(BuildContext context) => [
    LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final content = Padding(
          padding: EdgeInsets.all(compact ? 24 : 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NoirEyebrow(L10n.noirEyebrow),
                const SizedBox(height: 16),
                Text(
                  L10n.noirHeadline,
                  style: compact
                      ? Theme.of(context).textTheme.headlineLarge
                      : constraints.maxWidth < 1000
                      ? Theme.of(context).textTheme.displayMedium
                      : Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 20),
                const Text(
                  L10n.noirIntro,
                  style: TextStyle(
                    color: Noir.paper,
                    fontSize: 17,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: game.canStartNewGame
                          ? () => _newGame(context)
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(L10n.browserNewGame),
                    ),
                    if (game.state.turn > 0)
                      OutlinedButton.icon(
                        onPressed: () => navigate('/session'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(L10n.browserResume),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  L10n.noirOfflinePractice,
                  style: TextStyle(color: Noir.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: Noir.line),
            color: Noir.panel,
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      Noir.scene,
                      height: MediaQuery.sizeOf(context).height < 700
                          ? 100
                          : 170,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                    content,
                  ],
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        Noir.scene,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Noir.ink.withValues(alpha: 0.97),
                              Noir.ink.withValues(alpha: 0.9),
                              Noir.ink.withValues(alpha: 0.12),
                            ],
                            stops: const [0, 0.35, 1],
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 430),
                      child: content,
                    ),
                  ],
                ),
        );
      },
    ),
    if (game.notice.isNotEmpty && !game.storageFailed)
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _Notice(game: game),
      ),
    const SizedBox(height: 32),
    _patientStudy(context),
    const SizedBox(height: 28),
    const Divider(),
    const SizedBox(height: 14),
    const NoirEyebrow(L10n.noirCareerRecord),
    const SizedBox(height: 8),
    Text(L10n.careerTitle, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        Text(L10n.careerSessions(game.completedSessions.length)),
        Text(
          L10n.careerBalances(
            xp: game.balance('xp'),
            study: game.balance('study'),
            cash: game.balance('cash'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 18),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => navigate('/settings'),
        icon: const Icon(Icons.graphic_eq),
        label: const Text(L10n.browserAiSettings),
      ),
    ),
    const SizedBox(height: 24),
    const Text(L10n.browserLocalPrivacy, style: TextStyle(color: Noir.muted)),
    const SizedBox(height: 8),
    const Text(
      L10n.browserFictionalNotice,
      style: TextStyle(color: Noir.muted, fontSize: 12),
    ),
  ];

  Widget _patientStudy(BuildContext context, {bool compact = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              (!compact && constraints.maxWidth < 620) ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final notes = Padding(
            padding: EdgeInsets.all(
              compact
                  ? 16
                  : stacked
                  ? 20
                  : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NoirEyebrow(L10n.noirCurrentCase, color: Noir.teal),
                const SizedBox(height: 12),
                Text(
                  game.caseTitle,
                  style: compact
                      ? Theme.of(context).textTheme.headlineSmall
                      : Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  compact
                      ? L10n.noirCaseObservation
                      : game.manifest.modelFacingTemplate,
                ),
                if (!compact) ...[
                  const SizedBox(height: 20),
                  const Text(
                    L10n.noirCaseNote,
                    style: TextStyle(
                      fontFamily: 'NotoSerif',
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      color: Noir.gold,
                    ),
                  ),
                ],
              ],
            ),
          );
          return Container(
            decoration: const BoxDecoration(
              color: Noir.panel,
              border: Border(left: BorderSide(color: Noir.rust, width: 3)),
            ),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PatientPortrait(height: compact ? 200 : 290),
                      notes,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PatientPortrait(
                        height: compact ? 185 : 290,
                        width: compact
                            ? (constraints.maxWidth < 620 ? 94 : 145)
                            : 205,
                      ),
                      Expanded(child: notes),
                    ],
                  ),
          );
        },
      );

  List<Widget> _loadout(BuildContext context) {
    final locked = game.state.turn > 0 || game.busy;
    final gap = const core.LoadoutAnalyzer().analyze(
      game.manifest,
      game.loadout,
    );
    return [
      const NoirEyebrow(L10n.noirPreparation),
      const SizedBox(height: 10),
      Text(
        L10n.loadoutTitle,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      const Text(L10n.noirPreparationHint),
      const SizedBox(height: 20),
      _patientStudy(context, compact: true),
      const SizedBox(height: 20),
      Text(L10n.loadoutStyle(game.manifest.styleArchetype.name)),
      Text(
        L10n.browserInitialAxes(
          game.state.trustScore,
          game.state.agitationLevel,
          game.state.activeDefense.name,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        L10n.loadoutActiveCards(
          game.loadout.cardIds.length,
          game.loadout.slotCap,
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (locked) const Text(L10n.browserLoadoutLocked),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in game.manifest.interactionPatterns)
            FilterChip(
              label: Text(actionLabel(action)),
              selected: game.loadout.contains(
                cardFromInteractionPattern(action).id,
              ),
              tooltip: L10n.browserEquipTooltip(
                game.loadout.contains(cardFromInteractionPattern(action).id),
                actionLabel(action),
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: locked
                  ? null
                  : (_) =>
                        game.toggleCard(cardFromInteractionPattern(action).id),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        L10n.browserTactics(
          game.manifest.resolvedCards.map((c) => c.signature.name).toSet(),
        ),
      ),
      Text(
        gap.hasGap
            ? L10n.loadoutMissingTactics(
                gap.missingSignatures.map((s) => s.name).toList(),
              )
            : L10n.browserTacticsCovered,
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<FocusAxis>(
        initialValue: game.controllers.focus,
        decoration: const InputDecoration(labelText: L10n.loadoutFocusLabel),
        items: [
          for (final v in FocusAxis.values)
            DropdownMenuItem(value: v, child: Text(L10n.browserFocus(v))),
        ],
        onChanged: locked
            ? null
            : (v) {
                if (v != null) {
                  game.setControllers(
                    TherapyControllerSettings(
                      focus: v,
                      emotionalDelivery: game.controllers.emotionalDelivery,
                    ),
                  );
                }
              },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<EmotionalDelivery>(
        initialValue: game.controllers.emotionalDelivery,
        decoration: const InputDecoration(
          labelText: L10n.loadoutEmotionalDeliveryLabel,
        ),
        items: [
          for (final v in EmotionalDelivery.values)
            DropdownMenuItem(value: v, child: Text(L10n.browserDelivery(v))),
        ],
        onChanged: locked
            ? null
            : (v) {
                if (v != null) {
                  game.setControllers(
                    TherapyControllerSettings(
                      focus: game.controllers.focus,
                      emotionalDelivery: v,
                    ),
                  );
                }
              },
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        title: const Text(L10n.browserApproachGuide),
        children: [
          for (final action in game.manifest.interactionPatterns)
            ListTile(
              title: Text(actionLabel(action)),
              subtitle: Text(L10n.browserActionHelp(action)),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(L10n.browserControllerHelp),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _PracticeSwitch(game: game),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: game.canStart ? () => navigate('/session') : null,
        child: Text(locked ? L10n.browserResume : L10n.loadoutStartSession),
      ),
      if (!game.canStart) const Text(L10n.loadoutInvalid),
    ];
  }

  List<Widget> _session(BuildContext context) => [
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        const NoirEyebrow(L10n.noirSessionRoom),
        OutlinedButton.icon(
          onPressed: game.canStartNewGame ? () => _newGame(context) : null,
          icon: const Icon(Icons.add),
          label: const Text(L10n.browserNewGame),
        ),
      ],
    ),
    const SizedBox(height: 16),
    _patientStudy(context, compact: true),
    const SizedBox(height: 24),
    Text(game.turnLabel, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 16),
    LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.3
            ? 3
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 24) / columns;
        return Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            SizedBox(
              width: width,
              child: NoirMeter(
                label: L10n.browserTrust(game.state.trustScore),
                value: game.state.trustScore,
                color: Noir.teal,
              ),
            ),
            SizedBox(
              width: width,
              child: NoirMeter(
                label: L10n.browserAgitation(game.state.agitationLevel),
                value: game.state.agitationLevel,
                color: Noir.rust,
              ),
            ),
            SizedBox(
              width: width,
              child: NoirMeter(
                label: L10n.browserProgress(game.state.sessionProgress),
                value: game.state.sessionProgress,
                color: Noir.gold,
              ),
            ),
          ],
        );
      },
    ),
    const SizedBox(height: 16),
    Text(
      game.isLegacySession
          ? L10n.browserLegacySession
          : L10n.browserSessionGoal,
      style: const TextStyle(color: Noir.muted),
    ),
    if (game.lastOutput != null) ...[
      const SizedBox(height: 8),
      Text(game.sessionGuidance, style: const TextStyle(color: Noir.gold)),
    ],
    const SizedBox(height: 12),
    _PracticeSwitch(game: game),
    if (!game.practiceMode && !game.canAct && !game.busy)
      TextButton(
        onPressed: () => navigate('/settings'),
        child: const Text(L10n.browserConfigureAi),
      ),
    const SizedBox(height: 16),
    if (game.transcript.isEmpty)
      Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Noir.gold, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.noirEmptySession,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              L10n.browserSelectApproach,
              style: TextStyle(color: Noir.muted),
            ),
          ],
        ),
      ),
    for (final turn in game.transcript) _TurnBubble(turn: turn),
    if (game.partialAttempts.isNotEmpty)
      ExpansionTile(
        title: const Text(L10n.browserIncompleteResponses),
        children: [
          for (final attempt in game.partialAttempts)
            ListTile(
              title: Text(
                L10n.browserAttempt(
                  attempt['action'] as String,
                  attempt['status'] as String,
                ),
              ),
              subtitle: _ReadableText(attempt['text'] as String),
            ),
        ],
      ),
    if (game.partialText.isNotEmpty || game.busy)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.partialStatus,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _ReadableText(
                game.partialText.isEmpty
                    ? L10n.browserWaiting
                    : game.partialText,
              ),
            ],
          ),
        ),
      ),
    if (game.notice.isNotEmpty) _Notice(game: game),
    if (game.completed) ...[
      const SizedBox(height: 24),
      Text(
        game.completedSessions.last['outcome'] == 'succeed'
            ? L10n.sessionSuccess
            : L10n.sessionFailure,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const Text(L10n.browserSessionSaved),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () async {
          await game.startNextSession();
          if (!game.completed) navigate('/loadout');
        },
        child: const Text(L10n.sessionNext),
      ),
    ],
  ];

  void _followLatest([int remainingLayouts = 4]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          path == '/session' &&
          _conversationScroll.hasClients &&
          _conversationScroll.positions.length == 1) {
        final position = _conversationScroll.position;
        if ((position.maxScrollExtent - position.pixels).abs() > 1) {
          _conversationScroll.jumpTo(position.maxScrollExtent);
          // Lazy transcript rows refine the estimated extent as they mount.
          if (remainingLayouts > 0) _followLatest(remainingLayouts - 1);
        }
      }
    });
  }

  Future<void> _act(InteractionPattern action) async {
    final pending = game.submitAction(action);
    _followLatest();
    await pending;
    if (mounted) setState(() => _followLatest());
  }

  Widget _actionDock(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${game.turnLabel} · ${L10n.browserTrust(game.state.trustScore)} · ${L10n.browserAgitation(game.state.agitationLevel)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 0,
                      color: Noir.paper,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    L10n.browserChooseApproach,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  if (game.busy)
                    FilledButton.icon(
                      onPressed: game.cancel,
                      icon: const Icon(Icons.stop),
                      label: const Text(L10n.browserStop),
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 700 &&
                                MediaQuery.textScalerOf(context).scale(1) < 1.4
                            ? 4
                            : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 8) /
                            columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final action in game.availableActions)
                              SizedBox(
                                width: width,
                                child: Tooltip(
                                  message: L10n.browserActionHelp(action),
                                  preferBelow: false,
                                  excludeFromSemantics: true,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      alignment: Alignment.centerLeft,
                                      foregroundColor: _actionColor(action),
                                    ),
                                    onPressed: game.canAct
                                        ? () => _act(action)
                                        : null,
                                    icon: Icon(_actionIcon(action), size: 20),
                                    label: Text(actionLabel(action)),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (game.pendingAction != null)
                      TextButton.icon(
                        onPressed: game.canAct
                            ? () => _act(game.pendingAction!)
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          L10n.browserRetryAction(
                            actionLabel(game.pendingAction!),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _history(BuildContext context) => [
    const NoirEyebrow(L10n.noirFieldNotes),
    const SizedBox(height: 12),
    Text(
      L10n.browserSessionHistory,
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 16),
    const Text(
      L10n.noirHistoryIntro,
      style: TextStyle(
        fontFamily: 'NotoSerif',
        color: Noir.muted,
        fontStyle: FontStyle.italic,
      ),
    ),
    const SizedBox(height: 20),
    if (game.completedSessions.isEmpty) const Text(L10n.browserHistoryEmpty),
    for (var i = game.completedSessions.length - 1; i >= 0; i--)
      ExpansionTile(
        title: Text(
          L10n.browserHistorySession(
            i + 1,
            game.completedSessions[i]['outcome'] as String,
          ),
        ),
        subtitle: Text(
          L10n.browserHistoryTurns(game.completedSessions[i]['turns'] as int),
        ),
        children: [
          for (final t in game.completedSessions[i]['transcript'] as List)
            _TurnBubble(
              turn: BrowserTurn.fromJson((t as Map).cast<String, dynamic>()),
            ),
          for (final attempt
              in (game.completedSessions[i]['partial_attempts'] ?? []) as List)
            ListTile(
              title: Text(
                L10n.browserAttempt(
                  attempt['action'] as String,
                  attempt['status'] as String,
                ),
              ),
              subtitle: _ReadableText(attempt['text'] as String),
            ),
        ],
      ),
  ];
}

class _PracticeSwitch extends StatelessWidget {
  const _PracticeSwitch({required this.game});
  final BrowserSession game;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text(L10n.browserPracticeWithoutAi),
    subtitle: Text(
      game.practiceMode
          ? L10n.browserPracticeDescription
          : L10n.browserAiRequirements,
    ),
    value: game.practiceMode,
    onChanged: game.busy ? null : game.setPracticeMode,
  );
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn});
  final BrowserTurn turn;
  @override
  Widget build(BuildContext context) => Align(
    alignment: turn.isPlayer ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(
        color: turn.isPlayer ? Noir.panel : Noir.paper,
        border: Border(
          left: BorderSide(
            color: turn.isPlayer ? Noir.teal : Noir.rust,
            width: 3,
          ),
        ),
      ),
      child: Semantics(
        container: true,
        label: turn.isPlayer
            ? L10n.browserPlayerAction
            : L10n.browserPatientResponse,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: NoirEyebrow(
                turn.isPlayer
                    ? L10n.noirPlayerSpeaker
                    : L10n.noirPatientSpeaker,
                color: turn.isPlayer ? Noir.teal : Noir.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (turn.practice && !turn.isPlayer)
              const Text(
                L10n.browserLocalDialogue,
                style: TextStyle(color: Color(0xFF4D5148), fontSize: 12),
              ),
            _ReadableText(
              turn.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: turn.isPlayer ? Noir.paper : Noir.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// SelectionArea keeps copy/selection without exposing read-only dialogue as
/// an empty disabled text field in Flutter web's accessibility tree.
class _ReadableText extends StatelessWidget {
  const _ReadableText(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      SelectionArea(child: Text(text, style: style));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.game});
  final BrowserSession game;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = game.storageFailed
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: game.storageFailed
            ? scheme.errorContainer
            : scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.notice, style: TextStyle(color: foreground)),
              if (game.storageFailed && game.ready)
                TextButton(
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(foreground),
                    side: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.focused)
                          ? BorderSide(color: foreground, width: 3)
                          : BorderSide.none,
                    ),
                  ),
                  onPressed: game.busy
                      ? null
                      : (game.saveConflict
                            ? game.loadLatestSave
                            : game.retrySave),
                  child: Text(
                    game.saveConflict
                        ? L10n.browserLoadLatest
                        : L10n.browserRetrySaving,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiSettings extends StatefulWidget {
  const AiSettings({super.key, required this.game});
  final BrowserSession game;
  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  final keyInput = TextEditingController();
  @override
  void dispose() {
    keyInput.clear();
    keyInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              L10n.browserAiSettings,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          const Text(L10n.browserAiPrivacy),
          const SizedBox(height: 12),
          const Text(L10n.browserKeyPrivacy),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            child: TextField(
              controller: keyInput,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              autofillHints: const [],
              decoration: const InputDecoration(
                labelText: L10n.browserKeyLabel,
                hintText: L10n.browserKeyHint,
              ),
              onSubmitted: (_) => _useKey(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: game.busy ? null : _useKey,
                child: const Text(L10n.browserUseKey),
              ),
              OutlinedButton(
                onPressed: game.hasKey ? game.clearApiKey : null,
                child: const Text(L10n.browserForgetKey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              game.hasKey ? L10n.browserKeyPresent : L10n.browserKeyAbsent,
            ),
          ),
          const SizedBox(height: 20),
          const Text(L10n.browserFreeModels),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: !game.isOnline() || game.catalogBusy
                ? null
                : game.refreshCatalog,
            child: Text(
              game.catalogBusy
                  ? L10n.browserLoadingModels
                  : L10n.browserRefreshCatalog,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                '${game.selectedModelId}:${game.client.models.length}',
              ),
              initialValue: game.selectedModelId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: L10n.browserPatientModel,
              ),
              items: [
                for (final model in game.client.models)
                  DropdownMenuItem(
                    value: model.id,
                    child: Text(model.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: game.busy ? null : game.selectModel,
            ),
          ),
          const SizedBox(height: 20),
          _PracticeSwitch(game: game),
        ],
      ),
    );
  }

  void _useKey() {
    final value = keyInput.text.trim();
    if (value.isEmpty) return;
    widget.game.setApiKey(value);
    keyInput.clear();
    FocusScope.of(context).unfocus();
  }
}

class _StorageRecovery extends StatelessWidget {
  const _StorageRecovery({required this.game});
  final BrowserSession game;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        L10n.browserSavedData,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(L10n.browserStorageHelp),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () {
          String data;
          try {
            data = game.exportSave();
          } catch (_) {
            data = L10n.browserStorageUnavailable;
          }
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(L10n.browserExport),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: _ReadableText(
                    data.isEmpty ? L10n.browserNoSavedData : data,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: data));
                  },
                  child: const Text(L10n.browserCopy),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(L10n.browserClose),
                ),
              ],
            ),
          );
        },
        child: const Text(L10n.browserExport),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: game.busy
            ? null
            : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(L10n.browserClearQuestion),
                    content: const Text(L10n.browserClearExplanation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(L10n.browserKeepData),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(L10n.browserClearData),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await game.clearSavedData();
              },
        child: const Text(L10n.browserClearLocalData),
      ),
    ],
  );
}

IconData _actionIcon(InteractionPattern action) => switch (action) {
  InteractionPattern.openQuestion => Icons.forum_outlined,
  InteractionPattern.validate => Icons.hearing_outlined,
  InteractionPattern.reframe => Icons.filter_tilt_shift,
  InteractionPattern.setBoundary => Icons.front_hand_outlined,
  _ => Icons.chat_bubble_outline,
};

Color _actionColor(InteractionPattern action) => switch (action) {
  InteractionPattern.openQuestion => Noir.gold,
  InteractionPattern.validate => Noir.teal,
  InteractionPattern.reframe => Noir.rust,
  _ => Noir.paper,
};
