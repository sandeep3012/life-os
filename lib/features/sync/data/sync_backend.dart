import 'dart:convert';
import 'dart:typed_data';

/// One encrypted record as the server holds it. [payload] is ciphertext;
/// the server never sees what table it belongs to or what it says.
class RemoteRecord {
  const RemoteRecord({
    required this.id,
    required this.hlc,
    required this.deviceId,
    required this.deleted,
    required this.payload,
    required this.schemaVer,
    this.seq = 0,
  });

  final String id;
  final String hlc;
  final String deviceId;
  final bool deleted;
  final Uint8List payload;
  final int schemaVer;

  /// Server-assigned and only ever increasing: the pull cursor.
  final int seq;

  Map<String, Object?> toJson() => {
    'id': id,
    'hlc': hlc,
    'device_id': deviceId,
    'deleted': deleted,
    'payload': base64Encode(payload),
    'schema_ver': schemaVer,
  };

  factory RemoteRecord.fromJson(Map<String, dynamic> json) => RemoteRecord(
    id: json['id'] as String,
    hlc: json['hlc'] as String,
    deviceId: json['device_id'] as String,
    deleted: json['deleted'] as bool,
    // Postgres' base64 wraps lines every 76 characters.
    payload: base64Decode(
      (json['payload'] as String).replaceAll(RegExp(r'\s'), ''),
    ),
    schemaVer: (json['schema_ver'] as num).toInt(),
    seq: (json['seq'] as num?)?.toInt() ?? 0,
  );
}

class PushResult {
  const PushResult({required this.accepted, required this.conflicts});

  final Set<String> accepted;

  /// Records the server kept because its copy was newer — applied locally
  /// exactly like pulled ones.
  final List<RemoteRecord> conflicts;
}

/// The data key, sealed with the recovery key, as stored on the server.
class WrappedKey {
  const WrappedKey(this.wrapped);
  final Uint8List wrapped;
}

/// The account has no active sync subscription, so uploads are refused.
/// Downloads still work, so a lapsed subscriber can restore.
class SyncNotEntitledException implements Exception {
  const SyncNotEntitledException();
}

/// Everything the sync engine needs from the server, so tests can run two
/// "phones" against an in-memory one.
abstract class SyncBackend {
  Future<bool> hasSyncAccess();

  Future<WrappedKey?> fetchWrappedKey();

  /// Fails if a key is already stored, unless [replace].
  Future<void> storeWrappedKey(WrappedKey key, {bool replace = false});

  Future<PushResult> push(List<RemoteRecord> records);

  /// Records with a seq after [afterSeq], oldest first.
  Future<List<RemoteRecord>> pull(int afterSeq, {int limit = 500});

  Future<void> registerDevice(String deviceId, String name);

  /// Removes the account and everything stored for it on the server.
  Future<void> deleteAccount();
}
