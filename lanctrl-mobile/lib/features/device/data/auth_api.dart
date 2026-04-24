import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../app/domain/app_models.dart';

class AuthApi {
  AuthApi(this._dio, this._storage);

  final Dio _dio;
  final StorageService _storage;

  Future<String?> pairDevice(
    String ip,
    int port,
    String deviceName,
    String deviceId,
  ) async {
    final url = 'http://$ip:$port/auth/pair';
    final clientName = await DeviceIdentityService.currentClientName();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {'client_id': _storage.clientId, 'client_name': clientName},
      );

      final data = response.data ?? const <String, dynamic>{};
      if (data['success'] == true && data['token'] != null) {
        final returnedDeviceId = data['device_id'] as String? ?? deviceId;
        final returnedDeviceName = data['device_name'] as String? ?? deviceName;

        await _storage.saveToken(returnedDeviceId, data['token'] as String);
        await _storage.saveDevice(
          returnedDeviceId,
          returnedDeviceName,
          ip,
          port,
        );
        return data['token'] as String;
      }
    } catch (error) {
      debugPrint('配对请求失败: $error');
    }

    return null;
  }

  Future<bool> verifyDevice(KnownDevice device) async {
    final token = await _storage.getToken(device.deviceId);
    if (token == null) {
      return false;
    }

    final clientName = await DeviceIdentityService.currentClientName();
    final url = 'http://${device.ip}:${device.port}/auth/verify';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'client_id': _storage.clientId,
          'token': token,
          'client_name': clientName,
        },
      );

      if (response.data?['success'] == true) {
        return true;
      }

      await _storage.removeDevice(device.deviceId);
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<bool> connectDevice(KnownDevice device) async {
    final token = await _storage.getToken(device.deviceId);
    if (token == null) {
      return false;
    }

    final clientName = await DeviceIdentityService.currentClientName();
    final url = 'http://${device.ip}:${device.port}/auth/connect';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'client_id': _storage.clientId,
          'token': token,
          'client_name': clientName,
        },
      );
      return response.data?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnectDevice(KnownDevice device) async {
    final token = await _storage.getToken(device.deviceId);
    final clientName = await DeviceIdentityService.currentClientName();
    final url = 'http://${device.ip}:${device.port}/auth/disconnect';

    try {
      await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'client_id': _storage.clientId,
          'token': token ?? '',
          'client_name': clientName,
        },
      );
    } catch (_) {
      // Local session still needs to be cleared.
    }
  }

  Future<bool> heartbeatDevice(KnownDevice device) async {
    final token = await _storage.getToken(device.deviceId);
    if (token == null) {
      return false;
    }

    final clientName = await DeviceIdentityService.currentClientName();
    final url = 'http://${device.ip}:${device.port}/auth/heartbeat';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {
          'client_id': _storage.clientId,
          'token': token,
          'client_name': clientName,
        },
      );
      return response.data?['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<({List<FeatureGroup> groups, FeatureSnapshot snapshot})> fetchCatalog(
    KnownDevice device,
  ) async {
    final response = await _authorizedPost(
      device,
      '/features/catalog',
      data: {},
    );

    if (response['success'] != true) {
      throw Exception(response['msg'] ?? '无法读取功能目录');
    }

    final groups = (response['groups'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => _featureGroupFromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final snapshot = _featureSnapshotFromJson(
      response['snapshot'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );

    return (groups: groups, snapshot: snapshot);
  }

  Future<FeatureExecutionResult> executeCommand(
    KnownDevice device, {
    required String feature,
    int? level,
  }) async {
    final data = <String, dynamic>{'feature': feature};
    if (level != null) {
      data['level'] = level;
    }

    final response = await _authorizedPost(
      device,
      '/features/execute',
      data: data,
    );

    if (response['success'] != true) {
      throw Exception(response['msg'] ?? '执行失败');
    }

    return _executionResultFromJson(
      response['result'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      response['msg'] as String? ?? '执行成功',
    );
  }

  Future<List<ScheduledTask>> listTasks(KnownDevice device) async {
    final response = await _authorizedPost(device, '/tasks/list', data: {});

    if (response['success'] != true) {
      throw Exception(response['msg'] ?? '无法读取定时任务');
    }

    return (response['tasks'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => _scheduledTaskFromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ScheduledTask> createTask(
    KnownDevice device, {
    required String feature,
    required DateTime executeAt,
    int? level,
  }) async {
    final data = <String, dynamic>{
      'execute_at_ms': executeAt.millisecondsSinceEpoch,
      'feature': feature,
    };
    if (level != null) {
      data['level'] = level;
    }

    final response = await _authorizedPost(device, '/tasks/create', data: data);

    if (response['success'] != true) {
      throw Exception(response['msg'] ?? '创建定时任务失败');
    }

    return _scheduledTaskFromJson(
      response['task'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  Future<void> cancelTask(KnownDevice device, String taskId) async {
    final response = await _authorizedPost(
      device,
      '/tasks/cancel',
      data: {'task_id': taskId},
    );

    if (response['success'] != true) {
      throw Exception(response['msg'] ?? '停止定时任务失败');
    }
  }

  Future<Map<String, dynamic>> _authorizedPost(
    KnownDevice device,
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final token = await _storage.getToken(device.deviceId);
    if (token == null) {
      throw Exception('设备令牌不存在，请重新配对');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      'http://${device.ip}:${device.port}$path',
      data: {'client_id': _storage.clientId, 'token': token, ...data},
    );

    return response.data ?? const <String, dynamic>{};
  }

  FeatureGroup _featureGroupFromJson(Map<String, dynamic> json) {
    return FeatureGroup(
      groupKey: json['groupKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      features: (json['features'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => _featureFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  FeatureDefinition _featureFromJson(Map<String, dynamic> json) {
    final control = json['control'] as Map<String, dynamic>? ?? const {};
    final type = control['type'] as String? ?? 'action';

    return FeatureDefinition(
      featureKey: json['featureKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mobileReady: json['mobileReady'] as bool? ?? false,
      control: switch (type) {
        'range' => RangeFeatureControl(
          min: (control['min'] as num?)?.toInt() ?? 0,
          max: (control['max'] as num?)?.toInt() ?? 100,
          step: (control['step'] as num?)?.toInt() ?? 1,
          unit: control['unit'] as String? ?? '',
          actionText: control['actionText'] as String? ?? '应用',
        ),
        _ => ActionFeatureControl(
          buttonText: control['buttonText'] as String? ?? '执行',
          tone: (control['tone'] as String?) == 'danger'
              ? FeatureTone.danger
              : FeatureTone.primary,
          confirmRequired: control['confirmRequired'] as bool? ?? false,
        ),
      },
    );
  }

  FeatureSnapshot _featureSnapshotFromJson(Map<String, dynamic> json) {
    return FeatureSnapshot(
      volumeLevel: (json['volumeLevel'] as num?)?.toInt() ?? 0,
    );
  }

  FeatureExecutionResult _executionResultFromJson(
    Map<String, dynamic> json,
    String fallbackMessage,
  ) {
    return FeatureExecutionResult(
      featureKey: json['featureKey'] as String? ?? '',
      message: json['message'] as String? ?? fallbackMessage,
      volumeLevel: (json['volumeLevel'] as num?)?.toInt(),
    );
  }

  ScheduledTask _scheduledTaskFromJson(Map<String, dynamic> json) {
    final origin = json['origin'] as Map<String, dynamic>? ?? const {};
    return ScheduledTask(
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      executeAtMs: (json['executeAtMs'] as num?)?.toInt() ?? 0,
      originKind: (origin['kind'] as String?) == 'mobile'
          ? TaskOriginKind.mobile
          : TaskOriginKind.pc,
      originName: origin['clientName'] as String? ?? 'PC',
      feature: json['feature'] as String? ?? '',
      level: (json['level'] as num?)?.toInt(),
      originClientId: origin['clientId'] as String?,
    );
  }
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider), ref.watch(storageServiceProvider));
});
