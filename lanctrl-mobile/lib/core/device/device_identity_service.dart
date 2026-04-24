import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static Future<String>? _cachedClientName;

  static Future<String> currentClientName() {
    return _cachedClientName ??= _loadClientName();
  }

  static Future<String> _loadClientName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final manufacturer = info.manufacturer.trim();
        final model = info.model.trim();
        if (manufacturer.isEmpty) {
          return model.isEmpty ? 'Android 设备' : model;
        }
        if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
          return model;
        }
        return '$manufacturer $model'.trim();
      }

      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.name.trim().isNotEmpty
            ? info.name.trim()
            : (info.model.trim().isNotEmpty ? info.model.trim() : 'iPhone');
      }

      if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return info.computerName.trim().isNotEmpty
            ? info.computerName.trim()
            : 'Windows 设备';
      }

      if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return info.computerName.trim().isNotEmpty
            ? info.computerName.trim()
            : 'Mac 设备';
      }

      if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return info.prettyName.trim().isNotEmpty
            ? info.prettyName.trim()
            : 'Linux 设备';
      }
    } catch (_) {
      // Fall through to hostname fallback.
    }

    final environmentName = Platform.localHostname.trim();
    return environmentName.isNotEmpty ? environmentName : 'LanCtrl 设备';
  }
}
