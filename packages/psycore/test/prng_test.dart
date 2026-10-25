import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('SeededPrng', () {
    const profile = RulesetProfile.v0_1_0;

    test('rejects out-of-range seeds without truncation', () {
      for (final seed in ['18446744073709551616', '-9223372036854775809']) {
        expect(() => SeededPrng(seed, profile), throwsArgumentError);
        expect(
            () => SeededPrng(BigInt.parse(seed), profile), throwsArgumentError);
      }
      expect(SeededPrng('18446744073709551615', profile).nextUint64(),
          SeededPrng(-1, profile).nextUint64());
    });

    test('full-width decimal seeds preserve signed VM vectors exactly', () {
      final prng = SeededPrng('9223372036854775807', profile);
      expect([
        for (var i = 0; i < 5; i++) prng.nextUint64().toRadixString(16)
      ], [
        '2a67d7552e039ea7',
        '1a0b48cd43449fdf',
        '2597058fc3b893d0',
        '1affdfd807bb0905',
        '3f903546166cae3c'
      ]);
      final minimum = SeededPrng('-9223372036854775808', profile);
      expect(minimum.nextUint64().toRadixString(16), '8071e7d6d65b19b');
      expect(() => prng.nextInt(4294967297), throwsArgumentError);
    });

    test('produces the specified SplitMix64 sequence for seed 0', () {
      final prng = SeededPrng(0, profile);
      const expected = <String>[
        '21f5a9b2bcd060c4',
        '6e789e6aa1b965f4',
        '1e0bed5ece3c3cbc',
        '07744756724c81ec',
        '1b39896a51a8749b',
      ];
      for (final hex in expected) {
        expect(
          prng.nextUint64().toRadixString(16).padLeft(16, '0'),
          equals(hex),
        );
      }
    });

    test('reproduces the same sequence from the same seed', () {
      final a = SeededPrng(12345, profile);
      final b = SeededPrng(12345, profile);
      for (var i = 0; i < 20; i++) {
        expect(a.nextUint64(), equals(b.nextUint64()));
      }
    });

    test('produces different sequences for different seeds', () {
      final a = SeededPrng(0, profile);
      final b = SeededPrng(1, profile);
      expect(a.nextUint64(), isNot(equals(b.nextUint64())));
    });

    test('nextInt respects bounds and is deterministic', () {
      final prng = SeededPrng(42, profile);
      const max = 7;
      final draws = <int>[
        for (var i = 0; i < 100; i++) prng.nextInt(max),
      ];
      expect(draws.every((d) => d >= 0 && d < max), isTrue);

      final replay = SeededPrng(42, profile);
      for (final draw in draws) {
        expect(replay.nextInt(max), equals(draw));
      }
    });

    test('nextInt is unbiased for non-power-of-two max', () {
      final prng = SeededPrng(0, profile);
      const max = 7;
      const iterations = 7000; // divisible by 7 for perfect uniformity target
      final counts = List<int>.filled(max, 0);
      for (var i = 0; i < iterations; i++) {
        counts[prng.nextInt(max)]++;
      }
      final expected = iterations ~/ max;
      // Allow 10% deviation; with proper rejection sampling this should pass
      // deterministically for this fixed seed.
      for (var i = 0; i < max; i++) {
        expect(
          counts[i],
          greaterThan((expected * 0.9).floor()),
          reason: 'value $i under-represented',
        );
        expect(
          counts[i],
          lessThan((expected * 1.1).ceil()),
          reason: 'value $i over-represented',
        );
      }
    });

    test('nextIntRange clamps to [min, max)', () {
      final prng = SeededPrng(99, profile);
      const min = 3;
      const max = 10;
      for (var i = 0; i < 50; i++) {
        final v = prng.nextIntRange(min, max);
        expect(v, greaterThanOrEqualTo(min));
        expect(v, lessThan(max));
      }
    });

    test('forRuleset pins profile constants to ruleset version', () {
      final prng = SeededPrng.forRuleset(0, '0.1.0');
      expect(
        prng.nextUint64().toRadixString(16).padLeft(16, '0'),
        equals('21f5a9b2bcd060c4'),
      );
    });

    test('rejects unknown ruleset version', () {
      expect(
        () => SeededPrng.forRuleset(0, '9.9.9'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
