// One source program runs on both Dart VM and dart2js/Node. Its committed
// expected output was captured from the original native implementation.
import 'dart:convert';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

void main() {
  const manifest = PatientManifest(
    id: 'golden-case-001',
    rulesetVersion: '0.1.0',
    contentChecksum:
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
    nameKey: 'golden.case_001.name',
    displayNameKey: 'golden.case_001.display_name',
    styleArchetype: StyleArchetype.vexa,
    initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
    interactionPatterns: [
      InteractionPattern.openQuestion,
      InteractionPattern.validate,
      InteractionPattern.reframe,
      InteractionPattern.setBoundary
    ],
    clueTokens: ['ferve-axine'],
    maxHistoryTurns: 6,
    modelFacingTemplate: 'Golden replay template.',
  );
  final loadout = Loadout(
      cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
  final library = CardLibrary(ownedCardIds: loadout.cardIds.toSet());
  final vectors = <Map<String, Object?>>[];
  for (final seed in [0, 1, -1, 42, 20260715, 9007199254740991]) {
    final prng = SeededPrng.forRuleset(seed, '0.1.0');
    final draws = SeededPrng.forRuleset(seed, '0.1.0');
    final turnSeeds = <String>[];
    for (var turn = 0; turn < 12; turn++) {
      turnSeeds.add(deriveTurnSeed(
              caseId: 'case-🧠',
              turnIndex: turn,
              actionName: manifest.interactionPatterns[turn % 4].name,
              rootSeed: seed,
              profile: RulesetProfile.v0_1_0)
          .toString());
    }
    final outputs = const CoreRunPath().resolveScripted(
      rulesetVersion: '0.1.0',
      manifest: manifest,
      actions: [
        for (var i = 0; i < 16; i++) manifest.interactionPatterns[i % 4]
      ],
      rootSeed: seed,
      clock: const InjectedClock.replay(123456789),
      loadout: loadout,
      library: library,
    );
    vectors.add({
      'seed': seed.toString(),
      'prng': [
        for (var i = 0; i < 20; i++) prng.nextUint64().toRadixString(16)
      ],
      'bounded': [
        for (var i = 0; i < 100; i++) draws.nextInt(i % 2 == 0 ? 1000 : 8)
      ],
      'turn_seeds': turnSeeds,
      'router_seed':
          deriveRouterSeed(profileId: 'profile-🧠', cursor: 7, rootSeed: seed)
              .toString(),
      'turns': outputs.map((o) => utf8.decode(o.toCanonicalBytes())).toList(),
    });
  }
  final pacedVectors = <Map<String, Object?>>[];
  for (final seed in [0, 1, -1, 42, 20260715, 9007199254740991]) {
    for (final actions in [
      [for (var i = 0; i < 16; i++) InteractionPattern.validate],
      [
        ...List.filled(6, InteractionPattern.validate),
        ...List.filled(5, InteractionPattern.openQuestion),
        InteractionPattern.setBoundary,
      ],
      [
        ...List.filled(5, InteractionPattern.reframe),
        ...List.filled(3, InteractionPattern.setBoundary),
        ...List.filled(8, InteractionPattern.validate),
      ],
    ]) {
      final outputs = const CoreRunPath().resolveScripted(
        rulesetVersion: '0.2.0',
        manifest: manifest,
        actions: actions,
        rootSeed: seed,
        clock: const InjectedClock.replay(123456789),
        loadout: loadout,
        library: library,
      );
      pacedVectors.add({
        'seed': seed.toString(),
        'actions': actions.map((action) => action.toJson()).toList(),
        'turns': outputs.map((o) => utf8.decode(o.toCanonicalBytes())).toList(),
      });
    }
  }
  final hundred = FixedPoint.fromWhole(100);
  // ignore: avoid_print
  print(jsonEncode({
    'vectors': vectors,
    'paced_vectors': pacedVectors,
    'money': [
      hundred.applyPercentage(3333).raw,
      hundred.divideBy(3).raw,
      (hundred - hundred.applyPercentage(3333) - hundred.applyPercentage(6667))
          .raw
    ],
    'tax': const ClinicEconomy(ClinicEconomyConfig()).taxOwedMicros(200000000),
  }));
}
