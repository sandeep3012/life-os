import 'dart:async';
import 'dart:typed_data';

import 'package:life_manager/features/sync/data/sync_backend.dart';
import 'package:life_manager/features/sync/data/sync_session.dart';

/// The server's rules from `supabase/migrations/*_sync.sql`, in memory: one
/// shared instance plays the server for several "phones".
class FakeSyncServer {
  final records = <String, RemoteRecord>{};
  WrappedKey? wrappedKey;
  bool entitled = true;
  bool offline = false;
  int _seq = 0;

  FakeSyncBackend client() => FakeSyncBackend(this);
}

class FakeSyncBackend implements SyncBackend {
  FakeSyncBackend(this.server);

  final FakeSyncServer server;
  final devices = <String, String>{};
  bool deleted = false;

  void _online() {
    if (server.offline) throw StateError('offline');
  }

  @override
  Future<bool> hasSyncAccess() async => server.entitled;

  @override
  Future<WrappedKey?> fetchWrappedKey() async {
    _online();
    return server.wrappedKey;
  }

  @override
  Future<void> storeWrappedKey(WrappedKey key, {bool replace = false}) async {
    _online();
    if (server.wrappedKey != null && !replace) {
      throw StateError('duplicate key');
    }
    server.wrappedKey = key;
  }

  @override
  Future<PushResult> push(List<RemoteRecord> records) async {
    _online();
    if (!server.entitled) throw const SyncNotEntitledException();
    final accepted = <String>{};
    final conflicts = <RemoteRecord>[];
    for (final r in records) {
      final existing = server.records[r.id];
      if (existing != null && existing.hlc.compareTo(r.hlc) > 0) {
        conflicts.add(existing);
        continue;
      }
      server.records[r.id] = RemoteRecord(
        id: r.id,
        hlc: r.hlc,
        deviceId: r.deviceId,
        deleted: r.deleted,
        payload: r.payload,
        schemaVer: r.schemaVer,
        seq: ++server._seq,
      );
      accepted.add(r.id);
    }
    return PushResult(accepted: accepted, conflicts: conflicts);
  }

  @override
  Future<List<RemoteRecord>> pull(int afterSeq, {int limit = 500}) async {
    _online();
    final newer = server.records.values.where((r) => r.seq > afterSeq).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return newer.take(limit).toList();
  }

  @override
  Future<void> registerDevice(String deviceId, String name) async {
    devices[deviceId] = name;
  }

  @override
  Future<void> deleteAccount() async {
    server.records.clear();
    server.wrappedKey = null;
    deleted = true;
  }
}

extension RemoteRecordCopy on RemoteRecord {
  static RemoteRecord withPayload(RemoteRecord r, List<int> payload) =>
      RemoteRecord(
        id: r.id,
        hlc: r.hlc,
        deviceId: r.deviceId,
        deleted: r.deleted,
        payload: Uint8List.fromList(payload),
        schemaVer: r.schemaVer,
        seq: r.seq,
      );
}

class FakeSession implements SyncSession {
  final _changes = StreamController<String?>.broadcast();
  final _recovery = StreamController<void>.broadcast();

  @override
  String? userId;

  @override
  String? get email => userId == null ? null : '$userId@example.com';

  void signIn(String id) {
    userId = id;
    _changes.add(id);
  }

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  @override
  Stream<void> get passwordRecovery => _recovery.stream;

  @override
  Future<void> signOut() async {
    userId = null;
    _changes.add(null);
  }
}

class MemoryKeyStore implements SyncKeyStore {
  final keys = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String userId) async => keys[userId];

  @override
  Future<void> write(String userId, Uint8List key) async => keys[userId] = key;

  @override
  Future<void> delete(String userId) async => keys.remove(userId);
}
