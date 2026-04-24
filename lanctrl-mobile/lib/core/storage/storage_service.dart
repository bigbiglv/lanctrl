import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService(this._secureStorage, this._prefs);

  static const _clientIdKey = 'client_id';
  static const _knownDevicesKey = 'known_devices';
  static const _activeDeviceIdKey = 'active_device_id';
  static const _themeIdKey = 'theme_id';
  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static Future<StorageService> init() async {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_clientIdKey)) {
      await prefs.setString(_clientIdKey, const Uuid().v4());
    }

    return StorageService(secureStorage, prefs);
  }

  String get clientId => _prefs.getString(_clientIdKey)!;

  String? get activeDeviceId => _prefs.getString(_activeDeviceIdKey);

  Future<void> setActiveDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return _prefs.remove(_activeDeviceIdKey);
    }
    return _prefs.setString(_activeDeviceIdKey, deviceId);
  }

  String get themeId => _prefs.getString(_themeIdKey) ?? 'default';

  Future<void> setThemeId(String themeId) {
    return _prefs.setString(_themeIdKey, themeId);
  }

  String get themeMode => _prefs.getString(_themeModeKey) ?? 'light';

  Future<void> setThemeMode(String themeMode) {
    return _prefs.setString(_themeModeKey, themeMode);
  }

  Map<String, dynamic> getDevice(String deviceId) {
    final raw = _prefs.getString('device_$deviceId');
    if (raw == null) {
      return {};
    }

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveDevice(
    String deviceId,
    String name,
    String ip,
    int port,
  ) async {
    final device = <String, dynamic>{
      'deviceId': deviceId,
      'name': name,
      'ip': ip,
      'port': port,
      'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs.setString('device_$deviceId', jsonEncode(device));

    final devices = List<String>.from(
      _prefs.getStringList(_knownDevicesKey) ?? const <String>[],
    );
    if (!devices.contains(deviceId)) {
      devices.add(deviceId);
      await _prefs.setStringList(_knownDevicesKey, devices);
    }
  }

  Future<void> removeDevice(String deviceId) async {
    await _prefs.remove('device_$deviceId');
    await _secureStorage.delete(key: 'token_$deviceId');

    final devices = List<String>.from(
      _prefs.getStringList(_knownDevicesKey) ?? const <String>[],
    )..remove(deviceId);

    await _prefs.setStringList(_knownDevicesKey, devices);

    if (activeDeviceId == deviceId) {
      await setActiveDeviceId(null);
    }
  }

  List<Map<String, dynamic>> getAllKnownDevices() {
    final devices = _prefs.getStringList(_knownDevicesKey) ?? const <String>[];
    return devices
        .map(getDevice)
        .where((device) => device.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> saveToken(String deviceId, String token) {
    return _secureStorage.write(key: 'token_$deviceId', value: token);
  }

  Future<String?> getToken(String deviceId) {
    return _secureStorage.read(key: 'token_$deviceId');
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden in main().');
});
