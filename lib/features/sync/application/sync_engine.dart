import 'dart:convert';

import '../data/local_sync_store.dart';
import '../data/sync_backend.dart';
import '../domain/hlc.dart';
import '../domain/sync_crypto.dart';

/// What one round of sync did.
class SyncRoundResult {
  const SyncRoundResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.skipped = 0,
    this.uploadsRefused = false,
  });

  final int uploaded;
  final int downloaded;

  /// Records that couldn't be read — damaged or tampered with. Logged and
  /// passed over; one bad record never blocks the rest.
  final int skipped;

  /// The account has no active subscription: nothing went up, but
  /// downloads still ran.
  final bool uploadsRefused;
}

/// One round of sync between this phone's database and the server: upload
/// what changed here, download what changed elsewhere.
///
/// Every step is safe to retry. A failed upload leaves the outbox as it was;
/// a failed download leaves the cursor where it was.
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.backend,
    required this.crypto,
    required this.dataKey,
    required this.deviceId,
    required this.schemaVersion,
  });

  final LocalSyncStore store;
  final SyncBackend backend;
  final SyncCrypto crypto;
  final List<int> dataKey;
  final String deviceId;
  final int schemaVersion;

  static const pushBatch = 200;
  static const pullBatch = 500;

  Future<SyncRoundResult> run() async {
    var skipped = 0;

    // Anything held from a newer version that this one can now read.
    final released = await store.releaseHeld(schemaVersion);
    if (released.isNotEmpty) {
      await store.applyIncoming([
        for (final json in released) _changeFrom(jsonDecode(json) as Map),
      ]);
    }

    await store.reconcileOpeningBalances();

    var uploaded = 0;
    var refused = false;
    try {
      while (true) {
        final entries = await store.readOutbox(limit: pushBatch);
        if (entries.isEmpty) break;
        final result = await _push(entries);
        uploaded += result.accepted;
        skipped += result.skipped;
        if (entries.length < pushBatch) break;
      }
    } on SyncNotEntitledException {
      refused = true;
    }

    var downloaded = 0;
    var cursor = int.tryParse(await store.readState('cursor') ?? '') ?? 0;
    while (true) {
      final records = await backend.pull(cursor, limit: pullBatch);
      if (records.isEmpty) break;
      final applied = await _applyRemote(records);
      downloaded += applied.applied;
      skipped += applied.skipped;
      for (final r in records) {
        if (r.seq > cursor) cursor = r.seq;
      }
      await store.writeState('cursor', '$cursor');
      if (records.length < pullBatch) break;
    }

    await store.mergeDuplicateDefaults();
    await store.writeState(
      'last_synced',
      DateTime.now().toUtc().toIso8601String(),
    );
    return SyncRoundResult(
      uploaded: uploaded,
      downloaded: downloaded,
      skipped: skipped,
      uploadsRefused: refused,
    );
  }

  Future<({int accepted, int skipped})> _push(List<OutboxEntry> entries) async {
    var latest = _parseHlc(await store.readState('hlc'));
    final records = <RemoteRecord>[];
    final byId = <String, OutboxEntry>{};
    for (final entry in entries) {
      final id = LocalSyncStore.recordId(entry.table, entry.key);
      final Hlc stamp;
      if (entry.isSeed) {
        stamp = Hlc.seed(deviceId);
      } else {
        stamp = Hlc.next(latest, entry.changedAt, deviceId);
        latest = stamp;
      }
      final plain = utf8.encode(
        jsonEncode({'t': entry.table, 'k': entry.key, 'r': entry.row}),
      );
      records.add(
        RemoteRecord(
          id: id,
          hlc: '$stamp',
          deviceId: deviceId,
          deleted: entry.isDelete,
          payload: await crypto.encryptRecord(dataKey, id, plain),
          schemaVer: schemaVersion,
        ),
      );
      byId[id] = entry;
    }
    if (latest != null) await store.writeState('hlc', '$latest');

    final result = await backend.push(records);
    final settled = {...result.accepted, for (final c in result.conflicts) c.id};
    await store.markUploaded([
      for (final id in settled)
        if (byId[id] != null) byId[id]!,
    ]);
    // Where the server's copy was newer, it wins here too.
    final applied = await _applyRemote(result.conflicts, fromConflict: true);
    return (accepted: result.accepted.length, skipped: applied.skipped);
  }

  Future<({int applied, int skipped})> _applyRemote(
    List<RemoteRecord> records, {
    bool fromConflict = false,
  }) async {
    var latest = _parseHlc(await store.readState('hlc'));
    final changes = <IncomingChange>[];
    var skipped = 0;
    for (final record in records) {
      // This phone's own uploads coming back: already applied here.
      if (record.deviceId == deviceId && !fromConflict) continue;
      final Map<dynamic, dynamic> decoded;
      try {
        decoded = jsonDecode(
          utf8.decode(
            await crypto.decryptRecord(dataKey, record.id, record.payload),
          ),
        ) as Map;
      } on Object {
        skipped++;
        continue;
      }
      final table = decoded['t'] as String?;
      final key = decoded['k'] as String?;
      // The id must be the one this content claims to be.
      if (table == null ||
          key == null ||
          LocalSyncStore.recordId(table, key) != record.id) {
        skipped++;
        continue;
      }
      if (record.schemaVer > schemaVersion) {
        await store.hold(record.id, record.schemaVer, jsonEncode(decoded));
        continue;
      }
      final stamp = _parseHlc(record.hlc);
      if (stamp != null && stamp.millis > 0) {
        latest = Hlc.latestOf(latest, stamp);
      }
      if (!store.isSynced(table)) continue;

      // A newer edit made here and not uploaded yet wins over this one.
      final pending = await store.pendingFor(table, key);
      if (pending != null &&
          !pending.isSeed &&
          !fromConflict &&
          stamp != null &&
          pending.changedAt > stamp.millis) {
        continue;
      }
      if (pending != null) await store.markUploaded([pending]);
      changes.add(_changeFrom(decoded, deleted: record.deleted));
    }
    await store.applyIncoming(changes);
    if (latest != null) await store.writeState('hlc', '$latest');
    return (applied: changes.length, skipped: skipped);
  }

  IncomingChange _changeFrom(Map<dynamic, dynamic> decoded, {bool? deleted}) {
    final row = decoded['r'];
    return IncomingChange(
      table: decoded['t'] as String,
      key: decoded['k'] as String,
      row: deleted == true || row == null
          ? null
          : (row as Map).cast<String, Object?>(),
    );
  }

  static Hlc? _parseHlc(String? value) {
    if (value == null) return null;
    try {
      return Hlc.parse(value);
    } on FormatException {
      return null;
    }
  }
}
