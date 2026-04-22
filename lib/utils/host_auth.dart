import "dart:io";
import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

/// Helpers for the "Device Name + Password" connect flow.
///
/// Design:
/// - Host password deterministically maps to a UUID (uuid v5).
/// - That UUID is embedded into the generated connection code by the Go backend.
/// - Receiver resolves server by name (via discovery list) and validates that the
///   code's UUID matches the password-derived UUID before connecting.
///
/// This guarantees that when the host password changes, old password holders
/// can no longer connect.
abstract final class HostAuth {
  // Namespace: DNS (RFC4122 example).
  static const _ns = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  static String deriveUuidFromPassword(String password) {
    final p = password.trim();
    if (p.isEmpty) return '';
    final uuid = const Uuid();
    return uuid.v5(_ns, 'natproxy:$p');
  }

  static String generatePassword({int length = 8}) {
    // Human-friendly (no ambiguous chars 0/O, 1/l/I)
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  /// Parses receiver input in forms like:
  /// - "DeviceName | password"
  /// - "DeviceName:password"
  /// - "DeviceName password" (last token is password)
  static ({String name, String password}) parseNamePassword(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return (name: '', password: '');

    // Prefer explicit separators.
    for (final sep in ['|', ':', '#', '@']) {
      final idx = raw.lastIndexOf(sep);
      if (idx > 0 && idx < raw.length - 1) {
        final name = raw.substring(0, idx).trim();
        final pass = raw.substring(idx + 1).trim();
        return (name: name, password: pass);
      }
    }

    // Fallback: split on whitespace, take last token as password.
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return (name: '', password: '');
    final pass = parts.removeLast();
    final name = parts.join(' ').trim();
    return (name: name, password: pass);
  }

  /// Best-effort extraction of the embedded UUID from a connection code.
  /// Returns '' on failure.
  static String tryExtractUuidFromConnectionCode(String code) {
    try {
      final bin = base64Decode(code.trim());
      final inflated = const ZLibCodec().decoder.convert(bin);
      final jsonStr = utf8.decode(inflated);
      final obj = jsonDecode(jsonStr);
      if (obj is Map<String, dynamic>) {
        final uuid = (obj['uuid'] ?? obj['UUID'] ?? obj['id'])?.toString() ?? '';
        return uuid;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  static bool passwordMatchesCode({required String password, required String code}) {
    final expected = deriveUuidFromPassword(password);
    if (expected.isEmpty) return false;
    final got = tryExtractUuidFromConnectionCode(code);
    return got == expected;
  }
}
