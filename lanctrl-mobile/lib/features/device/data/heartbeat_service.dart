import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/storage/storage_service.dart';
import '../../app/domain/app_models.dart';
import 'auth_api.dart';

class HeartbeatService {
  HeartbeatService._();

  static final HeartbeatService instance = HeartbeatService._();
  static const _interval = Duration(seconds: 8);

  StorageService? _storage;
  Timer? _timer;
  bool _running = false;

  void start(StorageService storage) {
    _storage = storage;
    _timer?.cancel();
    unawaited(_sendHeartbeats());
    _timer = Timer.periodic(_interval, (_) => unawaited(_sendHeartbeats()));
  }

  Future<void> _sendHeartbeats() async {
    final storage = _storage;
    if (storage == null || _running) {
      return;
    }

    _running = true;
    try {
      final authApi = AuthApi(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 5),
          ),
        ),
        storage,
      );

      final devices = storage.getAllKnownDevices().map(KnownDevice.fromMap);
      await Future.wait(
        devices
            .where(
              (device) => device.deviceId.isNotEmpty && device.ip.isNotEmpty,
            )
            .map(authApi.heartbeatDevice),
      );
    } finally {
      _running = false;
    }
  }
}
