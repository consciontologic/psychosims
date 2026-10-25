import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

const _manifest = PatientManifest(
  id: 'poc-vexa-001',
  rulesetVersion: 'poc-1.0.0',
  contentChecksum:
      'sha256:517609f41dab0df37b5f8b95a04e4de316f29a4f85bd5b05098ae3d1a7f3fb53',
  nameKey: 'name',
  displayNameKey: 'display',
  styleArchetype: StyleArchetype.vexa,
  initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
  interactionPatterns: [
    InteractionPattern.openQuestion,
    InteractionPattern.validate,
    InteractionPattern.reframe,
    InteractionPattern.setBoundary,
  ],
  clueTokens: ['ferve-axine', 'restless-activation'],
  maxHistoryTurns: 6,
  modelFacingTemplate: 'template',
);
const _loadout = Loadout(
  cardIds: ['open_question', 'validate', 'reframe', 'set_boundary'],
  slotCap: 6,
);
const _library = CardLibrary(
  ownedCardIds: {'open_question', 'validate', 'reframe', 'set_boundary'},
);
const _resolver = TurnResolver(InjectedClock.replay(0));

TurnOutput _step(SimState state, InteractionPattern action,
        {String version = '0.2.0',
        TherapyControllerSettings controllers =
            const TherapyControllerSettings()}) =>
    _resolver.resolve(TurnInput(
      rulesetVersion: version,
      manifest: _manifest,
      state: state,
      action: action,
      loadout: _loadout,
      library: _library,
      controllers: controllers,
    ));

List<TurnOutput> _play(List<InteractionPattern> actions,
    {int seed = 42,
    String version = '0.2.0',
    TherapyControllerSettings controllers =
        const TherapyControllerSettings()}) {
  var state = SimState.fromInitialState(seed, _manifest.initialState);
  final outputs = <TurnOutput>[];
  for (final action in actions) {
    final output =
        _step(state, action, version: version, controllers: controllers);
    outputs.add(output);
    state = output.nextState;
    if (output.isTerminal) break;
  }
  return outputs;
}

void main() {
  group('Bounded 0.2.0 sessions', () {
    test('mixed rapport and exploration reaches healthy success in 12 turns',
        () {
      final result = _play([
        ...List.filled(6, InteractionPattern.validate),
        ...List.filled(5, InteractionPattern.openQuestion),
        InteractionPattern.setBoundary,
      ]);
      expect(result, hasLength(12));
      expect(result.take(11).every((o) => !o.isTerminal), isTrue);
      expect(result.last.isTerminal, isTrue);
      expect(result.last.outcome, SessionOutcome.succeed);
      expect(result.last.nextState.trustScore, greaterThanOrEqualTo(50));
      expect(result.last.nextState.agitationLevel, lessThanOrEqualTo(35));
    });

    test('repeating Validate alone ends with review instead of reward farming',
        () {
      final result = _play(List.filled(100, InteractionPattern.validate));
      expect(result, hasLength(16));
      expect(result.last.outcome, SessionOutcome.fail);
      expect(result.last.isTerminal, isTrue);
      expect(result.last.nextState.sessionProgress, 100);
    });

    test('low trust cannot succeed just because time elapsed', () {
      final result = _play(
        [
          InteractionPattern.openQuestion,
          ...List.filled(99, InteractionPattern.validate)
        ],
        controllers: const TherapyControllerSettings(
          emotionalDelivery: EmotionalDelivery.objective,
        ),
      );
      expect(result, hasLength(16));
      expect(result.last.nextState.trustScore, lessThan(50));
      expect(result.last.outcome, SessionOutcome.fail);
    });

    test('bound closes a crisis instead of allowing unbounded turns', () {
      final output = _step(
        const SimState(
            seed: 42,
            turn: 15,
            trustScore: 100,
            agitationLevel: 84,
            sessionProgress: 100),
        InteractionPattern.validate,
      );
      expect(output.isTerminal, isTrue);
      expect(output.outcome, SessionOutcome.fail);
      expect(output.nextState.turn, 16);
    });

    test('boundary creates a useful recovery window during crisis', () {
      final output = _step(
        const SimState(
            seed: 42,
            turn: 5,
            trustScore: 30,
            agitationLevel: 84,
            sessionProgress: 45),
        InteractionPattern.setBoundary,
      );
      expect(output.nextState.agitationLevel, lessThan(80));
      expect(output.outcome, isNot(SessionOutcome.crisis));
      expect(output.isTerminal, isFalse);
    });

    test('high-pressure fresh start can resolve a boundary before walkout', () {
      final output = _step(
        const SimState(seed: 42, trustScore: 30, agitationLevel: 100),
        InteractionPattern.setBoundary,
      );
      expect(output.nextState.turn, 1);
      expect(output.nextState.agitationLevel, lessThan(95));
      expect(output.isTerminal, isFalse);
      // The next turn must also remain actionable after first-turn containment.
      final next = _step(output.nextState, InteractionPattern.setBoundary);
      expect(next.nextState.turn, 2);
      expect(next.nextState.agitationLevel,
          lessThan(output.nextState.agitationLevel));
    });

    test('uncontained high-pressure fresh start returns an explicit outcome',
        () {
      final output = _step(
        const SimState(seed: 42, trustScore: 30, agitationLevel: 100),
        InteractionPattern.reframe,
      );
      expect(output.nextState.turn, 1);
      expect(output.outcome, SessionOutcome.fail);
      expect(output.isTerminal, isTrue);
      expect(() => _step(output.nextState, InteractionPattern.setBoundary),
          throwsStateError);
    });

    test('five premature reframes can recover through boundary and rapport',
        () {
      final outputs = _play([
        ...List.filled(5, InteractionPattern.reframe),
        ...List.filled(3, InteractionPattern.setBoundary),
        ...List.filled(8, InteractionPattern.validate),
      ], seed: 0);
      expect(outputs[4].outcome, SessionOutcome.crisis);
      expect(outputs[4].nextState.agitationLevel, 81);
      expect(outputs[5].outcome, SessionOutcome.ongoing);
      expect(outputs.last.outcome, SessionOutcome.succeed);
      expect(outputs.last.nextState.turn, 14);
      expect(outputs.last.nextState.trustScore, 57);
      expect(outputs.last.nextState.agitationLevel, 33);
    });

    test('mixed approach remains viable across 100 deterministic seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        final outputs = _play([
          ...List.filled(6, InteractionPattern.validate),
          ...List.filled(5, InteractionPattern.openQuestion),
          InteractionPattern.setBoundary,
        ], seed: seed);
        expect(outputs.last.outcome, SessionOutcome.succeed,
            reason: 'seed=$seed');
        expect(outputs.length, 12);
      }
    });

    test('open exploration is productive after rapport lowers defenses', () {
      final output = _step(
        const SimState(seed: 42, trustScore: 50, agitationLevel: 30),
        InteractionPattern.openQuestion,
      );
      expect(output.nextState.trustScore, greaterThan(50));
      expect(output.deltas.first.contextFit, ContextFit.partial);
    });

    test('session progress deltas record the actual clamped change', () {
      final outputs = _play(List.filled(16, InteractionPattern.validate));
      final progress = outputs
          .expand((output) => output.deltas)
          .where((delta) => delta.axis == StateAxis.sessionProgress)
          .map((delta) => delta.deltaMillis)
          .toList();
      expect(progress.take(11), everyElement(9));
      expect(progress[11], 1);
      expect(progress.skip(12), everyElement(0));
      expect(progress.reduce((a, b) => a + b), 100);
    });

    test('approach history survives a state snapshot and deterministic replay',
        () {
      final outputs = _play([
        InteractionPattern.validate,
        InteractionPattern.openQuestion,
      ]);
      final state = outputs.last.nextState;
      final restored = SimState.fromJson(state.toJson());
      expect(restored.hasRapportApproach, isTrue);
      expect(restored.hasExplorationApproach, isTrue);
      expect(restored.toCanonicalBytes(), state.toCanonicalBytes());
      expect(_step(restored, InteractionPattern.validate).toCanonicalBytes(),
          _step(state, InteractionPattern.validate).toCanonicalBytes());
    });

    test('all single-action strategies stop by 16 over many seeds', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final action in _manifest.interactionPatterns) {
          final result = _play(List.filled(100, action), seed: seed);
          expect(result.length, lessThanOrEqualTo(16),
              reason: 'seed=$seed action=$action');
          expect(result.last.isTerminal, isTrue);
          expect(result.last.outcome, isNot(SessionOutcome.succeed));
        }
      }
    });

    test('terminal session rejects another turn', () {
      final result = _play(List.filled(16, InteractionPattern.validate));
      expect(() => _step(result.last.nextState, InteractionPattern.validate),
          throwsStateError);
    });
  });

  group('Immutable legacy behavior', () {
    test('old rules retain the original 100 turn result', () {
      for (final version in ['0.1.0', 'poc-1.0.0']) {
        final outputs = _play(List.filled(100, InteractionPattern.validate),
            version: version);
        expect(outputs, hasLength(100));
        expect(outputs.last.outcome, SessionOutcome.succeed);
        expect(outputs.last.nextState.toJson().containsKey('approach_mask'),
            isFalse);
      }
    });

    test('old crisis trace remains exactly nonterminal at its old turn count',
        () {
      final output = _step(
        const SimState(
            seed: 42,
            turn: 99,
            trustScore: 100,
            agitationLevel: 84,
            sessionProgress: 99),
        InteractionPattern.validate,
        version: 'poc-1.0.0',
      );
      expect(output.nextState.turn, 100);
      expect(output.nextState.agitationLevel, 84);
      expect(output.outcome, SessionOutcome.crisis);
      expect(output.isTerminal, isFalse);
    });
  });
}
