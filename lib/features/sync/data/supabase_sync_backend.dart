import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_backend.dart';

/// [SyncBackend] over the functions in `supabase/migrations/*_sync.sql`.
class SupabaseSyncBackend implements SyncBackend {
  SupabaseSyncBackend(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  @override
  Future<bool> hasSyncAccess() async =>
      (await _client.rpc<dynamic>('my_sync_access')) == true;

  @override
  Future<WrappedKey?> fetchWrappedKey() async {
    final row = await _client
        .from('user_keys')
        .select('wrapped_recovery')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    return WrappedKey(base64Decode(row['wrapped_recovery'] as String));
  }

  @override
  Future<void> storeWrappedKey(WrappedKey key, {bool replace = false}) async {
    final row = {
      'user_id': _userId,
      'wrapped_recovery': base64Encode(key.wrapped),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (replace) {
      await _client.from('user_keys').upsert(row);
    } else {
      // Fails on a key that's already there, rather than replacing the one
      // another phone's data is sealed with.
      await _client.from('user_keys').insert(row);
    }
  }

  @override
  Future<PushResult> push(List<RemoteRecord> records) async {
    try {
      final result = await _client.rpc<dynamic>(
        'push_records',
        params: {'batch': [for (final r in records) r.toJson()]},
      );
      final map = (result as Map).cast<String, dynamic>();
      return PushResult(
        accepted: {for (final id in map['accepted'] as List) id as String},
        conflicts: [
          for (final c in map['conflicts'] as List)
            RemoteRecord.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('not_entitled')) {
        throw const SyncNotEntitledException();
      }
      rethrow;
    }
  }

  @override
  Future<List<RemoteRecord>> pull(int afterSeq, {int limit = 500}) async {
    final rows = await _client.rpc<dynamic>(
      'pull_records',
      params: {'after_seq': afterSeq, 'max_rows': limit},
    );
    return [
      for (final row in rows as List)
        RemoteRecord.fromJson((row as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<void> registerDevice(String deviceId, String name) => _client
      .from('devices')
      .upsert({
        'id': deviceId,
        'user_id': _userId,
        'name': name,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<dynamic>('delete_my_account');
    await _client.auth.signOut();
  }
}
