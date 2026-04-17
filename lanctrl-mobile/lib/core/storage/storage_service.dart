import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  StorageService(this._secureStorage, this._prefs);

  static Future<StorageService> init() async {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    
    // Init Client ID for the first start
    if (!prefs.containsKey('client_id')) {
      await prefs.setString('client_id', const Uuid().v4());
    }

    return StorageService(secureStorage, prefs);
  }

  String get clientId => _prefs.getString('client_id')!;

  // Save device meta to SharedPreferences (omitting the sensitive Tokens)
  Map<String, dynamic> getDevice(String deviceId) {
    var str = _prefs.getString('device_$deviceId');
    if (str != null) return jsonDecode(str);
    return {};
  }
  
  Future<void> saveDevice(String deviceId, String name, String ip, int port) async {
    final dev = {
      'deviceId': deviceId,
      'name': name,
      'ip': ip,
      'port': port,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs.setString('device_$deviceId', jsonEncode(dev));
    
    List<String> devices = _prefs.getStringList('known_devices') ?? [];
    if (!devices.contains(deviceId)) {
      devices.add(deviceId);
      await _prefs.setStringList('known_devices', devices);
    }
  }

  Future<void> removeDevice(String deviceId) async {
    await _prefs.remove('device_$deviceId');
    await _secureStorage.delete(key: 'token_$deviceId');
    
    List<String> devices = _prefs.getStringList('known_devices') ?? [];
    devices.remove(deviceId);
    await _prefs.setStringList('known_devices', devices);
  }
  
  List<Map<String, dynamic>> getAllKnownDevices() {
    List<String> devices = _prefs.getStringList('known_devices') ?? [];
    List<Map<String, dynamic>> result = [];
    for (var id in devices) {
      var d = getDevice(id);
      if (d.isNotEmpty) result.add(d);
    }
    return result;
  }

  // Token is saved strictly in SecureStorage
  Future<void> saveToken(String deviceId, String token) async {
    await _secureStorage.write(key: 'token_$deviceId', value: token);
  }

  Future<String?> getToken(String deviceId) async {
    return await _secureStorage.read(key: 'token_$deviceId');
  }
}

// Provider injected later via ProviderScope overrides in main.dart
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Storage provider must be initialized.');
});
