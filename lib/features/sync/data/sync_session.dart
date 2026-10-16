import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who's signed in for sync, as the sync controller needs to know it.
abstract class SyncSession {
  String? get userId;
  String? get email;

  /// The signed-in user's id on every change; null after signing out.
  Stream<String?> get userIdChanges;

  /// Fires when a password-reset link has been opened and a new password
  /// should be chosen.
  Stream<void> get passwordRecovery;

  Future<void> signOut();
}

class SupabaseSyncSession implements SyncSession {
  SupabaseSyncSession(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  String? get email => _client.auth.currentUser?.email;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();

  @override
  Stream<void> get passwordRecovery => _client.auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> signOut() => _client.auth.signOut();
}

/// Where each account's data key is kept on this phone.
abstract class SyncKeyStore {
  Future<Uint8List?> read(String userId);
  Future<void> write(String userId, Uint8List key);
  Future<void> delete(String userId);
}

/// The phone's keychain / keystore: the data key never sits in the
/// database, in backups, or anywhere the app's files are copied.
class SecureSyncKeyStore implements SyncKeyStore {
  SecureSyncKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _name(String userId) => 'sync_data_key_$userId';

  @override
  Future<Uint8List?> read(String userId) async {
    final value = await _storage.read(key: _name(userId));
    if (value == null) return null;
    return Uint8List.fromList(
      [for (var i = 0; i < value.length; i += 2) int.parse(value.substring(i, i + 2), radix: 16)],
    );
  }

  @override
  Future<void> write(String userId, Uint8List key) => _storage.write(
    key: _name(userId),
    value: key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  );

  @override
  Future<void> delete(String userId) => _storage.delete(key: _name(userId));
}
