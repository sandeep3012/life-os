import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The recovery key couldn't open the stored data key, or a record failed
/// its integrity check.
class SyncCryptoException implements Exception {
  const SyncCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All of sync's encryption, in one place: records and the data key are
/// sealed with XChaCha20-Poly1305 (authenticated, random 24-byte nonce), and
/// the recovery key is stretched into a wrapping key with HKDF-SHA256. No
/// hand-written primitives — everything is the `cryptography` package's.
class SyncCrypto {
  SyncCrypto({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final _aead = Xchacha20.poly1305Aead();

  static const keyLength = 32;
  static const _recoveryBytes = 16;
  static const _dataKeyAad = 'lifeos data key v1';

  /// A fresh random data key: what every record is encrypted with.
  Uint8List newDataKey() => _randomBytes(keyLength);

  /// A fresh recovery key, for the person to keep: 128 random bits.
  String newRecoveryKey() => formatRecoveryKey(_randomBytes(_recoveryBytes));

  /// Seals one record. [recordId] is bound in as associated data, so the
  /// server can't move one record's content into another.
  Future<Uint8List> encryptRecord(
    List<int> dataKey,
    String recordId,
    List<int> plain,
  ) => _seal(dataKey, plain, utf8.encode(recordId));

  Future<Uint8List> decryptRecord(
    List<int> dataKey,
    String recordId,
    List<int> sealed,
  ) => _open(dataKey, sealed, utf8.encode(recordId));

  /// The data key sealed with a key derived from [recoveryKey] — what the
  /// server keeps, so a new phone can recover it.
  Future<Uint8List> wrapDataKey(
    List<int> dataKey,
    String recoveryKey,
    String userId,
  ) async => _seal(
    await _wrappingKey(recoveryKey, userId),
    dataKey,
    utf8.encode(_dataKeyAad),
  );

  Future<Uint8List> unwrapDataKey(
    List<int> wrapped,
    String recoveryKey,
    String userId,
  ) async {
    try {
      return await _open(
        await _wrappingKey(recoveryKey, userId),
        wrapped,
        utf8.encode(_dataKeyAad),
      );
    } on SyncCryptoException {
      throw const SyncCryptoException(
        "That recovery key doesn't match this account.",
      );
    }
  }

  Future<List<int>> _wrappingKey(String recoveryKey, String userId) async {
    final bytes = parseRecoveryKey(recoveryKey);
    final key = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: keyLength,
    ).deriveKey(
      secretKey: SecretKey(bytes),
      nonce: utf8.encode(userId),
      info: utf8.encode('lifeos recovery wrap v1'),
    );
    return key.extractBytes();
  }

  Future<Uint8List> _seal(List<int> key, List<int> plain, List<int> aad) async {
    final box = await _aead.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: _randomBytes(_aead.nonceLength),
      aad: aad,
    );
    return Uint8List.fromList(box.concatenation());
  }

  Future<Uint8List> _open(List<int> key, List<int> sealed, List<int> aad) async {
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: _aead.nonceLength,
        macLength: _aead.macAlgorithm.macLength,
      );
      return Uint8List.fromList(
        await _aead.decrypt(box, secretKey: SecretKey(key), aad: aad),
      );
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException('A record failed its integrity check.');
    } on ArgumentError {
      throw const SyncCryptoException('A record is damaged.');
    }
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList([for (var i = 0; i < length; i++) _random.nextInt(256)]);

  /// Crockford base32: no I, L, O or U, so it survives being read aloud or
  /// copied by hand.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// `LOS-XXXX-XXXX-…`: 26 base32 characters in groups of four.
  static String formatRecoveryKey(List<int> bytes) {
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(_alphabet[(value << (5 - bits)) & 31]);
    final chars = out.toString();
    final groups = [
      for (var i = 0; i < chars.length; i += 4)
        chars.substring(i, min(i + 4, chars.length)),
    ];
    return 'LOS-${groups.join('-')}';
  }

  /// Reads a recovery key back, forgiving case, spacing, dashes and the
  /// look-alike letters people mistype (O for 0, I or L for 1).
  static Uint8List parseRecoveryKey(String input) {
    var text = input.toUpperCase().replaceAll(RegExp('[^0-9A-Z]'), '');
    if (text.startsWith('LOS')) text = text.substring(3);
    text = text.replaceAll('O', '0').replaceAll(RegExp('[IL]'), '1');
    if (text.length != 26 || text.split('').any((c) => !_alphabet.contains(c))) {
      throw const SyncCryptoException(
        'A recovery key has 26 letters and numbers after "LOS".',
      );
    }
    var bits = 0, value = 0;
    final out = <int>[];
    for (final char in text.split('')) {
      value = ((value << 5) | _alphabet.indexOf(char)) & 0xFFFF;
      bits += 5;
      if (bits >= 8) {
        out.add((value >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }
    return Uint8List.fromList(out.take(_recoveryBytes).toList());
  }
}
