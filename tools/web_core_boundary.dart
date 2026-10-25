import 'package:psycore/psycore.dart';

// Assertions are explicit so optimized dart2js also executes them.
void main() {
  void equal(Object actual, Object expected) {
    if (actual != expected) throw StateError('$actual != $expected');
  }

  equal(
      const ClinicEconomy(ClinicEconomyConfig())
          .taxOwedMicros(9007199254740989),
      1801439838948197);

  final maximum = FixedPoint.fromString('922337203685477.5807');
  equal(maximum.exactRaw.toString(), '9223372036854775807');
  equal((maximum + const FixedPoint(1)).exactRaw, maximum.exactRaw);
  equal(maximum.multiplyByRatio(const FixedPoint(10000)), maximum);
  equal(FixedPoint.fromString('-922337203685477.5808').negate(), maximum);
  equal((const FixedPoint(-10000) * 2).raw, -20000);
  equal(FixedPoint.fromString('-0.1250').toString(), '-0.1250');
  var overflow = false;
  try {
    maximum.multiplyByRatioChecked(const FixedPoint(20000));
  } on StateError {
    overflow = true;
  }
  equal(overflow, true);
  final rng = SeededPrng.forRuleset('9223372036854775807', '0.1.0');
  for (final hex in [
    '2a67d7552e039ea7',
    '1a0b48cd43449fdf',
    '2597058fc3b893d0',
    '1affdfd807bb0905',
    '3f903546166cae3c'
  ]) {
    equal(rng.nextUint64().toRadixString(16), hex);
  }
  equal(
      SeededPrng.forRuleset('-9223372036854775808', '0.1.0')
          .nextUint64()
          .toRadixString(16),
      '8071e7d6d65b19b');
  for (final seed in ['18446744073709551616', '-9223372036854775809']) {
    var rejected = false;
    try {
      SeededPrng.forRuleset(seed, '0.1.0');
    } on ArgumentError {
      rejected = true;
    }
    equal(rejected, true);
  }
  equal(SeededPrng.forRuleset('18446744073709551615', '0.1.0').nextUint64(),
      SeededPrng.forRuleset(-1, '0.1.0').nextUint64());
  if (const bool.fromEnvironment('dart.library.js_interop')) {
    var rejected = false;
    try {
      SeededPrng.forRuleset(int.parse('9223372036854775807'), '0.1.0');
    } on ArgumentError {
      rejected = true;
    }
    equal(rejected, true);
  }
  // ignore: avoid_print
  print('Exact 64-bit seed and fixed-point boundaries passed.');
}
