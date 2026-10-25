/// Deterministic money / ratios, scaled by 10^4, with signed 64-bit bounds.
/// Exact intermediates and round-half-to-even are identical on VM and web.
class FixedPoint {
  static const int scale = 10000;
  static final BigInt _scale = BigInt.from(scale);
  static final BigInt _maxRaw = BigInt.parse('9223372036854775807');
  static final BigInt _minRaw = -(_maxRaw + BigInt.one);

  final int? _smallRaw;
  final BigInt? _largeRaw;
  const FixedPoint(int raw)
      : _smallRaw = raw,
        _largeRaw = null;
  const FixedPoint.zero()
      : _smallRaw = 0,
        _largeRaw = null;
  FixedPoint._exact(BigInt raw)
      : _smallRaw = null,
        _largeRaw = raw;

  /// Full-width representation, including values outside JavaScript's integer
  /// range. Use decimal strings when serializing this value.
  BigInt get exactRaw {
    if (_largeRaw != null) return _largeRaw!;
    const browser = bool.fromEnvironment('dart.library.js_interop');
    if (browser && _smallRaw!.abs() > 9007199254740991) {
      throw StateError('Large browser amounts must use decimal strings.');
    }
    return BigInt.from(_smallRaw!);
  }

  /// Compatibility accessor. Never silently rounds a large browser value.
  int get raw {
    final exact = exactRaw;
    const browser = bool.fromEnvironment('dart.library.js_interop');
    if (browser && exact.abs() > BigInt.from(9007199254740991)) {
      throw StateError(
          'Use exactRaw for values outside the JSON integer range.');
    }
    final result = exact.toInt();
    if (BigInt.from(result) != exact) {
      throw StateError(
          'Use exactRaw for values outside the platform int range.');
    }
    return result;
  }

  factory FixedPoint.fromWhole(int whole) =>
      FixedPoint._exact(_saturate(BigInt.from(whole) * _scale));
  factory FixedPoint.fromBasisPoints(int basisPoints) =>
      FixedPoint(basisPoints);

  factory FixedPoint.fromString(String value) {
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) throw const FormatException('Invalid fixed-point value');
    final magnitude = BigInt.parse(match[2]!) * _scale +
        BigInt.parse((match[3] ?? '').padRight(4, '0').substring(0, 4));
    return FixedPoint._exact(
        _saturate(match[1] == '-' ? -magnitude : magnitude));
  }

  /// Config seam only: floating point never participates in core arithmetic.
  factory FixedPoint.fromDouble(double value) =>
      FixedPoint((value * scale).roundToEven());
  double toDouble() => exactRaw.toDouble() / scale;
  int toWhole() => (exactRaw ~/ _scale).toInt();

  FixedPoint operator +(FixedPoint other) =>
      FixedPoint._exact(_saturate(exactRaw + other.exactRaw));
  FixedPoint operator -(FixedPoint other) =>
      FixedPoint._exact(_saturate(exactRaw - other.exactRaw));
  FixedPoint operator *(int multiplier) =>
      FixedPoint._exact(_saturate(exactRaw * BigInt.from(multiplier)));

  FixedPoint addChecked(FixedPoint other) =>
      _checked(exactRaw + other.exactRaw);
  FixedPoint subtractChecked(FixedPoint other) =>
      _checked(exactRaw - other.exactRaw);
  FixedPoint multiplyByRatio(FixedPoint ratio) => FixedPoint._exact(
      _saturate(_divideRoundHalfToEven(exactRaw * ratio.exactRaw, _scale)));
  FixedPoint multiplyByRatioChecked(FixedPoint ratio) =>
      _checked(_divideRoundHalfToEven(exactRaw * ratio.exactRaw, _scale));
  FixedPoint divideBy(int divisor) => FixedPoint._exact(
      _saturate(_divideRoundHalfToEven(exactRaw, BigInt.from(divisor))));
  FixedPoint applyPercentage(int basisPoints) =>
      multiplyByRatio(FixedPoint.fromBasisPoints(basisPoints));
  FixedPoint negate() => FixedPoint._exact(_saturate(-exactRaw));

  static FixedPoint _checked(BigInt value) {
    if (value > _maxRaw || value < _minRaw)
      throw StateError('FixedPoint overflow');
    return FixedPoint._exact(value);
  }

  static BigInt _saturate(BigInt value) => value > _maxRaw
      ? _maxRaw
      : value < _minRaw
          ? _minRaw
          : value;
  static BigInt _divideRoundHalfToEven(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) throw ArgumentError('division by zero');
    final quotient = numerator ~/ denominator;
    final twice = numerator.remainder(denominator).abs() * BigInt.two;
    final absDen = denominator.abs();
    if (twice > absDen || (twice == absDen && quotient.isOdd)) {
      return quotient +
          BigInt.from(numerator.sign == denominator.sign ? 1 : -1);
    }
    return quotient;
  }

  @override
  String toString() {
    final value = exactRaw;
    final whole = value.abs() ~/ _scale;
    final frac = (value.abs() % _scale).toString().padLeft(4, '0');
    return '${value.isNegative ? '-' : ''}$whole.$frac';
  }

  @override
  bool operator ==(Object other) =>
      other is FixedPoint && other.exactRaw == exactRaw;
  @override
  int get hashCode => exactRaw.hashCode;
  int compareTo(FixedPoint other) => exactRaw.compareTo(other.exactRaw);
  bool operator <(FixedPoint other) => exactRaw < other.exactRaw;
  bool operator <=(FixedPoint other) => exactRaw <= other.exactRaw;
  bool operator >(FixedPoint other) => exactRaw > other.exactRaw;
  bool operator >=(FixedPoint other) => exactRaw >= other.exactRaw;
}

extension on double {
  int roundToEven() {
    final truncated = truncate();
    final frac = this - truncated;
    if (frac.abs() < 0.5) return truncated;
    if (frac.abs() > 0.5) return truncated + (this > 0 ? 1 : -1);
    // Exactly half: round to even.
    if (truncated.isEven) return truncated;
    return truncated + (this > 0 ? 1 : -1);
  }
}

/// A fixed-point ratio independent of money semantics.
///
/// Used by the config→core seam so percentages arrive as integer basis points
/// and are converted to a [FixedPoint] ratio once, at the boundary. No `double`
/// multiplication ever enters a deterministic rule.
typedef Ratio = FixedPoint;

/// Converts a config percentage `double` to integer basis points.
///
/// This is the **only** place a config `double` percentage becomes a core
/// ratio. The result is an exact integer basis-point value; non-representable
/// values like 0.1 % are rounded half-to-even and the integer bp is what flows
/// into core rules.
int percentToBasisPoints(double percent) {
  final scaled = percent * 100.0;
  final rounded = scaled >= 0 ? scaled + 0.0001 : scaled - 0.0001;
  return rounded.round();
}

/// Converts a config fractional rate `double` (e.g. 0.02) to basis points.
int fractionToBasisPoints(double fraction) {
  final scaled = fraction * 10000.0;
  final rounded = scaled >= 0 ? scaled + 0.0001 : scaled - 0.0001;
  return rounded.round();
}
