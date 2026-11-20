import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/plan.dart';

/// What the server says about the signed-in account's plan. The server is
/// the judge for anything that costs money; the app only asks.
abstract class PlanBackend {
  /// Whether the account has PersonalOS Plus right now.
  Future<bool> hasPlus();

  /// The account's voice allowance, or null if it couldn't be read.
  Future<VoiceAllowance?> voiceAllowance();
}

class SupabasePlanBackend implements PlanBackend {
  SupabasePlanBackend(this._client);

  final SupabaseClient _client;

  // Plus is an active row in `entitlements` — the same test sync's uploads
  // use, hence the function's name.
  @override
  Future<bool> hasPlus() async =>
      (await _client.rpc<dynamic>('my_sync_access')) == true;

  @override
  Future<VoiceAllowance?> voiceAllowance() async =>
      VoiceAllowance.fromJson(await _client.rpc<dynamic>('my_voice_allowance'));
}

/// The last answer the server gave for an account, kept on the phone so the
/// extra themes and fonts don't vanish every time it's offline.
class CachedPlan {
  const CachedPlan({required this.plus, required this.checkedAt});

  final bool plus;
  final DateTime checkedAt;
}

abstract class PlanCache {
  Future<CachedPlan?> read(String userId);
  Future<void> write(String userId, CachedPlan plan);
  Future<void> clear(String userId);
}

/// In the phone's secure storage, by account: not in the database, so it
/// isn't carried into a backup or onto another phone.
class SecurePlanCache implements PlanCache {
  SecurePlanCache([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'plan_$userId';

  @override
  Future<CachedPlan?> read(String userId) async {
    try {
      final value = await _storage.read(key: _key(userId));
      final parts = value?.split('|');
      if (parts == null || parts.length != 2) return null;
      final at = DateTime.tryParse(parts[1]);
      if (at == null) return null;
      return CachedPlan(plus: parts[0] == 'plus', checkedAt: at);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String userId, CachedPlan plan) async {
    try {
      await _storage.write(
        key: _key(userId),
        value:
            '${plan.plus ? 'plus' : 'free'}|'
            '${plan.checkedAt.toUtc().toIso8601String()}',
      );
    } on Object {
      // Only a convenience; the next launch asks the server again.
    }
  }

  @override
  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } on Object {
      // Nothing to clear.
    }
  }
}
