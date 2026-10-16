import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

/// A local change waiting to go up. [row] is the row as it is now, or null
/// when it's been deleted.
class OutboxEntry {
  const OutboxEntry({
    required this.table,
    required this.key,
    required this.op,
    required this.changedAt,
    this.row,
  });

  final String table;
  final String key;

  /// upsert | delete | seed — see `SyncOutbox.op`.
  final String op;
  final int changedAt;
  final Map<String, Object?>? row;

  bool get isSeed => op == 'seed';
  bool get isDelete => row == null;
}

/// A change to make here because another phone made it. [row] null deletes.
class IncomingChange {
  const IncomingChange({required this.table, required this.key, this.row});

  final String table;
  final String key;
  final Map<String, Object?>? row;
}

/// Sync's side of the local database: which tables sync, the triggers that
/// record every change to them, and applying other phones' changes without
/// those triggers echoing them straight back up.
class LocalSyncStore {
  LocalSyncStore(this._db);

  final AppDatabase _db;

  /// Not synced: insights are recomputed on every phone, settings mostly
  /// belong to the device (app lock, motion, tours), and sync's own tables.
  static const _localOnly = {
    'insights',
    'app_settings',
    'sync_outbox',
    'sync_state',
    'sync_held',
  };

  /// Columns that change as a side effect of a transaction rather than an
  /// edit to the account. They're recomputed on every phone after a
  /// download, so writing them doesn't queue the account for upload — which
  /// would otherwise let one phone's running total overwrite another's.
  static const _derivedColumns = {
    'accounts': {'balance_minor', 'updated_at'},
  };

  static const _demoPrefix = 'demo-';
  static const _recordNamespace = '3c9a51f2-7e44-4b8e-a6d1-5f0e2b8c9d17';

  /// Every table that syncs, in schema order.
  late final List<TableInfo<Table, dynamic>> tables = [
    for (final table in _db.allTables)
      if (!_localOnly.contains(table.actualTableName)) table,
  ];

  late final Map<String, TableInfo<Table, dynamic>> _byName = {
    for (final table in tables) table.actualTableName: table,
  };

  bool isSynced(String table) => _byName.containsKey(table);

  /// The server's id for a row: derived from its table and key, so it's the
  /// same on every phone, and says nothing about either.
  static String recordId(String table, String key) =>
      const Uuid().v5(_recordNamespace, '$table:$key');

  List<String> _keyColumns(TableInfo<Table, dynamic> table) {
    final keys = table.$primaryKey.map((c) => c.name).toSet();
    return [
      for (final column in table.$columns)
        if (keys.contains(column.name)) column.name,
    ];
  }

  /// The SQL for a row's key, matching what [_keyValues] reads back: the
  /// value itself, or a JSON array of them for a composite key.
  String _keySql(TableInfo<Table, dynamic> table, String alias) {
    final columns = _keyColumns(table);
    if (columns.length == 1) return '$alias."${columns.single}"';
    return 'json_array(${columns.map((c) => '$alias."$c"').join(', ')})';
  }

  List<Object?> _keyValues(TableInfo<Table, dynamic> table, String key) {
    final columns = _keyColumns(table);
    if (columns.length == 1) return [key];
    return (jsonDecode(key) as List).cast<Object?>();
  }

  String _keyWhere(TableInfo<Table, dynamic> table) =>
      _keyColumns(table).map((c) => '"$c" = ?').join(' AND ');

  /// Sample data stays on the phone it was loaded on.
  String _notDemo(TableInfo<Table, dynamic> table, String alias) =>
      "$alias.\"${_keyColumns(table).first}\" NOT LIKE '$_demoPrefix%'";

  static const _notApplyingRemote =
      "(SELECT value FROM sync_state WHERE key = 'applying_remote') IS NOT '1'";

  // ---- State ---------------------------------------------------------------

  Future<String?> readState(String key) async {
    final row = await (_db.select(
      _db.syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeState(String key, String? value) async {
    if (value == null) {
      await (_db.delete(_db.syncState)..where((s) => s.key.equals(key))).go();
      return;
    }
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(key: key, value: value),
        );
  }

  /// This phone's id for sync, made once and kept through sign-outs.
  Future<String> deviceId() async {
    final existing = await readState('device_id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await writeState('device_id', id);
    return id;
  }

  // ---- Triggers ------------------------------------------------------------

  String _triggerName(String table, String kind) => 'sync_${table}_$kind';

  /// Starts recording every change to a synced table in the outbox.
  /// Re-runnable: replaces any triggers already there.
  Future<void> installTriggers() => _db.transaction(() async {
    for (final table in tables) {
      final name = table.actualTableName;
      await _dropTriggers(name);
      // Milliseconds; julianday rather than unixepoch('subsec'), which
      // needs a newer SQLite than some phones' system library.
      const now = "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";
      String record(String alias, String op) =>
          'INSERT OR REPLACE INTO sync_outbox (table_name, row_key, op, changed_at) '
          "VALUES ('$name', ${_keySql(table, alias)}, '$op', $now);";

      final derived = _derivedColumns[name] ?? const <String>{};
      final watched = derived.isEmpty
          ? ''
          : ' OF ${[
              for (final c in table.$columns)
                if (!derived.contains(c.name)) '"${c.name}"',
            ].join(', ')}';

      await _db.customStatement(
        'CREATE TRIGGER ${_triggerName(name, 'ins')} AFTER INSERT ON "$name" '
        'WHEN $_notApplyingRemote AND ${_notDemo(table, 'NEW')} '
        'BEGIN ${record('NEW', 'upsert')} END',
      );
      await _db.customStatement(
        'CREATE TRIGGER ${_triggerName(name, 'upd')} AFTER UPDATE$watched ON "$name" '
        'WHEN $_notApplyingRemote AND ${_notDemo(table, 'NEW')} '
        'BEGIN ${record('NEW', 'upsert')} END',
      );
      await _db.customStatement(
        'CREATE TRIGGER ${_triggerName(name, 'del')} AFTER DELETE ON "$name" '
        'WHEN $_notApplyingRemote AND ${_notDemo(table, 'OLD')} '
        'BEGIN ${record('OLD', 'delete')} END',
      );
    }
  });

  Future<void> removeTriggers() => _db.transaction(() async {
    for (final table in tables) {
      await _dropTriggers(table.actualTableName);
    }
  });

  Future<void> _dropTriggers(String name) async {
    for (final kind in ['ins', 'upd', 'del']) {
      await _db.customStatement(
        'DROP TRIGGER IF EXISTS ${_triggerName(name, kind)}',
      );
    }
  }

  Future<bool> triggersInstalled() async {
    final rows = await _db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'sync\\_%' ESCAPE '\\'",
        )
        .getSingle();
    return rows.read<int>('n') == tables.length * 3;
  }

  // ---- Outbox --------------------------------------------------------------

  /// Queues every existing row, for the first upload after sync is switched
  /// on. Never replaces a real edit already waiting.
  Future<void> queueAll() => _db.transaction(() async {
    for (final table in tables) {
      final name = table.actualTableName;
      await _db.customStatement(
        'INSERT OR IGNORE INTO sync_outbox (table_name, row_key, op, changed_at) '
        "SELECT '$name', ${_keySql(table, 't')}, 'seed', 0 FROM \"$name\" t "
        'WHERE ${_notDemo(table, 't')}',
      );
    }
  });

  Future<int> pendingCount() async {
    final row = await _db
        .customSelect('SELECT COUNT(*) AS n FROM sync_outbox')
        .getSingle();
    return row.read<int>('n');
  }

  /// The oldest waiting changes, each with its row as it is now.
  Future<List<OutboxEntry>> readOutbox({int limit = 200}) async {
    final waiting = await (_db.select(_db.syncOutbox)
          ..orderBy([(o) => OrderingTerm.asc(o.changedAt)])
          ..limit(limit))
        .get();
    final entries = <OutboxEntry>[];
    for (final item in waiting) {
      final table = _byName[item.entity];
      if (table == null) {
        // A table that no longer syncs.
        await _forget(item.entity, item.rowKey, item.changedAt);
        continue;
      }
      final row = item.op == 'delete' ? null : await readRow(table, item.rowKey);
      entries.add(
        OutboxEntry(
          table: item.entity,
          key: item.rowKey,
          // A row queued for upload but gone by now is a delete.
          op: row == null ? 'delete' : item.op,
          changedAt: item.changedAt,
          row: row,
        ),
      );
    }
    return entries;
  }

  /// The waiting change for one row, if there is one.
  Future<OutboxEntry?> pendingFor(String table, String key) async {
    final item = await (_db.select(_db.syncOutbox)
          ..where((o) => o.entity.equals(table) & o.rowKey.equals(key)))
        .getSingleOrNull();
    if (item == null) return null;
    return OutboxEntry(
      table: item.entity,
      key: item.rowKey,
      op: item.op,
      changedAt: item.changedAt,
    );
  }

  /// Clears uploaded entries — unless the row changed again meanwhile, in
  /// which case the newer change stays queued.
  Future<void> markUploaded(Iterable<OutboxEntry> entries) =>
      _db.transaction(() async {
        for (final entry in entries) {
          await _forget(entry.table, entry.key, entry.changedAt);
        }
      });

  Future<void> _forget(String table, String key, int changedAt) =>
      (_db.delete(_db.syncOutbox)..where(
            (o) =>
                o.entity.equals(table) &
                o.rowKey.equals(key) &
                o.changedAt.isSmallerOrEqualValue(changedAt),
          ))
          .go();

  // ---- Rows ----------------------------------------------------------------

  Future<Map<String, Object?>?> readRow(
    TableInfo<Table, dynamic> table,
    String key,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT * FROM "${table.actualTableName}" WHERE ${_keyWhere(table)}',
          variables: [
            for (final v in _keyValues(table, key)) Variable(v),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return {
      for (final entry in row.data.entries)
        entry.key: entry.value is Uint8List
            ? {r'$b': base64Encode(entry.value as Uint8List)}
            : entry.value,
    };
  }

  /// Applies other phones' changes in one transaction, with the triggers
  /// told to stand aside, then brings every balance back in line with its
  /// transactions.
  Future<void> applyIncoming(List<IncomingChange> changes) async {
    if (changes.isEmpty) return;
    final touched = <TableInfo<Table, dynamic>>{};
    await _db.transaction(() async {
      await writeState('applying_remote', '1');
      try {
        for (final change in changes) {
          final table = _byName[change.table];
          if (table == null) continue;
          touched.add(table);
          final row = change.row;
          if (row == null) {
            await _db.customStatement(
              'DELETE FROM "${change.table}" WHERE ${_keyWhere(table)}',
              _keyValues(table, change.key),
            );
          } else {
            await _upsert(table, row);
          }
        }
        if (touched.any(
          (t) => t.actualTableName == 'transactions' ||
              t.actualTableName == 'accounts',
        )) {
          await _recomputeBalances();
          touched.add(_db.accounts);
        }
      } finally {
        await writeState('applying_remote', null);
      }
    });
    // Raw SQL doesn't tell Drift's streams anything changed.
    _db.markTablesUpdated(touched);
  }

  Future<void> _upsert(
    TableInfo<Table, dynamic> table,
    Map<String, Object?> row,
  ) async {
    // Only the columns this version has: a row from an older version fills
    // the rest with defaults; the server keeps newer versions' rows aside.
    final known = {for (final c in table.$columns) c.name};
    final columns = [
      for (final name in row.keys)
        if (known.contains(name)) name,
    ];
    final keys = _keyColumns(table);
    final updates = [
      for (final c in columns)
        if (!keys.contains(c)) '"$c" = excluded."$c"',
    ];
    final values = [
      for (final c in columns)
        switch (row[c]) {
          {r'$b': final String b} => base64Decode(b),
          final value => value,
        },
    ];
    await _db.customStatement(
      'INSERT INTO "${table.actualTableName}" '
      '(${columns.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')}) '
      'ON CONFLICT (${keys.map((c) => '"$c"').join(', ')}) '
      '${updates.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${updates.join(', ')}'}',
      values,
    );
  }

  // ---- Derived data ---------------------------------------------------------

  static const _recordedSql =
      '(SELECT COALESCE(SUM(amount_minor), 0) FROM transactions '
      'WHERE transactions.account_id = accounts.id)';

  /// Every balance as its opening balance plus its transactions — after a
  /// download, when another phone's entries have just arrived.
  Future<void> _recomputeBalances() => _db.customStatement(
    'UPDATE accounts SET balance_minor = opening_balance_minor + $_recordedSql '
    'WHERE balance_minor IS NOT opening_balance_minor + $_recordedSql',
  );

  /// The reverse, before an upload: anything that set a balance without
  /// going through an account edit (a restored backup, sample data) leaves
  /// the opening balance behind; this brings it back so the balance shown
  /// here is the one other phones will compute.
  Future<void> reconcileOpeningBalances() async {
    await _db.customStatement(
      'UPDATE accounts SET opening_balance_minor = balance_minor - $_recordedSql '
      'WHERE opening_balance_minor IS NOT balance_minor - $_recordedSql',
    );
    _db.markTablesUpdated({_db.accounts});
  }

  /// Built-in categories and account types created separately on two
  /// phones before they had the same ids: keeps one of each — the same one
  /// on every phone — and points everything at it.
  Future<void> mergeDuplicateDefaults() async {
    final merged = await _db.transaction(() async {
      var changed = false;
      final categories = await _db
          .customSelect(
            'SELECT lower(name) AS n, kind, MIN(id) AS keep, '
            'group_concat(id) AS ids FROM categories '
            'GROUP BY lower(name), kind HAVING COUNT(*) > 1',
          )
          .get();
      for (final group in categories) {
        final keep = group.read<String>('keep');
        for (final id in group.read<String>('ids').split(',')) {
          if (id == keep) continue;
          for (final table in [
            'transactions',
            'recurring_transactions',
            'bills',
            'budgets',
            'habits',
            'tasks',
          ]) {
            await _db.customStatement(
              'UPDATE "$table" SET category_id = ? WHERE category_id = ?',
              [keep, id],
            );
          }
          await _db.customStatement('DELETE FROM categories WHERE id = ?', [
            id,
          ]);
          changed = true;
        }
      }
      final types = await _db
          .customSelect(
            'SELECT MIN(id) AS keep, group_concat(id) AS ids FROM account_types '
            'GROUP BY lower(name) HAVING COUNT(*) > 1',
          )
          .get();
      for (final group in types) {
        final keep = group.read<String>('keep');
        for (final id in group.read<String>('ids').split(',')) {
          if (id == keep) continue;
          await _db.customStatement('DELETE FROM account_types WHERE id = ?', [
            id,
          ]);
          changed = true;
        }
      }
      return changed;
    });
    if (merged) {
      _db.markTablesUpdated({
        _db.categories,
        _db.accountTypes,
        _db.transactions,
        _db.recurringTransactions,
        _db.bills,
        _db.budgets,
        _db.habits,
        _db.tasks,
      });
    }
  }

  // ---- Held records ---------------------------------------------------------

  Future<void> hold(String recordId, int schemaVer, String record) => _db
      .into(_db.syncHeld)
      .insertOnConflictUpdate(
        SyncHeldCompanion.insert(
          recordId: recordId,
          schemaVer: schemaVer,
          record: record,
        ),
      );

  /// Held records this version can now read, removed from the hold.
  Future<List<String>> releaseHeld(int schemaVersion) async {
    final ready = await (_db.select(
      _db.syncHeld,
    )..where((h) => h.schemaVer.isSmallerOrEqualValue(schemaVersion))).get();
    if (ready.isEmpty) return const [];
    await (_db.delete(
      _db.syncHeld,
    )..where((h) => h.schemaVer.isSmallerOrEqualValue(schemaVersion))).go();
    return [for (final h in ready) h.record];
  }

  // ---- Leaving -------------------------------------------------------------

  /// Stops recording changes and forgets this account's sync state. The
  /// data itself stays; the device id is kept.
  Future<void> reset() async {
    await removeTriggers();
    await _db.transaction(() async {
      await _db.delete(_db.syncOutbox).go();
      await _db.delete(_db.syncHeld).go();
      await (_db.delete(
        _db.syncState,
      )..where((s) => s.key.equals('device_id').not())).go();
    });
  }
}
