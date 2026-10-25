import 'package:psychemas/psychemas.dart';

/// Localization helpers.
///
/// This is a stub until ARB files are added. It centralizes the string-lookup
/// seam so that features never hard-code user-facing copy.
class L10n implements StringCatalog {
  const L10n();

  static const String appTitle = 'Psychosims';
  static const String browserApproachGuide = 'How approaches work';
  static const String browserControllerHelp =
      'Workspace focus favors open questions; childhood focus favors reframing. Warm delivery favors validation; objective delivery favors boundaries. Balanced settings have no extra fit bonus. Keep all four approaches equipped to retain every option.';
  static const String browserSessionGoal =
      'Successful sessions close after 12–16 choices. Build trust to 50, bring agitation to 35 or less, and combine validation with an open question or reframe. At turn 16 the session ends for review if those goals are not met. Every turn is saved.';
  static const String browserLegacySession =
      'This saved session keeps its original rules. Choose New game for a shorter 12–16-turn session; your completed history and career stay saved.';
  static const String browserCalmGoal =
      'The room is tense. A boundary can reduce agitation; validation can rebuild trust and ease tension.';
  static const String browserTrustGoal =
      'Build rapport: acknowledge the feeling with Validate. Aim for trust 50 or more.';
  static const String browserExploreGoal =
      'There is room to explore. Try an open question or a careful reframe after building trust.';
  static const String browserGoalsMet =
      'Rapport and exploration are established. Keep the conversation steady until it closes.';
  static String browserSessionTurn(int turn, int? limit) =>
      limit == null ? 'Turn $turn · original rules' : 'Turn $turn / $limit';
  static String browserActionHelp(
    InteractionPattern action,
  ) => switch (action) {
    InteractionPattern.openQuestion =>
      'Invite more detail. Best when resistance is high; workspace focus improves its fit.',
    InteractionPattern.validate =>
      'Acknowledge the feeling. Builds trust more reliably with warm delivery and lower agitation.',
    InteractionPattern.reframe =>
      'Offer another perspective. Risky at low trust; childhood focus improves its fit.',
    InteractionPattern.setBoundary =>
      'Slow the pace and set a limit. Most useful at high agitation; objective delivery improves its fit.',
    InteractionPattern.reflect =>
      'Reflect the patient’s words to build rapport.',
    InteractionPattern.discloseParallel =>
      'Offer a parallel to invite more detail.',
  };
  static String browserOutcomeHelp(SessionOutcome outcome) => switch (outcome) {
    SessionOutcome.crisis =>
      'Crisis: agitation is high. Set a boundary to slow the pace, then rebuild trust before reframing.',
    SessionOutcome.stabilize =>
      'Stabilized: agitation is low and trust is established. The session is still in progress.',
    SessionOutcome.succeed =>
      'Session complete. Your career and conversation have been saved.',
    SessionOutcome.fail =>
      'Session ended. Review the conversation and try a different approach.',
    _ =>
      'Conversation in progress. Watch how trust and agitation respond to your choices.',
  };
  static const String browserNewGame = 'New game';
  static const String browserNewGameQuestion = 'Start a new game?';
  static const String browserNewGameExplanation =
      'Your unfinished session and its dialogue will be replaced. Your career and completed session history will stay. This cannot be undone.';
  static const String browserKeepPlaying = 'Keep playing';
  static const String browserConfirmNewGame = 'Start new game';
  static const String noirEyebrow = 'A STUDY IN HUMAN TENSION';
  static const String noirHeadline = 'Every mind\nleaves a trace.';
  static const String noirIntro =
      'Listen closely. Choose your words. Find a way through.';
  static const String noirCurrentCase = 'CASE FILE / 01';
  static const String noirPatientStudy = 'PATIENT STUDY';
  static const String noirPortraitDescription =
      'Original painted portrait of the fictional Restless Hour patient';
  static const String noirCaseNote =
      'Thoughts move faster than words. Give them somewhere to land.';
  static const String noirCaseObservation =
      'Restless thoughts. Careful pacing.';
  static const String noirFieldNotes = 'FIELD NOTES';
  static const String noirSessionRoom = 'THE CONVERSATION';
  static const String noirEmptySession =
      'The room is quiet.\nYour next words matter.';
  static const String noirApproachHint =
      'A question. A pause. A different point of view.';
  static const String noirCareerRecord = 'YOUR PRACTICE';
  static const String noirHistoryIntro =
      'Every conversation leaves something behind.';
  static const String noirPreparation = 'Before the first word';
  static const String noirPreparationHint =
      'Choose the tools you bring into the room.';
  static const String noirSettingsLabel = 'VOICE & LOCAL RECORDS';
  static const String noirPlayerSpeaker = 'YOU';
  static const String noirPatientSpeaker = 'PATIENT';
  static const String noirOfflinePractice = 'No key needed for local practice';
  static String noirCompletedCount(int value) => '$value completed';
  static const String onlineTitle = 'Online practice';
  static const String onlineDescription =
      'Keep signed sessions and your server profile in sync across devices.';
  static const String onlineHeld =
      'This completed path is not covered by current verification. Rewards remain held.';
  static const String onlineCoverage =
      'Only some completion paths are covered by server verification. Rewards are not guaranteed.';
  static const String onlineConditional =
      'This session may qualify for verified rewards. Only supported completion paths are covered.';
  static const String onlineUncoveredStart =
      'This session is outside current verification coverage. Online rewards will be held.';
  static const String onlineQueued =
      'Session saved for sync. The server will confirm verification and any rewards.';
  static const String onlineNotConfigured =
      'Online sign-in is not configured for this build. Local practice is available.';
  static const String onlineGoogle = 'Continue with Google';
  static const String onlineApple = 'Continue with Apple';
  static const String onlineRecoverKey = 'Replace this device’s signing key';
  static const String onlineSignOut = 'Sign out';
  static const String onlineSync = 'Sync now';
  static const String onlineStart = 'Start online session';
  static const String onlineSignedOut = 'Sign in to start online sessions.';
  static const String onlineExpired =
      'This online session expired. Return to Online practice to start a new session.';
  static const String onlineDiscardExpired = 'Discard expired session';
  static const String onlineRejection =
      'The server could not accept this session. Its result is saved here for review.';
  static const String onlineProfileStale =
      'Showing the last saved server profile.';
  static const String onlineProfileCurrent = 'Server profile is up to date.';
  static String onlinePending(int count) => '$count sessions waiting to sync';
  static String onlineProfile(int level, int xp) => 'Level $level · $xp XP';
  static String onlineVerdict(
    String status, {
    String rewardStatus = 'held_unproven',
  }) {
    if (status != 'accepted') return 'Not accepted';
    return switch (rewardStatus) {
      'certified' => 'Synced · result verified',
      'certified_unrewarded' => 'Synced · verified without reward',
      _ => 'Synced · rewards held',
    };
  }

  static String onlineRewardDetail(ReceiptVerdict verdict) {
    if (verdict.status != 'accepted') return onlineRejection;
    if (verdict.rewardStatus == 'certified') {
      final whole = verdict.cashMicrosAwarded ~/ 1000000;
      final fraction = (verdict.cashMicrosAwarded % 1000000)
          .toString()
          .padLeft(6, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      final cash = fraction.isEmpty ? '$whole' : '$whole.$fraction';
      return 'Server rewards: ${verdict.xpAwarded} XP · ${verdict.studyPointsAwarded} study points · $cash cash';
    }
    if (verdict.rewardStatus == 'certified_unrewarded') {
      return switch (verdict.rewardReason) {
        'cooldown' => 'Result verified. The reward cooldown is still active.',
        'window_budget' =>
          'Result verified. The reward limit for this time window has been reached.',
        'economy_disabled' =>
          'Result verified. Online rewards are currently disabled.',
        'balance_limit' =>
          'Result verified. Your balance has reached its limit.',
        'already_cured' =>
          'Result verified. This patient has already received completion rewards.',
        _ => 'Result verified without a reward.',
      };
    }
    return onlineHeld;
  }

  static String onlineError(String kind) {
    if (kind == 'expired_permit') return onlineExpired;
    if (kind == 'sign_in_not_configured') return onlineNotConfigured;
    if (kind == 'offline' || kind == 'timeout') {
      return 'Connection unavailable. Saved sessions will retry when you reconnect.';
    }
    if (kind == 'signed_out' ||
        kind == 'session_expired' ||
        kind == 'account_mismatch') {
      return 'Sign in again to continue with this account.';
    }
    if (kind == 'content_mismatch') {
      return 'This case changed on the server. Update the case before starting.';
    }
    return 'Online practice is unavailable. Check your connection and secure storage, then retry.';
  }

  static const String sessionSuccess = 'Session complete';
  static const String sessionFailure = 'Session ended';
  static const String sessionSaved =
      'Your practice history and progress are saved on this device.';
  static const String sessionNext = 'Next session';
  static const String sessionRetry = 'Retry';
  static const String homeStartPocSession = 'Prepare session';
  static const String careerTitle = 'Local practice career';
  static const String careerEmpty =
      'Complete a session to build your practice history.';
  static const String careerLoadError =
      'Your saved career could not be read. Retry after checking device storage.';
  static const String careerStudy = 'Study';
  static const String careerCash = 'Cash';
  static String careerSessions(int count) => '$count sessions completed';
  static String careerTurns(int count) => '$count turns';
  static String careerBalances({
    required int xp,
    required int study,
    required int cash,
  }) => 'XP: $xp · $careerStudy: $study · $careerCash: $cash';

  static const String homeFetchModel = 'Download model';
  static const String modelFetchTitle = 'Download Model';
  static const String modelFetchDescription =
      'A local model is required for private, offline dialogue. Downloads resume if interrupted.';
  static const String modelFetchStart = 'Download';
  static const String modelFetchPause = 'Pause';
  static const String modelFetchResume = 'Resume';
  static const String modelFetchMeteredLabel =
      'Defer until unmetered connection';
  static const String modelFetchComplete = 'Download complete.';

  static const String loadoutTitle = 'Prepare Session';
  static const String loadoutStyleLabel = 'Style';
  static const String loadoutInitialStateLabel = 'Initial state';
  static const String loadoutActiveCardsLabel = 'Active cards';
  static const String loadoutMissingTacticsLabel = 'Missing tactics';

  static String loadoutStyle(String archetype) =>
      '$loadoutStyleLabel: $archetype';
  static String loadoutInitialState(String state) =>
      '$loadoutInitialStateLabel: $state';
  static String loadoutActiveCards(int active, int cap) =>
      '$loadoutActiveCardsLabel: $active / $cap';
  static String loadoutMissingTactics(List<String> tactics) =>
      '$loadoutMissingTacticsLabel: ${tactics.join(', ')}';
  static const String loadoutOwnedCardsSemanticLabel =
      'Owned cards, toggle to equip or unequip';
  static const String loadoutEquipped = 'Equipped';
  static const String loadoutOwned = 'Owned';
  static const String loadoutRemoveTooltip = 'Remove from loadout';
  static const String loadoutAddTooltip = 'Add to loadout';
  static const String loadoutFocusLabel = 'Focus';
  static const String loadoutEmotionalDeliveryLabel = 'Emotional Delivery';
  static const String loadoutFocusChildhood = 'Childhood';
  static const String loadoutFocusBalanced = 'Balanced';
  static const String loadoutFocusWorkspace = 'Workspace';
  static const String loadoutDeliveryWarm = 'Warm';
  static const String loadoutDeliveryObjective = 'Objective';
  static const String loadoutDeliveryBalanced = 'Balanced';
  static const String loadoutStartSession = 'Start Session';
  static const String loadoutInvalid =
      'Equip at least one available card within the session slot limit.';

  // Static browser PWA copy; keep presentation strings behind this seam.
  static const String browserOnline = 'Online — AI available with a key';
  static const String browserOffline = 'Offline — AI paused';
  static const String browserLoadingCase = 'Loading case…';
  static const String browserHome = 'Home';
  static const String browserSession = 'Session';
  static const String browserHistory = 'History';
  static const String browserSettings = 'Settings';
  static const String browserResume = 'Resume Session';
  static const String browserAiSettings = 'AI settings';
  static const String browserLocalPrivacy =
      'Your game, transcripts, and progress stay on this device. New AI dialogue needs an internet connection. Local practice works offline after the app finishes caching.';
  static const String browserFictionalNotice =
      'A fictional patient simulation for play and exploration.';
  static const String browserLoadoutLocked =
      'Your current session keeps its starting loadout. Complete it to prepare another.';
  static const String browserTacticsCovered =
      'All available tactics are covered.';
  static const String browserSelectApproach = 'Select an approach to begin.';
  static const String browserIncompleteResponses =
      'Previous incomplete responses';
  static const String browserWaiting = 'Waiting for a response…';
  static const String browserSessionSaved =
      'Session, transcript, and progress saved on this device.';
  static const String browserConfigureAi =
      'Configure AI or choose local practice';
  static const String browserChooseApproach = 'Choose an approach';
  static const String browserStop = 'Stop';
  static const String browserSessionHistory = 'Session history';
  static const String browserHistoryEmpty =
      'Completed sessions and their transcripts will appear here.';
  static const String browserPracticeWithoutAi = 'Practice without AI';
  static const String browserPracticeDescription =
      'Offline mechanics with authored patient dialogue. No AI requests.';
  static const String browserAiRequirements =
      'AI dialogue requires a connection, your key, and a selected model.';
  static const String browserPlayerAction = 'Player action';
  static const String browserPatientResponse = 'Patient response';
  static const String browserLocalDialogue = 'Local practice dialogue';
  static const String browserLoadLatest = 'Load latest saved game';
  static const String browserRetrySaving = 'Retry saving';
  static const String browserAiPrivacy =
      'Optional online patient dialogue uses OpenRouter. Sending an approach shares the fictional case and recent dialogue with OpenRouter and the selected provider. Every AI request requires a verified zero-data-retention endpoint and forbids provider data collection. No analytics are collected by this app.';
  static const String browserKeyPrivacy =
      'Your key stays only in this tab’s memory and is forgotten on reload. Saved transcripts stay in this browser. Never enter real patient information.';
  static const String browserKeyLabel = 'OpenRouter API key';
  static const String browserKeyHint = 'Paste your own key';
  static const String browserUseKey = 'Use key for this tab';
  static const String browserForgetKey = 'Forget key';
  static const String browserKeyPresent = 'Key is present in memory.';
  static const String browserKeyAbsent = 'No key in memory.';
  static const String browserFreeModels =
      'Only exact model variants with a verified free, zero-data-retention text endpoint are eligible. Availability can change; refresh and explicitly select another eligible model if needed.';
  static const String browserLoadingModels = 'Loading models…';
  static const String browserRefreshCatalog = 'Refresh model catalog';
  static const String browserPatientModel = 'Patient model';
  static const String browserSavedData = 'Saved data';
  static const String browserStorageHelp =
      'Browser storage contains your local game and transcripts. Clearing browser data removes them. Export a copy before clearing storage or moving devices.';
  static const String browserStorageUnavailable = 'Storage is unavailable.';
  static const String browserExport = 'Export saved data';
  static const String browserNoSavedData = 'No saved data yet.';
  static const String browserCopy = 'Copy';
  static const String browserClose = 'Close';
  static const String browserClearQuestion = 'Clear local saved data?';
  static const String browserClearExplanation =
      'This removes progress and transcripts from this browser. Export a copy first if you want to keep them.';
  static const String browserKeepData = 'Keep data';
  static const String browserClearData = 'Clear data';
  static const String browserClearLocalData = 'Clear local saved data';
  static const String browserOfflineNotice =
      'You are offline. AI actions are paused; saved sessions and local practice remain available.';
  static const String browserInterrupted = 'Interrupted — not applied';
  static const String browserPreviousInterrupted =
      'The previous response was interrupted. Its partial text is saved. Retry only when you choose.';
  static const String browserReadFailure =
      'Could not read this saved game or bundled case. Existing data has been preserved. Export it before clearing storage.';
  static const String browserKeyStored =
      'Key kept in memory for this tab only.';
  static const String browserKeyForgotten =
      'Key forgotten. Saved game and transcripts remain on this device.';
  static const String browserNoModels =
      'No eligible models are available. You can continue local practice.';
  static const String browserCatalogFailure =
      'Could not load the model catalog. Check your connection and try again explicitly.';
  static const String browserOfflineAction =
      'You are offline. AI actions are paused; choose local practice to continue without new AI dialogue.';
  static const String browserConfigureNotice =
      'Add a key and choose a validated model in AI settings, or use local practice.';
  static const String browserFallbackDialogue =
      'I need a moment to gather my thoughts.';
  static const String browserPracticeClosing =
      'I would like to stop here for today.';
  static List<String> browserPracticeReplies(
    InteractionPattern action, {
    required bool guarded,
  }) => switch (action) {
    InteractionPattern.openQuestion =>
      guarded
          ? const [
              browserFallbackDialogue,
              'There are several thoughts at once. I am not sure which one to put into words.',
              'I want to answer, but the question is hard to hold onto while my mind races.',
              'Let me stay with one part of that question before moving to the next.',
            ]
          : const [
              'My thoughts keep getting ahead of my words. That is the part I want to explain.',
              'When I try to sit still, I notice how quickly my attention moves on.',
              'There is a gap between what I am thinking and what I manage to say.',
              'I can start with this moment: I am trying to finish one thought at a time.',
            ],
    InteractionPattern.validate =>
      guarded
          ? const [
              'I hear you. My thoughts are still racing, so I need a little room to answer.',
              'Being heard matters, even while I am finding it hard to settle into this conversation.',
              'Thank you for staying with what I said. I am not ready to add much yet.',
              'I do want you to understand. I am still choosing which words feel right.',
            ]
          : const [
              'It helps to hear that you are following me. I can leave a little space between my words.',
              'Yes, that is what I was trying to say. I do not have to rush the next sentence.',
              'I feel heard. Let me stay with the thought instead of jumping straight past it.',
              'Thank you. I can take my time explaining this part.',
            ],
    InteractionPattern.reframe =>
      guarded
          ? const [
              'That way of looking at it feels too far from what I am trying to say.',
              'I am not ready to see it differently. Can we stay with my words for a moment?',
              'I can hear the other view, but I am still holding onto my own.',
              'The new angle is hard to follow while my thoughts are moving this fast.',
            ]
          : const [
              'That is another way to look at it. I can consider it without rushing to agree.',
              'Perhaps there is more than one way to describe this restless feeling.',
              'I can hold that possibility alongside what I said before.',
              'Looking at it from that angle gives me something different to think about.',
            ],
    InteractionPattern.setBoundary =>
      guarded
          ? const [
              'All right. Let us pause here; I am not ready to move further into it.',
              'I can stay within that limit. There is already a lot in my mind.',
              'A clear stopping point helps me know what you are asking of me.',
              'We can leave that part for now. I need time with what is already here.',
            ]
          : const [
              'All right. We can keep this to one thought for now.',
              'I understand where we are pausing. I do not need to fill every silence.',
              'That gives the conversation a clear edge. I can stay here for a moment.',
              'Let us leave the next part aside and make room for this one.',
            ],
    InteractionPattern.reflect =>
      guarded
          ? const [
              'That is close to what I said, though it still feels hard to hear it back.',
              'I recognise those words. I am not sure I can add to them yet.',
              'You caught part of it. There is more, but I need time to find the words.',
              'Hearing it repeated makes me want to check that I said it clearly.',
            ]
          : const [
              'Yes, that sounds like what I meant. Hearing it back helps me follow the thought.',
              'You noticed the part where my words could not keep up.',
              'That puts words around something I was struggling to finish saying.',
              'I recognise myself in that description. I can stay with it a little longer.',
            ],
    InteractionPattern.discloseParallel =>
      guarded
          ? const [
              'I hear the comparison, but I want to be careful about how it fits my experience.',
              'There may be something similar there. I need a moment before drawing a connection.',
              'I can follow part of that parallel, though my own thoughts are still tangled.',
              'Let me think about the shared part without assuming everything is the same.',
            ]
          : const [
              'The parallel gives me a way to describe the pace of my thoughts.',
              'I can see a connection there, even if my experience has its own shape.',
              'That comparison gives me somewhere to begin explaining the restlessness.',
              'There is something familiar in that. I want to put it in my own words.',
            ],
  };
  static const String browserReceiving = 'Receiving — not applied';
  static const String browserStopped =
      'Response stopped. Partial output is saved; the turn was not applied. Retry is manual.';
  static const String browserRejected = 'Rejected — not applied';
  static const String browserRejectedNotice =
      'The response did not meet this patient’s dialogue rules. State is unchanged. Retry only when you choose.';
  static const String browserResponseFailure =
      'The response could not finish. Partial text is saved; state is unchanged. Retry is manual.';
  static const String browserSaved = 'Saved on this device.';
  static const String browserDataCleared = 'Local saved data cleared.';
  static const String browserClearFailure = 'Could not clear browser storage.';
  static const String browserSaveConflict =
      'The saved game changed in another tab. Load the latest saved game before continuing. Nothing was overwritten.';
  static const String browserSaveFailure =
      'Could not save on this device. The turn was not applied. Free browser storage, then retry saving.';

  static String browserInitialAxes(int trust, int agitation, String defense) =>
      'Trust: $trust · Agitation: $agitation · Defense: $defense';
  static String browserEquipTooltip(bool equipped, String action) =>
      '${equipped ? 'Remove' : 'Equip'} $action';
  static String browserTactics(Iterable<String> tactics) =>
      'Tactics: ${tactics.join(', ')}';
  static String browserTurn(int value) => 'Turn $value';
  static String browserTrust(int value) => 'Trust $value';
  static String browserAgitation(int value) => 'Agitation $value';
  static String browserProgress(int value) => 'Progress $value';
  static String browserAttempt(String action, String status) =>
      '$action · $status';
  static String browserRetryAction(String action) => 'Retry $action';
  static String browserHistorySession(int number, String outcome) =>
      'Session $number · $outcome';
  static String browserHistoryTurns(int value) => '$value turns';
  static String browserFocus(FocusAxis value) => switch (value) {
    FocusAxis.childhood => loadoutFocusChildhood,
    FocusAxis.balanced => loadoutFocusBalanced,
    FocusAxis.workspace => loadoutFocusWorkspace,
  };
  static String browserDelivery(EmotionalDelivery value) => switch (value) {
    EmotionalDelivery.warm => loadoutDeliveryWarm,
    EmotionalDelivery.balanced => loadoutDeliveryBalanced,
    EmotionalDelivery.objective => loadoutDeliveryObjective,
  };
  static String browserAction(InteractionPattern action) => switch (action) {
    InteractionPattern.openQuestion => 'Open question',
    InteractionPattern.validate => 'Validate',
    InteractionPattern.reframe => 'Reframe',
    InteractionPattern.setBoundary => 'Set boundary',
    InteractionPattern.reflect => 'Reflect',
    InteractionPattern.discloseParallel => 'Disclose parallel',
  };

  static const _catalog = <String, String>{
    'manifests.poc_vexa_001.name': 'The Restless Hour',
    'manifests.poc_vexa_001.display_name': 'Restless Hour',
    'session.actions_label': 'Choose an approach',
    'session.cancel_button': 'Stop',
    'session.loading': 'Loading case...',
    'session.empty_turns': 'Select an action to begin.',
    'home.start_poc_session': 'Start PoC Session',
    'home.fetch_model': 'Fetch Model',
    'model_fetch.no_source': 'No model source is configured.',
    'model_fetch.metered': 'Download deferred until unmetered connection.',
    'model_fetch.disk_space': 'Not enough free space.',
    'model_fetch.checksum_error': 'Model file is corrupt; retry to re-fetch.',
    'errors.model_load_failed': 'The model could not be loaded.',
    'errors.model_corrupt': 'The model file appears to be corrupt.',
    'errors.out_of_memory':
        'Not enough memory. Try a smaller model in settings.',
    'errors.generation_cancelled': 'Generation was cancelled.',
    'errors.generation_failed': 'The response could not be generated.',
    'errors.offline': 'You are offline.',
  };

  /// Resolve an error code to a user-facing message.
  /// Real implementation will look up the config-selected locale.
  String errorMessage(String code) => _catalog[code] ?? '[$code]';

  /// Resolve a manifest name key.
  String manifestName(String key) => _catalog[key] ?? key;

  /// Resolve a manifest presentation key.
  String manifestPresentation(String key) => _catalog[key] ?? key;

  /// Returns true if [key] is present in the catalog.
  @override
  bool containsKey(String key) => _catalog.containsKey(key);

  static String modelFetchProgress(int percent) => '$percent%';

  static String get modelFetchNoSource => _catalog['model_fetch.no_source']!;

  static String get modelFetchMetered => _catalog['model_fetch.metered']!;

  static String modelFetchDiskSpace(int required, int free) =>
      '${_catalog['model_fetch.disk_space']!} '
      'Required: $required bytes, free: $free bytes.';

  static String get modelFetchChecksumError =>
      _catalog['model_fetch.checksum_error']!;
}
