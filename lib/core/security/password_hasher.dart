import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const int iterations = 120000;
  static const int saltLength = 16;
  static const int derivedKeyLength = 32;

  static String createSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(saltLength, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 according to RFC 8018, block 1..N.
  static String hash(String password, String saltBase64) {
    final salt = base64Url.decode(saltBase64);
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    final output = <int>[];
    var blockIndex = 1;
    while (output.length < derivedKeyLength) {
      final first = hmac.convert([...salt, (blockIndex >> 24) & 0xff, (blockIndex >> 16) & 0xff, (blockIndex >> 8) & 0xff, blockIndex & 0xff]).bytes;
      var u = first;
      final t = List<int>.from(first);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.addAll(t);
      blockIndex++;
    }
    return base64UrlEncode(output.take(derivedKeyLength).toList());
  }

  static bool verify(String password, String salt, String expectedHash) {
    final actual = hash(password, salt);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
