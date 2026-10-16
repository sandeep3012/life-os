import 'package:drift/drift.dart';

/// Rows changed locally and not yet uploaded — one per row, however many
/// times it changed. Written by SQLite triggers (installed only while sync
/// is on, see `LocalSyncStore`), so no code path can forget to sync.
class SyncOutbox extends Table {
  @override
  String get tableName => 'sync_outbox';

  /// The synced table the row lives in.
  TextColumn get entity => text().named('table_name')();

  /// The row's primary key: the id itself, or a JSON array of the values
  /// for a composite key.
  TextColumn get rowKey => text()();

  /// upsert | delete | seed. A seed is a row queued when sync was switched
  /// on rather than an edit, so it loses to any real edit made elsewhere.
  TextColumn get op => text()();

  /// Wall-clock milliseconds of the change.
  IntColumn get changedAt => integer()();

  @override
  Set<Column> get primaryKey => {entity, rowKey};
}

/// Small key/value state for sync: the pull cursor, this device's id, the
/// clock, and the `applying_remote` flag the triggers read.
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Records written by a newer app version than this one, kept untouched
/// until an update can read them rather than half-applied.
class SyncHeld extends Table {
  @override
  String get tableName => 'sync_held';

  TextColumn get recordId => text()();
  IntColumn get schemaVer => integer()();

  /// The decrypted record, as JSON.
  TextColumn get record => text()();

  @override
  Set<Column> get primaryKey => {recordId};
}
