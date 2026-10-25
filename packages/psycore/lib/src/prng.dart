import 'ruleset_profile.dart';

/// Portable, specified integer PRNG for the deterministic core.
///
/// Preserves the historical VM stream: signed 64-bit wrapping and arithmetic
/// right shifts. BigInt makes those exact semantics portable to JavaScript.
/// The algorithm and constants are pinned to a [RulesetProfile] selected by
/// `ruleset_version` (0.7): any change is a tracked ruleset bump, not a silent
/// replay break.
///
/// Only integer draws are exposed on the core path. There is no `nextDouble`,
/// no `dart:math.Random`, and no platform-dependent float sequence.
class SeededPrng {
  final BigInt _gamma;
  final BigInt _mul0;
  final BigInt _mul1;
  BigInt _state;

  /// Creates a PRNG from a 64-bit seed and a pinned [profile].
  SeededPrng(Object seed, RulesetProfile profile)
      : _state = exactSeed(seed).toSigned(64),
        _gamma = profile.splitMixGamma,
        _mul0 = profile.splitMixMul0,
        _mul1 = profile.splitMixMul1;

  /// Creates a PRNG from a 64-bit seed and a ruleset version string.
  factory SeededPrng.forRuleset(Object seed, String rulesetVersion) {
    return SeededPrng(seed, RulesetProfile.forVersion(rulesetVersion));
  }

  /// Returns the historical draw exactly. Serialize this as a decimal string;
  /// a JavaScript JSON number cannot hold all 64-bit values.
  BigInt nextUint64() {
    _state = (_state + _gamma).toSigned(64);
    var z = _state;
    z = ((z ^ (z >> 30)) * _mul0).toSigned(64);
    z = ((z ^ (z >> 27)) * _mul1).toSigned(64);
    z = z ^ (z >> 31);
    return z;
  }

  /// Returns a deterministic int in [0, max).
  ///
  /// Uses rejection sampling in 32-bit unsigned space to avoid modulo bias
  /// when [max] does not evenly divide 2^32. [max] must be positive and
  /// small enough to fit in 32 bits (more than enough for all core draws).
  int nextInt(int max) {
    if (max <= 0 || max > 4294967296) {
      throw ArgumentError('max must be in 1..2^32: $max');
    }
    if (max == 1) return 0;
    // Fast path for powers of two.
    if ((max & (max - 1)) == 0) {
      return (nextUint64() & BigInt.from(max - 1)).toInt();
    }
    const full = 0xFFFFFFFF; // 2^32 - 1
    final limit = full - ((full % max) + 1) % max;
    while (true) {
      final draw = (nextUint64() & BigInt.from(0xFFFFFFFF)).toInt();
      if (draw <= limit) return draw % max;
    }
  }

  /// Returns a deterministic int in [min, max).
  int nextIntRange(int min, int max) {
    if (min >= max) {
      throw ArgumentError('min must be less than max: $min >= $max');
    }
    return min + nextInt(max - min);
  }
}

/// Accept exact integer seeds or their portable decimal serialization. Browser
/// callers must use strings/BigInt above the JSON safe-integer range.
/// Signed values and unsigned 64-bit bit patterns are accepted; wider input
/// fails instead of silently truncating to an unrelated stream.
BigInt exactSeed(Object seed) {
  final BigInt value;
  if (seed is BigInt) {
    value = seed;
  } else if (seed is String) {
    value = BigInt.parse(seed);
  } else if (seed is int) {
    const browser = bool.fromEnvironment('dart.library.js_interop');
    if (browser && seed.abs() > 9007199254740991) {
      throw ArgumentError('Large browser seeds must use decimal strings.');
    }
    value = BigInt.from(seed);
  } else {
    throw ArgumentError('Seed must be an integer or decimal string.');
  }
  if (value < -(BigInt.one << 63) || value > (BigInt.one << 64) - BigInt.one) {
    throw ArgumentError('Seed must fit a 64-bit signed or unsigned value.');
  }
  return value;
}
