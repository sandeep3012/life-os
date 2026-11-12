import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/sync/domain/hlc.dart';
import 'package:life_manager/features/sync/domain/sync_crypto.dart';

void main() {
  final crypto = SyncCrypto();

  test('a recovery key reads back however it is typed', () {
    final key = crypto.newRecoveryKey();
    expect(key, matches(RegExp(r'^LOS(-[0-9A-Z]{4}){6}-[0-9A-Z]{2}$')));
    final bytes = SyncCrypto.parseRecoveryKey(key);
    expect(bytes, hasLength(16));
    final sloppy = key.toLowerCase().replaceAll('-', ' ').replaceAll('0', 'o');
    expect(SyncCrypto.parseRecoveryKey(sloppy), bytes);
    expect(SyncCrypto.formatRecoveryKey(bytes), key);
    expect(
      () => SyncCrypto.parseRecoveryKey('LOS-1234'),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('the data key opens only with its recovery key and user', () async {
    final dataKey = crypto.newDataKey();
    final recovery = crypto.newRecoveryKey();
    final wrapped = await crypto.wrapDataKey(dataKey, recovery, 'user-1');
    expect(await crypto.unwrapDataKey(wrapped, recovery, 'user-1'), dataKey);
    await expectLater(
      crypto.unwrapDataKey(wrapped, crypto.newRecoveryKey(), 'user-1'),
      throwsA(isA<SyncCryptoException>()),
    );
    await expectLater(
      crypto.unwrapDataKey(wrapped, recovery, 'user-2'),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('a record is sealed to its id and fails if altered', () async {
    final key = crypto.newDataKey();
    final plain = utf8.encode('{"merchant":"Corner café"}');
    final sealed = await crypto.encryptRecord(key, 'rec-1', plain);
    expect(utf8.decode(sealed, allowMalformed: true), isNot(contains('café')));
    expect(await crypto.decryptRecord(key, 'rec-1', sealed), plain);

    // Moved to another record's id.
    await expectLater(
      crypto.decryptRecord(key, 'rec-2', sealed),
      throwsA(isA<SyncCryptoException>()),
    );
    // A flipped byte.
    final tampered = [...sealed]..[30] ^= 1;
    await expectLater(
      crypto.decryptRecord(key, 'rec-1', tampered),
      throwsA(isA<SyncCryptoException>()),
    );
  });

  test('clock stamps never go backwards and compare as text', () {
    const device = '11111111-2222-3333-4444-555555555555';
    final first = Hlc.next(null, 1000, device);
    final sameMillis = Hlc.next(first, 1000, device);
    final clockBehind = Hlc.next(sameMillis, 900, device);
    final later = Hlc.next(clockBehind, 2000, device);
    expect([first, sameMillis, clockBehind, later].map((h) => '$h').toList(), [
      for (final h in [first, sameMillis, clockBehind, later]) '$h',
    ]..sort());
    expect(clockBehind.millis, 1000);
    expect(Hlc.parse('$clockBehind'), clockBehind);
    expect('${Hlc.seed(device)}'.compareTo('$first'), lessThan(0));
  });

  group('approve from another phone', () {
    const id = '0b6a3f4e-2c1d-4e5f-8a9b-0c1d2e3f4a5b';

    test('the joining phone opens what the other phone sealed', () async {
      final request = await crypto.newLinkRequest(id);
      final scanned = LinkRequest.parse(request.code);
      expect(scanned.id, id);
      expect(scanned.publicKey, request.publicKey);

      final dataKey = crypto.newDataKey();
      final sealed = await crypto.sealForLink(
        dataKey,
        scanned.publicKey,
        'user-1',
        scanned.id,
      );
      expect(await crypto.openLink(request, sealed, 'user-1'), dataKey);
    });

    test('it is bound to the account and to this request', () async {
      final request = await crypto.newLinkRequest(id);
      final sealed = await crypto.sealForLink(
        crypto.newDataKey(),
        request.publicKey,
        'user-1',
        id,
      );
      await expectLater(
        crypto.openLink(request, sealed, 'user-2'),
        throwsA(isA<SyncCryptoException>()),
      );
      final other = await crypto.newLinkRequest(id);
      await expectLater(
        crypto.openLink(other, sealed, 'user-1'),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('codes that are not LifeOS ones are refused', () {
      for (final code in [
        'https://example.com',
        'lifeos-link:1:not-an-id:AAAA',
        'lifeos-link:1:$id:AAAA',
        'lifeos-link:2:$id:${'A' * 43}',
      ]) {
        expect(
          () => LinkRequest.parse(code),
          throwsA(isA<SyncCryptoException>()),
          reason: code,
        );
      }
    });
  });
}
