/// Pinned ruleset profiles for the deterministic core.
///
/// Each [RulesetProfile] carries the exact constants used by the portable PRNG
/// and seed derivation for a given [rulesetVersion]. Changing any constant
/// requires a new profile and a ruleset version bump in
/// `config/ruleset_registry.yaml`.
class RulesetProfile {
  /// New sessions opt into this version; saved sessions retain their version.
  static const currentVersion = '0.2.0';

  /// The ruleset version this profile belongs to.
  final String rulesetVersion;

  /// Null preserves the original unbounded session contract for legacy replay.
  final int? maxSessionTurns;
  final int minimumSuccessTurns;
  final int progressPerTurn;
  final int successTrustFloor;
  final int successAgitationCeiling;

  bool get hasBoundedSessions => maxSessionTurns != null;

  /// SplitMix64 golden gamma constant.
  BigInt get splitMixGamma => BigInt.parse(_gammaHex, radix: 16).toSigned(64);
  final String _gammaHex;

  /// SplitMix64 first multiplier.
  BigInt get splitMixMul0 => BigInt.parse(_mul0Hex, radix: 16).toSigned(64);
  final String _mul0Hex;

  /// SplitMix64 second multiplier.
  BigInt get splitMixMul1 => BigInt.parse(_mul1Hex, radix: 16).toSigned(64);
  final String _mul1Hex;

  const RulesetProfile({
    required this.rulesetVersion,
    required String splitMixGamma,
    required String splitMixMul0,
    required String splitMixMul1,
    this.maxSessionTurns,
    this.minimumSuccessTurns = 0,
    this.progressPerTurn = 1,
    this.successTrustFloor = 0,
    this.successAgitationCeiling = 100,
  })  : _gammaHex = splitMixGamma,
        _mul0Hex = splitMixMul0,
        _mul1Hex = splitMixMul1;

  /// The initial profile for ruleset `0.1.0`.
  static const RulesetProfile v0_1_0 = RulesetProfile(
    rulesetVersion: '0.1.0',
    splitMixGamma: '9e3779b97f4a7c15',
    splitMixMul0: 'bf58476d1ce4e5b9',
    splitMixMul1: '94d049bb133111eb',
  );

  /// Backwards-compatible profile for the PoC ruleset version.
  ///
  /// Uses the same constants as [v0_1_0] so existing PoC manifests and receipts
  /// remain replayable (0.8 wire-compat).
  static const RulesetProfile poc_1_0_0 = RulesetProfile(
    rulesetVersion: 'poc-1.0.0',
    splitMixGamma: '9e3779b97f4a7c15',
    splitMixMul0: 'bf58476d1ce4e5b9',
    splitMixMul1: '94d049bb133111eb',
  );

  /// Short, bounded sessions with health and approach-variety success gates.
  /// PRNG constants remain unchanged; gameplay changes are version-isolated.
  static const RulesetProfile v0_2_0 = RulesetProfile(
    rulesetVersion: '0.2.0',
    splitMixGamma: '9e3779b97f4a7c15',
    splitMixMul0: 'bf58476d1ce4e5b9',
    splitMixMul1: '94d049bb133111eb',
    maxSessionTurns: 16,
    minimumSuccessTurns: 12,
    progressPerTurn: 9,
    successTrustFloor: 50,
    successAgitationCeiling: 35,
  );

  static const Map<String, RulesetProfile> _registry = {
    '0.1.0': v0_1_0,
    'poc-1.0.0': poc_1_0_0,
    '0.2.0': v0_2_0,
  };

  /// Resolves a profile from a [rulesetVersion] string.
  ///
  /// Throws [ArgumentError] if the version is unknown.
  factory RulesetProfile.forVersion(String rulesetVersion) {
    final profile = _registry[rulesetVersion];
    if (profile == null) {
      throw ArgumentError('Unknown ruleset version: $rulesetVersion');
    }
    return profile;
  }

  /// Returns true if a profile exists for [rulesetVersion].
  static bool supports(String rulesetVersion) =>
      _registry.containsKey(rulesetVersion);
}
