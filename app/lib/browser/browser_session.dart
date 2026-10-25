import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart' as core;

import '../shared/dialogue_sanitizer.dart';
import '../shared/l10n.dart';
import '../shared/openrouter_client.dart';
import 'browser_store.dart';
import 'practice_dialogue.dart';

class BrowserTurn {
  const BrowserTurn({
    required this.isPlayer,
    required this.text,
    this.practice = false,
  });
  final bool isPlayer;
  final String text;
  final bool practice;
  Map<String, Object?> toJson() => {
    'player': isPlayer,
    'text': text,
    'practice': practice,
  };
  factory BrowserTurn.fromJson(Map<String, dynamic> json) => BrowserTurn(
    isPlayer: json['player'] as bool,
    text: json['text'] as String,
    practice: json['practice'] as bool,
  );
}

/// Browser-owned game lifecycle; the shared deterministic core owns all axes,
/// outcomes, card rules, and career rewards. A model can supply dialogue only.
class BrowserSession extends ChangeNotifier {
  BrowserSession({
    required this.store,
    required this.isOnline,
    Future<PatientManifest> Function()? manifestLoader,
    OpenRouterClient? client,
  }) : _manifestLoader = manifestLoader ?? _loadManifest,
       client =
           client ??
           OpenRouterClient(isOnline: isOnline, maxResponseChars: 65536);

  final BrowserStore store;
  final bool Function() isOnline;
  final Future<PatientManifest> Function() _manifestLoader;
  final OpenRouterClient client;
  final Config config = loadConfig(environment: 'prod');
  late PatientManifest manifest;
  String sessionRulesetVersion = core.RulesetProfile.currentVersion;
  late core.SimState state;
  late core.SimState _initialState;
  late Loadout loadout;
  late CardLibrary library;
  TherapyControllerSettings controllers = const TherapyControllerSettings();
  List<BrowserTurn> transcript = [];
  List<InteractionPattern> _actions = [];
  List<core.TurnOutput> _outputs = [];
  List<Map<String, dynamic>> completedSessions = [];
  List<Map<String, dynamic>> partialAttempts = [];
  Map<String, int> _balances = {};
  CaseHistoryEnvelope _history = CaseHistoryEnvelope.empty;
  bool ready = false;
  bool busy = false;
  bool practiceMode = false;
  bool storageFailed = false;
  bool _corrupt = false;
  bool saveConflict = false;
  String? _observedSnapshot;
  bool _closed = false;
  String notice = '';
  String partialText = '';
  String partialStatus = '';
  InteractionPattern? pendingAction;
  String? selectedModelId;
  OpenRouterCancellation? _cancellation;
  bool catalogBusy = false;

  core.RulesetProfile get sessionRules =>
      core.RulesetProfile.forVersion(sessionRulesetVersion);
  bool get isLegacySession => !sessionRules.hasBoundedSessions;
  String get turnLabel =>
      L10n.browserSessionTurn(state.turn, sessionRules.maxSessionTurns);
  String get sessionGuidance {
    if (completed) return L10n.browserOutcomeHelp(lastOutput!.outcome);
    if (isLegacySession) {
      return L10n.browserOutcomeHelp(
        lastOutput?.outcome ?? SessionOutcome.ongoing,
      );
    }
    if (state.agitationLevel > sessionRules.successAgitationCeiling) {
      return L10n.browserCalmGoal;
    }
    if (state.trustScore < sessionRules.successTrustFloor ||
        !state.hasRapportApproach) {
      return L10n.browserTrustGoal;
    }
    if (!state.hasExplorationApproach) return L10n.browserExploreGoal;
    return L10n.browserGoalsMet;
  }

  bool get completed => _outputs.isNotEmpty && _outputs.last.isTerminal;
  core.TurnOutput? get lastOutput => _outputs.isEmpty ? null : _outputs.last;
  bool get canStart => ready && loadout.cardIds.isNotEmpty && !storageFailed;
  bool get canStartNewGame => ready && !busy && !storageFailed && !_closed;
  bool get hasActiveProgress =>
      ready &&
      !completed &&
      (state.turn > 0 ||
          pendingAction != null ||
          partialText.isNotEmpty ||
          partialAttempts.isNotEmpty);
  bool get canAct =>
      canStart &&
      !busy &&
      !completed &&
      (practiceMode ||
          (isOnline() && client.hasApiKey && selectedModelId != null));
  List<InteractionPattern> get availableActions => manifest.interactionPatterns
      .where((a) => loadout.contains(cardFromInteractionPattern(a).id))
      .toList();
  int balance(String currency) => _balances[currency] ?? 0;
  String get caseTitle => const L10n().manifestName(manifest.nameKey);
  bool get hasKey => client.hasApiKey;

  static Future<PatientManifest> _loadManifest() async {
    final data = await rootBundle.load('../content/manifests/poc_sample.json');
    return const ManifestLoader(
      catalog: L10n(),
    ).load(data.buffer.asUint8List());
  }

  core.TurnResolver get _resolver => core.TurnResolver(
    const core.InjectedClock.replay(0),
    balance: core.CardBalance.fromConfig(config.balance),
  );

  Future<void> initialize() async {
    try {
      manifest = await _manifestLoader();
      _balances = {};
      completedSessions = [];
      _history = CaseHistoryEnvelope.empty;
      controllers = const TherapyControllerSettings();
      practiceMode = false;
      library = CardLibrary(
        ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet(),
      );
      loadout = Loadout(
        cardIds: library.ownedCardIds
            .take(config.balance.activeCardSlots)
            .toList(),
        slotCap: config.balance.activeCardSlots,
      );
      _resetState();
      final saved = store.read();
      _observedSnapshot = saved;
      if (saved != null) _restore(saved);
      ready = true;
      if (!isOnline() && notice.isEmpty) {
        notice = L10n.browserOfflineNotice;
      }
      if (pendingAction != null) {
        partialStatus = L10n.browserInterrupted;
        notice = L10n.browserPreviousInterrupted;
        _persist();
      }
    } catch (_) {
      storageFailed = true;
      _corrupt = true;
      notice = L10n.browserReadFailure;
    }
    _notify();
  }

  void _resetState() {
    sessionRulesetVersion = core.RulesetProfile.currentVersion;
    _initialState = const core.MultiSessionResolver().startingState(
      initialState: manifest.initialState,
      rootSeed: config.inference.seed,
      envelope: manifest.memoryClass == MemoryClass.persistent
          ? _history
          : CaseHistoryEnvelope.empty,
    );
    state = _initialState;
    _actions = [];
    _outputs = [];
    transcript = [];
    partialAttempts = [];
    partialText = '';
    partialStatus = '';
    pendingAction = null;
  }

  core.TurnOutput _resolve(InteractionPattern action, core.SimState from) =>
      _resolver.resolve(
        core.TurnInput(
          rulesetVersion: sessionRulesetVersion,
          manifest: manifest,
          state: from,
          action: action,
          loadout: loadout,
          library: library,
          controllers: controllers,
        ),
      );

  Future<void> setPracticeMode(bool value) async {
    if (busy || _corrupt) return;
    final before = practiceMode;
    practiceMode = value;
    if (!_persist()) practiceMode = before;
    _notify();
  }

  Future<void> toggleCard(String id) async {
    if (!ready || busy || state.turn > 0 || _corrupt || !library.owns(id)) {
      return;
    }
    final before = loadout;
    final cards = List<String>.of(loadout.cardIds);
    if (!cards.remove(id)) {
      if (cards.length >= config.balance.activeCardSlots) return;
      cards.add(id);
    }
    loadout = Loadout(cardIds: cards, slotCap: config.balance.activeCardSlots);
    if (!_persist()) loadout = before;
    _notify();
  }

  Future<void> setControllers(TherapyControllerSettings value) async {
    if (busy || !ready || state.turn > 0 || _corrupt) return;
    final before = controllers;
    controllers = value;
    if (!_persist()) controllers = before;
    _notify();
  }

  void setApiKey(String value) {
    try {
      client.setApiKey(value);
      notice = L10n.browserKeyStored;
    } on OpenRouterFailure catch (error) {
      notice = error.message;
    }
    _notify();
  }

  void clearApiKey() {
    cancel();
    client.clearApiKey();
    selectedModelId = null;
    notice = L10n.browserKeyForgotten;
    _notify();
  }

  Future<void> refreshCatalog() async {
    if (catalogBusy) return;
    catalogBusy = true;
    notice = '';
    _notify();
    try {
      final models = await client.refreshCatalog();
      if (!models.any((m) => m.id == selectedModelId)) selectedModelId = null;
      if (models.isEmpty) {
        notice = L10n.browserNoModels;
      }
    } on OpenRouterFailure catch (error) {
      notice = error.message;
    } catch (_) {
      notice = L10n.browserCatalogFailure;
    } finally {
      catalogBusy = false;
      _notify();
    }
  }

  void selectModel(String? id) {
    if (busy) return;
    selectedModelId = client.models.any((m) => m.id == id) ? id : null;
    _notify();
  }

  void connectivityChanged() {
    final online = isOnline();
    final offlineNotice =
        notice == L10n.browserOfflineNotice ||
        notice == L10n.browserOfflineAction;
    if (!online && busy) _cancellation?.cancel();
    if (online && offlineNotice) {
      notice = '';
    } else if (!online && (notice.isEmpty || offlineNotice)) {
      notice = L10n.browserOfflineNotice;
    }
    _notify();
  }

  Future<void> retryPending() async {
    final action = pendingAction;
    if (action != null) await submitAction(action);
  }

  Future<void> submitAction(InteractionPattern action) async {
    if (!ready ||
        busy ||
        completed ||
        storageFailed ||
        !availableActions.contains(action)) {
      return;
    }
    if (!practiceMode && !isOnline()) {
      notice = L10n.browserOfflineAction;
      _notify();
      return;
    }
    if (!practiceMode && (!client.hasApiKey || selectedModelId == null)) {
      notice = L10n.browserConfigureNotice;
      _notify();
      return;
    }
    busy = true;
    notice = '';
    try {
      final output = _resolve(action, state);
      if (partialText.isNotEmpty && pendingAction != null) {
        partialAttempts.add({
          'text': partialText,
          'status': partialStatus,
          'action': actionLabel(pendingAction!),
        });
      }
      if (practiceMode) {
        final dialogue = practiceDialogue(
          action: action,
          before: state,
          after: output.nextState,
          isTerminal: output.isTerminal,
          recentReplies: transcript.reversed
              .where((turn) => !turn.isPlayer)
              .take(2)
              .map((turn) => turn.text),
        );
        _commit(action, output, dialogue, practice: true);
        return;
      }
      pendingAction = action;
      partialText = '';
      partialStatus = L10n.browserReceiving;
      if (!_persist()) return;
      _notify();
      const assembler = core.PromptAssembler(
        tokenCounter: _ConservativeCounter(),
        chatTemplate: core.PlainChatTemplate(),
        roleplayFrame: core.PatientRoleplayFrame(),
      );
      final turns = transcript
          .where((t) => !t.practice)
          .map(
            (t) => core.ConversationTurn(
              role: t.isPlayer ? 'user' : 'assistant',
              text: t.text,
            ),
          )
          .toList();
      turns.add(core.ConversationTurn(role: 'user', text: actionLabel(action)));
      final prompt = assembler.assemble(
        rulesetVersion: sessionRulesetVersion,
        manifest: manifest,
        state: output.nextState,
        conversationWindow: turns.reversed
            .take(manifest.maxHistoryTurns)
            .toList()
            .reversed
            .toList(),
        historyEnvelope: _history,
        inputBudget: 32000,
        outputReserve: 1024,
      );
      _cancellation = OpenRouterCancellation();
      var complete = false;
      await for (final update in client.complete(
        modelId: selectedModelId!,
        messages: [OpenRouterMessage(role: 'user', content: prompt)],
        cancel: _cancellation!,
      )) {
        if (_closed) return;
        partialText = update.text;
        if (!_persist()) {
          _cancellation?.cancel();
          return;
        }
        _notify();
        if (update.failure != null) {
          partialStatus = L10n.browserInterrupted;
          notice = update.failure!.message;
          break;
        }
        if (update.done) complete = true;
      }
      if (!complete || _cancellation!.isCancelled || !isOnline()) {
        partialStatus = L10n.browserInterrupted;
        if (notice.isEmpty) {
          notice = L10n.browserStopped;
        }
        _persist();
        return;
      }
      const sanitizer = DialogueSanitizer();
      final checks = sanitizer.qualityChecks(
        partialText,
        output.requiredClueTokens,
      );
      final dialogue = sanitizer.sanitize(
        partialText,
        systemFrame: prompt,
        clueTokens: manifest.clueTokens,
      );
      if (!checks.values.every((p) => p) ||
          dialogue.isEmpty ||
          sanitizer.looksLikeRefusal(dialogue)) {
        partialStatus = L10n.browserRejected;
        notice = L10n.browserRejectedNotice;
        _persist();
        return;
      }
      _commit(action, output, dialogue, practice: false);
    } catch (_) {
      partialStatus = L10n.browserInterrupted;
      notice = L10n.browserResponseFailure;
      _persist();
    } finally {
      busy = false;
      _cancellation = null;
      _notify();
    }
  }

  void _commit(
    InteractionPattern action,
    core.TurnOutput output,
    String dialogue, {
    required bool practice,
  }) {
    final before = _payload();
    state = output.nextState;
    _actions.add(action);
    _outputs.add(output);
    transcript.addAll([
      BrowserTurn(
        isPlayer: true,
        text: actionLabel(action),
        practice: practice,
      ),
      BrowserTurn(isPlayer: false, text: dialogue, practice: practice),
    ]);
    partialText = '';
    partialStatus = '';
    pendingAction = null;
    if (output.isTerminal) _completeSession(output);
    if (!_persist()) {
      // A localStorage assignment is atomic: failure leaves the old snapshot.
      // Restore in-memory mechanics to the same pre-turn boundary.
      _applyPayload(before);
    }
  }

  void _completeSession(core.TurnOutput output) {
    final rewards = <String, int>{};
    if (output.outcome == SessionOutcome.succeed) {
      final p = config.progression;
      rewards['xp'] = core.XpCurve(
        core.XpCurveConfig(
          baseXpPerSession: p.baseXpPerSession,
          difficultyXpExponentMillis: p.difficultyXpExponentMillis,
          trivialGrindSessionThreshold: p.trivialGrindSessionThreshold,
          grindPenaltyMultiplierMillis: p.grindPenaltyMultiplierMillis,
        ),
      ).reward(difficultyTier: 1, sessionCount: completedSessions.length);
      rewards['study'] = p.baseStudyPointsPerSession;
      rewards['cash'] = config.balance.sessionFeeClinicCurrency;
    }
    for (final entry in rewards.entries) {
      _balances[entry.key] = balance(entry.key) + entry.value;
    }
    completedSessions.add({
      'outcome': output.outcome.toJson(),
      'ruleset': sessionRulesetVersion,
      'turns': state.turn,
      'case_id': manifest.id,
      'rewards': rewards,
      'transcript': transcript.map((t) => t.toJson()).toList(),
      'partial_attempts': partialAttempts
          .map((a) => Map<String, dynamic>.of(a))
          .toList(),
    });
    if (manifest.memoryClass == MemoryClass.persistent) {
      _history = const core.MultiSessionResolver().buildNextEnvelope(
        memoryClass: manifest.memoryClass,
        previous: _history,
        sessionOutputs: _outputs,
        manifestClueTokens: manifest.clueTokens,
      );
    }
  }

  Future<void> startNextSession() async {
    if (!completed) return;
    await startNewGame();
  }

  /// Replaces the current session after the UI confirms any active progress.
  /// Career, completed transcripts, preparation and in-memory AI setup survive.
  Future<bool> startNewGame() async {
    if (!canStartNewGame) return false;
    final before = _payload();
    _resetState();
    final saved = _persist();
    if (saved) {
      notice = isOnline() ? '' : L10n.browserOfflineNotice;
    } else {
      _applyPayload(before);
    }
    _notify();
    return saved;
  }

  void cancel() => _cancellation?.cancel();

  String exportSave() => store.read() ?? '';

  Future<void> loadLatestSave() async {
    if (busy) return;
    ready = false;
    storageFailed = false;
    _corrupt = false;
    saveConflict = false;
    notice = '';
    await initialize();
  }

  Future<void> retrySave() async {
    if (_corrupt || !ready) return;
    if (_persist()) notice = L10n.browserSaved;
    _notify();
  }

  Future<void> clearSavedData() async {
    cancel();
    if (busy) return;
    try {
      store.clear();
      _observedSnapshot = null;
      saveConflict = false;
      storageFailed = false;
      _corrupt = false;
      _balances = {};
      completedSessions = [];
      _history = CaseHistoryEnvelope.empty;
      practiceMode = false;
      notice = '';
      ready = false;
      await initialize();
      notice = L10n.browserDataCleared;
    } catch (_) {
      notice = L10n.browserClearFailure;
      storageFailed = true;
    }
    _notify();
  }

  Map<String, dynamic> _payload() => {
    'schema': 1,
    'case_id': manifest.id,
    'checksum': manifest.contentChecksum,
    'ruleset': sessionRulesetVersion,
    'initial_state': _initialState.toJson(),
    'loadout': loadout.toJson(),
    'controllers': controllers.toJson(),
    'actions': _actions.map((a) => a.toJson()).toList(),
    'transcript': transcript.map((t) => t.toJson()).toList(),
    'partial_attempts': partialAttempts
        .map((a) => Map<String, dynamic>.of(a))
        .toList(),
    'completed_sessions': completedSessions
        .map((s) => Map<String, dynamic>.of(s))
        .toList(),
    'balances': Map<String, int>.of(_balances),
    'history': _history.toJson(),
    'practice': practiceMode,
    'partial_text': partialText,
    'partial_status': partialStatus,
    'pending_action': pendingAction?.toJson(),
  };

  bool _persist() {
    if (_corrupt) return false;
    try {
      if (saveConflict || store.read() != _observedSnapshot) {
        saveConflict = true;
        storageFailed = true;
        notice = L10n.browserSaveConflict;
        return false;
      }
      final payload = jsonEncode(_payload());
      if (utf8.encode(payload).length > 4 * 1024 * 1024) {
        throw StateError('Save capacity');
      }
      final encoded = jsonEncode({
        'data': payload,
        'digest': sha256.convert(utf8.encode(payload)).toString(),
      });
      store.write(encoded);
      _observedSnapshot = encoded;
      storageFailed = false;
      return true;
    } catch (_) {
      storageFailed = true;
      notice = L10n.browserSaveFailure;
      return false;
    }
  }

  void _restore(String encoded) {
    if (encoded.length > 5 * 1024 * 1024) {
      throw const FormatException('Save budget');
    }
    final wrapper = jsonDecode(encoded) as Map<String, dynamic>;
    final data = wrapper['data'] as String;
    if (sha256.convert(utf8.encode(data)).toString() != wrapper['digest']) {
      throw const FormatException('Checksum');
    }
    _applyPayload(jsonDecode(data) as Map<String, dynamic>);
  }

  void _applyPayload(Map<String, dynamic> data) {
    if (data['schema'] != 1 ||
        data['case_id'] != manifest.id ||
        data['checksum'] != manifest.contentChecksum ||
        (data['ruleset'] != manifest.rulesetVersion &&
            data['ruleset'] != core.RulesetProfile.currentVersion)) {
      throw const FormatException('Incompatible save');
    }
    sessionRulesetVersion = core.RulesetProfile.forVersion(
      data['ruleset'] as String,
    ).rulesetVersion;
    loadout = Loadout.fromJson(
      (data['loadout'] as Map).cast<String, Object?>(),
    );
    if (loadout.slotCap != config.balance.activeCardSlots ||
        loadout.cardIds.length > loadout.slotCap ||
        loadout.cardIds.toSet().length != loadout.cardIds.length ||
        loadout.cardIds.any((id) => !library.owns(id))) {
      throw const FormatException('Invalid loadout');
    }
    controllers = TherapyControllerSettings.fromJson(
      (data['controllers'] as Map).cast<String, Object?>(),
    );
    _initialState = core.SimState.fromJson(
      (data['initial_state'] as Map).cast<String, Object?>(),
    );
    state = _initialState;
    _actions = (data['actions'] as List)
        .cast<String>()
        .map(InteractionPatternJson.fromJson)
        .toList();
    if (_actions.length > 10000) throw const FormatException('Turn budget');
    _outputs = [];
    for (final action in _actions) {
      if (_outputs.isNotEmpty && _outputs.last.isTerminal) {
        throw const FormatException('Post-terminal action');
      }
      final output = _resolve(action, state);
      _outputs.add(output);
      state = output.nextState;
    }
    transcript = (data['transcript'] as List)
        .map((t) => BrowserTurn.fromJson((t as Map).cast<String, dynamic>()))
        .toList();
    if (transcript.length != _actions.length * 2 ||
        transcript.any((t) => t.text.length > 4096)) {
      throw const FormatException('Transcript mismatch');
    }
    partialAttempts = ((data['partial_attempts'] ?? []) as List)
        .map((a) => (a as Map).cast<String, dynamic>())
        .toList();
    completedSessions = (data['completed_sessions'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    _validateAttempts(partialAttempts);
    if (completedSessions.length > 10000) {
      throw const FormatException('History budget');
    }
    for (final record in completedSessions) {
      final turns = record['turns'];
      if (record['case_id'] != manifest.id ||
          turns is! int ||
          turns < 1 ||
          turns > 10000 ||
          !SessionOutcome.values.any((v) => v.toJson() == record['outcome'])) {
        throw const FormatException('Invalid history record');
      }
      final historyTurns = (record['transcript'] as List)
          .map((t) => BrowserTurn.fromJson((t as Map).cast<String, dynamic>()))
          .toList();
      _validateTranscript(historyTurns, turns);
      final rewards = (record['rewards'] as Map).cast<String, int>();
      _validateBalances(rewards);
      _validateAttempts(
        ((record['partial_attempts'] ?? []) as List)
            .map((t) => (t as Map).cast<String, dynamic>())
            .toList(),
      );
    }
    if (completed &&
        (completedSessions.isEmpty ||
            completedSessions.last['turns'] != state.turn ||
            completedSessions.last['outcome'] !=
                _outputs.last.outcome.toJson() ||
            CanonicalJson.encodeString(completedSessions.last['transcript']) !=
                CanonicalJson.encodeString(data['transcript']))) {
      throw const FormatException('Terminal history mismatch');
    }
    _validateTranscript(transcript, _actions.length);
    _balances = (data['balances'] as Map).cast<String, int>();
    _validateBalances(_balances);
    _history = CaseHistoryEnvelope.fromJson(
      (data['history'] as Map).cast<String, Object?>(),
    );
    practiceMode = data['practice'] as bool;
    partialText = data['partial_text'] as String;
    partialStatus = data['partial_status'] as String;
    pendingAction = data['pending_action'] == null
        ? null
        : InteractionPatternJson.fromJson(data['pending_action'] as String);
    if (partialText.length > 65536) {
      throw const FormatException('Partial budget');
    }
  }

  void _validateTranscript(List<BrowserTurn> turns, int count) {
    if (turns.length != count * 2) {
      throw const FormatException('Transcript count');
    }
    for (var i = 0; i < turns.length; i++) {
      if (turns[i].isPlayer != i.isEven ||
          turns[i].text.isEmpty ||
          turns[i].text.length > 4096) {
        throw const FormatException('Invalid transcript');
      }
    }
  }

  void _validateAttempts(List<Map<String, dynamic>> attempts) {
    if (attempts.length > 10000) throw const FormatException('Attempt budget');
    for (final attempt in attempts) {
      if (attempt['text'] is! String ||
          (attempt['text'] as String).length > 65536 ||
          attempt['action'] is! String ||
          (attempt['action'] as String).length > 80 ||
          attempt['status'] is! String ||
          (attempt['status'] as String).length > 80) {
        throw const FormatException('Invalid interrupted response');
      }
    }
  }

  void _validateBalances(Map<String, int> balances) {
    if (balances.keys.any((k) => !const ['xp', 'study', 'cash'].contains(k)) ||
        balances.values.any((value) => value < 0 || value > 9007199254740991)) {
      throw const FormatException('Invalid rewards');
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    cancel();
    client.dispose();
    super.dispose();
  }
}

String actionLabel(InteractionPattern action) => L10n.browserAction(action);

/// Bytes are a conservative upper bound for supported UTF-8 text tokenizers;
/// unlike the historical whitespace test counter this cannot undercount CJK.
class _ConservativeCounter implements core.TokenCounter {
  const _ConservativeCounter();
  @override
  int count(String text) => utf8.encode(text).length;
}
