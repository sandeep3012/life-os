import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A copy of each account's data key in the phone platform's own secure
/// backup, so a reinstall or a new phone signed in to the same Apple or
/// Google account unlocks sync without the recovery key.
///
/// Both platforms keep it end-to-end encrypted — Apple and Google can't read
/// it either — so LifeOS's promise that nobody but you can read your data
/// still holds. The recovery key remains the way back when this isn't there.
abstract class SyncKeyBackup {
  /// Where the copy lives, as the person would know it — or null when this
  /// phone can't keep one.
  String? get label;

  Future<Uint8List?> read(String userId);

  /// Saves [key]; true when the copy is off this phone (so a new phone can
  /// get it), false when the platform kept it on this phone only.
  Future<bool> write(String userId, Uint8List key);
  Future<void> delete(String userId);

  /// The platform's backup for this phone: iCloud Keychain on iOS, Google's
  /// Block Store on Android, nothing elsewhere.
  factory SyncKeyBackup.forPlatform() {
    if (kIsWeb) return const NoSyncKeyBackup();
    if (Platform.isIOS) return ICloudKeychainBackup();
    if (Platform.isAndroid) return BlockStoreBackup();
    return const NoSyncKeyBackup();
  }
}

String _name(String userId) => 'sync_data_key_backup_$userId';

class NoSyncKeyBackup implements SyncKeyBackup {
  const NoSyncKeyBackup();

  @override
  String? get label => null;

  @override
  Future<Uint8List?> read(String userId) async => null;

  @override
  Future<bool> write(String userId, Uint8List key) async => false;

  @override
  Future<void> delete(String userId) async {}
}

/// A synchronizable keychain item: it outlives the app being deleted and
/// reaches every device signed in to the same Apple account with iCloud
/// Keychain on.
class ICloudKeychainBackup implements SyncKeyBackup {
  ICloudKeychainBackup([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // After first unlock, so a background sync can still read it; the
  // synchronizable flag is what puts it in iCloud Keychain.
  static const _options = IOSOptions(
    synchronizable: true,
    accessibility: KeychainAccessibility.first_unlock,
  );

  @override
  String get label => 'iCloud Keychain';

  @override
  Future<Uint8List?> read(String userId) async {
    final value = await _storage.read(key: _name(userId), iOptions: _options);
    return value == null ? null : base64Decode(value);
  }

  @override
  Future<bool> write(String userId, Uint8List key) async {
    await _storage.write(
      key: _name(userId),
      value: base64Encode(key),
      iOptions: _options,
    );
    // iOS doesn't say whether iCloud Keychain is on; when it's off the item
    // simply stays on this phone.
    return true;
  }

  @override
  Future<void> delete(String userId) =>
      _storage.delete(key: _name(userId), iOptions: _options);
}

/// Google's Block Store, through `MainActivity`'s `keyBackup` channel. It
/// survives the app being reinstalled, and is restored onto a new phone set
/// up from this one's Google backup. It's only sent to Google's cloud when
/// the phone has a screen lock, which is what makes that copy end-to-end
/// encrypted; without one it stays on this phone.
class BlockStoreBackup implements SyncKeyBackup {
  BlockStoreBackup([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('com.sandeep.lifeos/keyBackup');

  final MethodChannel _channel;

  @override
  String get label => 'your Google account';

  @override
  Future<Uint8List?> read(String userId) =>
      _channel.invokeMethod<Uint8List>('read', {'key': _name(userId)});

  @override
  Future<bool> write(String userId, Uint8List key) async =>
      await _channel.invokeMethod<bool>('write', {
        'key': _name(userId),
        'value': key,
      }) ??
      false;

  @override
  Future<void> delete(String userId) =>
      _channel.invokeMethod<void>('delete', {'key': _name(userId)});
}
