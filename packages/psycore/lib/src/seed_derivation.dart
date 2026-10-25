import 'ruleset_profile.dart';
import 'prng.dart' show exactSeed;

/// Pure, deterministic per-turn seed derivation.
///
/// Mixes only stable inputs (case id, turn index, ordered action, root session
/// seed) using fixed-width wrapping arithmetic and a stable string hash. Never
/// uses [Clock.nowMillis] and never uses [String.hashCode] (Dart randomizes the
/// latter per isolate), so a replay at any time, on any isolate, on any
/// architecture reproduces the identical stream.
BigInt deriveTurnSeed({
  required String caseId,
  required int turnIndex,
  required String actionName,
  required Object rootSeed,
  required RulesetProfile profile,
}) {
  // Stable string hash: process UTF-16 code units deterministically.
  var caseHash = _foldString(caseId);
  var actionHash = _foldString(actionName);

  var seed = exactSeed(rootSeed).toSigned(64);
  seed = _mix(seed, caseHash);
  seed = _mix(seed, BigInt.from(turnIndex).toSigned(64));
  seed = _mix(seed, actionHash);
  seed = _mix(seed, profile.splitMixGamma);
  return seed;
}

/// Derives a deterministic seed for the offline case router cursor.
BigInt deriveRouterSeed({
  required String profileId,
  required int cursor,
  required Object rootSeed,
}) {
  var seed = exactSeed(rootSeed).toSigned(64);
  seed = _mix(seed, _foldString(profileId));
  seed = _mix(seed, BigInt.from(cursor).toSigned(64));
  seed = _mix(seed, RulesetProfile.v0_1_0.splitMixGamma);
  return seed;
}

final _mix0 = BigInt.parse('ff51afd7ed558ccd', radix: 16).toSigned(64);
final _mix1 = BigInt.parse('c4ceb9fe1a85ec53', radix: 16).toSigned(64);
final _offset = BigInt.parse('cbf29ce484222325', radix: 16).toSigned(64);
final _prime = BigInt.parse('100000001b3', radix: 16);

BigInt _mix(BigInt value, BigInt delta) {
  // MurmurHash-style avalanche in 64-bit wrapping arithmetic.
  var v = (value + delta).toSigned(64);
  v ^= (v >> 33);
  v = (v * _mix0).toSigned(64);
  v ^= (v >> 33);
  v = (v * _mix1).toSigned(64);
  v ^= (v >> 33);
  return v;
}

BigInt _foldString(String value) {
  var h = _offset;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    h ^= BigInt.from(unit);
    h = (h * _prime).toSigned(64);
  }
  return h;
}
