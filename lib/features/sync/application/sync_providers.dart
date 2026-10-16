import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database_provider.dart';
import '../data/local_sync_store.dart';
import '../data/supabase_config.dart';
import '../data/supabase_sync_backend.dart';
import '../data/sync_backend.dart';
import '../data/sync_session.dart';
import '../domain/sync_crypto.dart';
import 'sync_engine.dart';

/// The Supabase client, or null in a build without sync's keys.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } on Object {
    // Initialisation failed at launch; the app carries on local-only.
    return null;
  }
});

final syncBackendProvider = Provider<SyncBackend?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseSyncBackend(client);
});

final syncSessionProvider = Provider<SyncSession?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseSyncSession(client);
});

final syncKeyStoreProvider = Provider<SyncKeyStore>(
  (ref) => SecureSyncKeyStore(),
);

final syncCryptoProvider = Provider<SyncCrypto>((ref) => SyncCrypto());

final localSyncStoreProvider = Provider<LocalSyncStore>(
  (ref) => LocalSyncStore(ref.watch(appDatabaseProvider)),
);

enum SyncPhase {
  /// This build has no Supabase keys.
  unavailable,
  signedOut,

  /// Signed in; working out whether this account has sync set up yet.
  checking,

  /// The first phone on this account: a data key and recovery key are made.
  needsSetup,

  /// The account has sync on another phone: the recovery key unlocks it.
  needsRecoveryKey,
  ready,
}

@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.email,
    this.syncing = false,
    this.lastSyncedAt,
    this.pending = 0,
    this.uploadsRefused = false,
    this.skipped = 0,
    this.error,
    this.choosingNewPassword = false,
  });

  final SyncPhase phase;
  final String? email;
  final bool syncing;
  final DateTime? lastSyncedAt;

  /// Local changes not uploaded yet.
  final int pending;

  /// No active subscription: changes stay on this phone until there is one.
  final bool uploadsRefused;
  final int skipped;

  /// The last attempt failed — usually just being offline.
  final String? error;

  /// A password-reset link was opened: ask for the new password.
  final bool choosingNewPassword;

  SyncStatus copyWith({
    SyncPhase? phase,
    String? email,
    bool? syncing,
    DateTime? lastSyncedAt,
    int? pending,
    bool? uploadsRefused,
    int? skipped,
    String? Function()? error,
    bool? choosingNewPassword,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    pending: pending ?? this.pending,
    uploadsRefused: uploadsRefused ?? this.uploadsRefused,
    skipped: skipped ?? this.skipped,
    error: error == null ? this.error : error(),
    choosingNewPassword: choosingNewPassword ?? this.choosingNewPassword,
  );
}

/// A data key and its recovery key, made but not yet saved — the recovery
/// key is shown first, and only stored once the person says they've kept it.
class PendingRecoveryKey {
  const PendingRecoveryKey._(this.recoveryKey, this._dataKey, this._replacing);

  final String recoveryKey;
  final Uint8List _dataKey;
  final bool _replacing;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Runs sync for the app: follows sign-in, holds the data key, and decides
/// when a round runs — on launch, on return to the app, five seconds after
/// the last local change, every fifteen minutes, and on "Sync now".
///
/// Nothing here is on the path of a screen: the app reads and writes its
/// own database exactly as it does without sync.
class SyncController extends Notifier<SyncStatus> {
  static const changeDelay = Duration(seconds: 5);
  static const interval = Duration(minutes: 15);
  static const _backoff = [
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  Uint8List? _dataKey;
  String? _userId;
  bool _started = false;
  bool _running = false;
  bool _again = false;
  int _failures = 0;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _retry;
  final _subscriptions = <StreamSubscription<Object?>>[];

  SyncSession? get _session => ref.read(syncSessionProvider);
  SyncBackend? get _backend => ref.read(syncBackendProvider);
  LocalSyncStore get _store => ref.read(localSyncStoreProvider);
  SyncKeyStore get _keys => ref.read(syncKeyStoreProvider);
  SyncCrypto get _crypto => ref.read(syncCryptoProvider);

  @override
  SyncStatus build() {
    ref.onDispose(_stopTimers);
    ref.onDispose(() {
      for (final s in _subscriptions) {
        s.cancel();
      }
    });
    final session = ref.read(syncSessionProvider);
    if (session == null || ref.read(syncBackendProvider) == null) {
      return const SyncStatus(phase: SyncPhase.unavailable);
    }
    return SyncStatus(
      phase: session.userId == null ? SyncPhase.signedOut : SyncPhase.checking,
      email: session.email,
    );
  }

  /// Called once the app is up. Follows sign-in from then on.
  Future<void> start() async {
    final session = _session;
    if (_started || session == null) return;
    _started = true;
    _subscriptions
      ..add(session.userIdChanges.listen((_) => _evaluate()))
      ..add(
        session.passwordRecovery.listen(
          (_) => state = state.copyWith(choosingNewPassword: true),
        ),
      )
      // Any write to the database might have queued something; a write
      // that only applied a download queues nothing, so this can't loop.
      ..add(
        ref
            .read(appDatabaseProvider)
            .tableUpdates(const TableUpdateQuery.any())
            .listen((_) => _scheduleAfterChange()),
      );
    await _evaluate();
  }

  void onResumed() {
    if (state.phase == SyncPhase.ready) unawaited(syncNow());
  }

  void finishedChoosingPassword() =>
      state = state.copyWith(choosingNewPassword: false);

  /// Works out where sync stands for whoever is signed in now.
  Future<void> _evaluate() async {
    final session = _session;
    final backend = _backend;
    if (session == null || backend == null) return;
    final userId = session.userId;
    if (userId == null) {
      _userId = null;
      _dataKey = null;
      _stopTimers();
      state = SyncStatus(phase: SyncPhase.signedOut);
      return;
    }
    if (userId == _userId && _dataKey != null) return;
    _userId = userId;
    state = SyncStatus(phase: SyncPhase.checking, email: session.email);

    final key = await _keys.read(userId);
    if (key != null) {
      await _enable(userId, key);
      return;
    }
    try {
      final wrapped = await backend.fetchWrappedKey();
      if (_userId != userId) return;
      state = state.copyWith(
        phase: wrapped == null
            ? SyncPhase.needsSetup
            : SyncPhase.needsRecoveryKey,
        error: () => null,
      );
    } on Object catch (e) {
      state = state.copyWith(error: () => _describe(e));
      _scheduleRetry(_evaluateAgain);
    }
  }

  void _evaluateAgain() {
    _userId = null;
    unawaited(_evaluate());
  }

  /// The first phone: makes the keys. Nothing is stored until
  /// [saveRecoveryKey].
  PendingRecoveryKey newAccountKeys() => PendingRecoveryKey._(
    _crypto.newRecoveryKey(),
    _crypto.newDataKey(),
    false,
  );

  /// A replacement recovery key for the data key this phone already has —
  /// for a lost recovery key, while a phone that still syncs is at hand.
  PendingRecoveryKey replacementRecoveryKey() {
    final key = _dataKey;
    if (key == null) throw StateError('Sync is not set up on this phone');
    return PendingRecoveryKey._(_crypto.newRecoveryKey(), key, true);
  }

  /// Stores [pending] once the person has kept its recovery key, then
  /// starts syncing.
  Future<void> saveRecoveryKey(PendingRecoveryKey pending) async {
    final userId = _requireUser();
    final wrapped = await _crypto.wrapDataKey(
      pending._dataKey,
      pending.recoveryKey,
      userId,
    );
    await _backend!.storeWrappedKey(
      WrappedKey(wrapped),
      replace: pending._replacing,
    );
    if (pending._replacing) return;
    await _keys.write(userId, pending._dataKey);
    await _enable(userId, pending._dataKey);
  }

  /// Unlocks sync on another phone with the account's recovery key.
  /// Throws [SyncCryptoException] with a message to show for a wrong key.
  Future<void> unlock(String recoveryKey) async {
    final userId = _requireUser();
    final wrapped = await _backend!.fetchWrappedKey();
    if (wrapped == null) {
      throw const SyncCryptoException(
        'Sync isn\'t set up on this account yet.',
      );
    }
    final key = await _crypto.unwrapDataKey(
      wrapped.wrapped,
      recoveryKey,
      userId,
    );
    await _keys.write(userId, key);
    await _enable(userId, key);
  }

  Future<void> _enable(String userId, Uint8List key) async {
    final store = _store;
    final enabledFor = await store.readState('enabled_user');
    if (enabledFor != userId) {
      // A different account than last time: start over, so its records
      // aren't mixed with the last account's sync state.
      if (enabledFor != null) await store.reset();
      await store.installTriggers();
      await store.queueAll();
      await store.writeState('enabled_user', userId);
    } else if (!await store.triggersInstalled()) {
      await store.installTriggers();
    }
    _dataKey = key;
    state = state.copyWith(
      phase: SyncPhase.ready,
      lastSyncedAt: _parseTime(await store.readState('last_synced')),
      pending: await store.pendingCount(),
    );
    _periodic?.cancel();
    _periodic = Timer.periodic(interval, (_) => syncNow());
    unawaited(_registerDevice());
    unawaited(syncNow());
  }

  Future<void> _registerDevice() async {
    try {
      final name = kIsWeb
          ? 'Web'
          : Platform.isIOS
          ? 'iPhone'
          : Platform.isAndroid
          ? 'Android phone'
          : Platform.operatingSystem;
      await _backend?.registerDevice(await _store.deviceId(), name);
    } on Object {
      // Only labels the device in a list; never worth failing over.
    }
  }

  void _scheduleAfterChange() {
    if (state.phase != SyncPhase.ready) return;
    _debounce?.cancel();
    _debounce = Timer(changeDelay, () async {
      if (await _store.pendingCount() > 0) unawaited(syncNow());
    });
  }

  /// One round now. A request while one is running runs again after it.
  Future<void> syncNow() async {
    final key = _dataKey;
    final backend = _backend;
    if (key == null || backend == null || state.phase != SyncPhase.ready) {
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _retry?.cancel();
    state = state.copyWith(syncing: true);
    try {
      final engine = SyncEngine(
        store: _store,
        backend: backend,
        crypto: _crypto,
        dataKey: key,
        deviceId: await _store.deviceId(),
        schemaVersion: ref.read(appDatabaseProvider).schemaVersion,
      );
      final result = await engine.run();
      _failures = 0;
      state = state.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now(),
        pending: await _store.pendingCount(),
        uploadsRefused: result.uploadsRefused,
        skipped: result.skipped,
        error: () => null,
      );
    } on Object catch (e) {
      state = state.copyWith(
        syncing: false,
        pending: await _store.pendingCount(),
        error: () => _describe(e),
      );
      _scheduleRetry(() => unawaited(syncNow()));
    } finally {
      _running = false;
    }
    if (_again) {
      _again = false;
      unawaited(syncNow());
    }
  }

  void _scheduleRetry(void Function() action) {
    final delay = _backoff[_failures.clamp(0, _backoff.length - 1)];
    _failures++;
    _retry?.cancel();
    _retry = Timer(delay, action);
  }

  /// Stops syncing and signs out. The data stays on this phone.
  Future<void> signOut() async {
    final userId = _userId;
    _stopTimers();
    await _store.reset();
    if (userId != null) await _keys.delete(userId);
    _dataKey = null;
    _userId = null;
    await _session?.signOut();
    state = const SyncStatus(phase: SyncPhase.signedOut);
  }

  /// Deletes the account and everything stored for it on the server. The
  /// data on this phone stays.
  Future<void> deleteAccount() async {
    final userId = _requireUser();
    _stopTimers();
    await _backend!.deleteAccount();
    await _store.reset();
    await _keys.delete(userId);
    _dataKey = null;
    _userId = null;
    state = const SyncStatus(phase: SyncPhase.signedOut);
  }

  String _requireUser() {
    final id = _session?.userId;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  void _stopTimers() {
    _debounce?.cancel();
    _periodic?.cancel();
    _retry?.cancel();
  }

  static DateTime? _parseTime(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();

  static String _describe(Object error) => switch (error) {
    SocketException() ||
    TimeoutException() ||
    AuthRetryableFetchException() =>
      'Offline. Changes are kept and will sync when you\'re back online.',
    // package:http's ClientException, wrapping a failed connection.
    _ when '$error'.contains('SocketException') =>
      'Offline. Changes are kept and will sync when you\'re back online.',
    AuthException(message: final m) => m,
    PostgrestException(message: final m) => 'The server refused: $m',
    _ => 'Couldn\'t sync just now. It will try again shortly.',
  };
}
