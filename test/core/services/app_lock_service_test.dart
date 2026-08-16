import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/services/app_lock_service.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    return _store[key];
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map.of(_store);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }
}

void main() {
  late AppLockService service;

  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    service = AppLockService(storage: const FlutterSecureStorage());
  });

  test('hasPin is false before any PIN is set', () async {
    expect(await service.hasPin(), isFalse);
  });

  test('setPin then verifyPin round-trips correctly', () async {
    await service.setPin('1234');
    expect(await service.hasPin(), isTrue);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('0000'), isFalse);
  });

  test('clearPin removes the stored PIN', () async {
    await service.setPin('1234');
    await service.clearPin();
    expect(await service.hasPin(), isFalse);
    expect(await service.verifyPin('1234'), isFalse);
  });
}
