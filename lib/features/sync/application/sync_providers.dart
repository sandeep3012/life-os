import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database_provider.dart';
import '../data/local_sync_store.dart';
import '../data/supabase_config.dart';
import '../data/supabase_sync_backend.dart';
import '../data/sync_key_backup.dart';
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

/// The copy of the data key in iCloud Keychain / Google's Block Store.
final syncKeyBackupProvider = Provider<SyncKeyBackup>(
  (ref) => SyncKeyBackup.forPlatform(),
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
    this.keyBackedUpTo,
    this.serverRecovery,
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

  /// Where the data key is also kept — "iCloud Keychain", "your Google
  /// account" — so a new phone unlocks on sign-in. Null when it isn't.
  final String? keyBackedUpTo;

  /// Standard recovery: the server holds a copy of the key, so signing in
  /// is enough to get the data back. False for Maximum privacy; null until
  /// known.
  final bool? serverRecovery;

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
    String? keyBackedUpTo,
    bool? serverRecovery,
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
    keyBackedUpTo: keyBackedUpTo ?? this.keyBackedUpTo,
    serverRecovery: serverRecovery ?? this.serverRecovery,
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

  /// Debug builds only: sync's steps in the phone's log ("sync:" in
  /// logcat), for tracing a restore on a real phone.
  static void _log(String message) {
    if (kDebugMode) debugPrint('sync: $message');
  }

  SyncSession? get _session => ref.read(syncSessionProvider);
  SyncBackend? get _backend => ref.read(syncBackendProvider);
  LocalSyncStore get _store => ref.read(localSyncStoreProvider);
  SyncKeyStore get _keys => ref.read(syncKeyStoreProvider);
  SyncKeyBackup get _backup => ref.read(syncKeyBackupProvider);
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
      _log('key found on this phone');
      await _enable(userId, key);
      return;
    }
    _log('no key on this phone, checking the account');
    try {
      final wrapped = await backend.fetchWrappedKey();
      if (_userId != userId) return;
      if (wrapped != null) {
        // A reinstall, or a new phone on the same Apple / Google account:
        // the platform's backup may already hold the key.
        final fromBackup = await _restoreFromBackup(userId, backend);
        _log('platform backup copy: ${fromBackup == null ? 'none' : 'found'}');
        final restored = fromBackup ?? await _restoreFromServer(backend);
        if (fromBackup == null) {
          _log('server copy: ${restored == null ? 'none' : 'found'}');
        }
        if (_userId != userId) return;
        if (restored != null) {
          await _keys.write(userId, restored);
          await _enable(userId, restored);
          return;
        }
      }
      _log(wrapped == null ? 'account not set up yet' : 'needs recovery key');
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

  /// The data key from the platform's backup, once it has opened one of
  /// this account's records — a key that can't is ignored and removed.
  /// Null when there's no usable copy.
  Future<Uint8List?> _restoreFromBackup(
    String userId,
    SyncBackend backend,
  ) async {
    final backup = _backup;
    final Uint8List? key;
    try {
      key = await backup.read(userId);
    } on Object {
      return null;
    }
    if (key == null || key.length != SyncCrypto.keyLength) return null;
    if (!await _opensAccountRecords(key, backend)) {
      unawaited(_forgetBackup(userId));
      return null;
    }
    return key;
  }

  /// Standard recovery's copy, once it has opened one of this account's
  /// records. Null for Maximum privacy or a copy that doesn't fit.
  Future<Uint8List?> _restoreFromServer(SyncBackend backend) async {
    final Uint8List? key;
    try {
      key = await backend.fetchEscrowKey();
    } on Object {
      // The recovery key and the other phone still work.
      return null;
    }
    if (key == null || key.length != SyncCrypto.keyLength) return null;
    return await _opensAccountRecords(key, backend) ? key : null;
  }

  /// Whether [key] opens this account's records — true for an account with
  /// none uploaded yet, where there's nothing to tell by.
  Future<bool> _opensAccountRecords(Uint8List key, SyncBackend backend) async {
    final sample = await backend.pull(0, limit: 20);
    final record = sample.where((r) => r.payload.isNotEmpty).firstOrNull;
    if (record == null) return true;
    try {
      await _crypto.decryptRecord(key, record.id, record.payload);
      return true;
    } on Object {
      return false;
    }
  }

  /// Keeps the platform's copy of [key] current. Never fails sync: without
  /// it the recovery key still works.
  Future<void> _backUpKey(String userId, Uint8List key) async {
    final backup = _backup;
    final label = backup.label;
    if (label == null) return;
    try {
      final offPhone = await backup.write(userId, key);
      if (offPhone && ref.mounted && _userId == userId) {
        state = state.copyWith(keyBackedUpTo: label);
      }
    } on Object {
      // No iCloud Keychain, no Google Play services, or the platform said
      // no: the recovery key is the way back.
    }
  }

  Future<void> _forgetBackup(String userId) async {
    try {
      await _backup.delete(userId);
    } on Object {
      // Nothing to remove, or it can't be reached; harmless either way.
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
  /// starts syncing. With [serverRecovery] (Standard recovery) the server
  /// also keeps a copy of the data key, and the recovery key is never shown.
  Future<void> saveRecoveryKey(
    PendingRecoveryKey pending, {
    bool serverRecovery = false,
  }) async {
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
    if (serverRecovery) await _backend!.storeEscrowKey(pending._dataKey);
    state = state.copyWith(serverRecovery: serverRecovery);
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

  /// The joining phone's side of "Approve from my other phone": a one-off
  /// request whose [LinkRequest.code] goes in the QR code.
  Future<LinkRequest> startLink() => _crypto.newLinkRequest(const Uuid().v4());

  /// Looks once for the key the other phone left for [request], and unlocks
  /// sync with it. False while it hasn't arrived; throws
  /// [SyncCryptoException] if what arrived can't be used.
  Future<bool> collectLink(LinkRequest request) async {
    final userId = _requireUser();
    final backend = _backend!;
    final sealed = await backend.collectKeyTransfer(request.id);
    if (sealed == null) return false;
    unawaited(backend.removeKeyTransfer(request.id).catchError((_) {}));
    final key = await _crypto.openLink(request, sealed, userId);
    if (!await _opensAccountRecords(key, backend)) {
      throw const SyncCryptoException(
        "The other phone's key doesn't open this account's data.",
      );
    }
    await _keys.write(userId, key);
    await _enable(userId, key);
    return true;
  }

  /// The syncing phone's side: hands this phone's data key to the phone
  /// that showed [code]. Throws [SyncCryptoException] for a code that isn't
  /// LifeOS's.
  Future<void> approveLink(String code) async {
    final userId = _requireUser();
    final key = _dataKey;
    if (key == null) throw StateError('Sync is not set up on this phone');
    final request = LinkRequest.parse(code);
    final sealed = await _crypto.sealForLink(
      key,
      request.publicKey,
      userId,
      request.id,
    );
    await _backend!.leaveKeyTransfer(request.id, sealed);
  }

  /// Switches between Standard recovery ([on]: the server keeps a copy of
  /// the key) and Maximum privacy (its copy is deleted). Before turning it
  /// off, the person should have a recovery key they've saved.
  Future<void> setServerRecovery(bool on) async {
    final key = _dataKey;
    final backend = _backend;
    if (key == null || backend == null) {
      throw StateError('Sync is not set up on this phone');
    }
    if (on) {
      await backend.storeEscrowKey(key);
    } else {
      await backend.removeEscrowKey();
    }
    state = state.copyWith(serverRecovery: on);
  }

  Future<void> _refreshServerRecovery(String userId) async {
    try {
      final on = await _backend!.hasEscrowKey();
      if (ref.mounted && _userId == userId) {
        state = state.copyWith(serverRecovery: on);
      }
    } on Object {
      // Shown as unknown; the next launch asks again.
    }
  }

  /// Whether [recoveryKey] is the one this account's key is stored under —
  /// for checking a saved key still works, without changing anything.
  Future<bool> checkRecoveryKey(String recoveryKey) async {
    final userId = _requireUser();
    final wrapped = await _backend!.fetchWrappedKey();
    if (wrapped == null) return false;
    try {
      final key = await _crypto.unwrapDataKey(
        wrapped.wrapped,
        recoveryKey,
        userId,
      );
      return _dataKey == null || listEquals(key, _dataKey);
    } on SyncCryptoException {
      return false;
    }
  }

  Future<void> _enable(String userId, Uint8List key) async {
    final store = _store;
    final enabledFor = await store.readState('enabled_user');
    _log('enabling (last account here: ${enabledFor ?? 'none'})');
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
    unawaited(_backUpKey(userId, key));
    if (state.serverRecovery == null) {
      unawaited(_refreshServerRecovery(userId));
    }
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
      final pendingBefore = await _store.pendingCount();
      final result = await engine.run();
      _log(
        'round: $pendingBefore queued, ${result.uploaded} up, '
        '${result.downloaded} down, ${result.skipped} skipped'
        '${result.uploadsRefused ? ', uploads refused' : ''}',
      );
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
      _log('round failed: $e');
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

  /// Stops syncing and signs out. The data stays on this phone, and so does
  /// the platform backup of the key: signing in again unlocks without the
  /// recovery key.
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
    await _forgetBackup(userId);
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
    SocketException() || TimeoutException() || AuthRetryableFetchException() =>
      'Offline. Changes are kept and will sync when you\'re back online.',
    // package:http's ClientException, wrapping a failed connection.
    _ when '$error'.contains('SocketException') =>
      'Offline. Changes are kept and will sync when you\'re back online.',
    AuthException(message: final m) => m,
    PostgrestException(message: final m) => 'The server refused: $m',
    _ => 'Couldn\'t sync just now. It will try again shortly.',
  };
}
