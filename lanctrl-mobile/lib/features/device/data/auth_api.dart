import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/storage_service.dart';

class AuthApi {
  final Dio _dio;
  final StorageService _storage;

  AuthApi(this._dio, this._storage);

  Future<String?> pairDevice(String ip, int port, String deviceName, String deviceId) async {
    final url = 'http://$ip:$port/auth/pair';
    try {
      final response = await _dio.post(url, data: {
        'client_id': _storage.clientId,
        'client_name': '随身终端 (Mobile)', 
      });
      if (response.data['success'] == true) {
        final token = response.data['token'];
        if (token != null) {
          final returnedDeviceId = response.data['device_id'] ?? deviceId;
          final returnedDeviceName = response.data['device_name'] ?? deviceName;
          await _storage.saveToken(returnedDeviceId, token); // 安全落盘 Token
          await _storage.saveDevice(returnedDeviceId, returnedDeviceName, ip, port); // 记录常用信息
          return token;
        }
      }
    } catch (e) {
      // 网络拒绝挂起或错误抛出超时等均落在此处
      print('配对异常: $e');
    }
    return null;
  }

  Future<bool> verifyDevice(String ip, int port, String deviceId) async {
    final token = await _storage.getToken(deviceId);
    if (token == null) return false;

    final url = 'http://$ip:$port/auth/verify';
    try {
      final response = await _dio.post(url, data: {
        'client_id': _storage.clientId,
        'token': token,
      });
      if (response.data['success'] == true) {
        return true;
      } else {
        // 如果这里显示验证失败，代表 PC 端可能主动点击了移除当前移动端。此时可主动触发清理环境
        await _storage.removeDevice(deviceId);
        return false;
      }
    } catch (e) {
      // 存在网络错误、PC离线情况引发的判定
      return false; 
    }
  }

  Future<bool> connectDevice(String ip, int port, String deviceId) async {
    final token = await _storage.getToken(deviceId);
    if (token == null) return false;
    final url = 'http://$ip:$port/auth/connect';
    try {
      final response = await _dio.post(url, data: {
        'client_id': _storage.clientId,
        'token': token,
      });
      return response.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnectDevice(String ip, int port, String deviceId) async {
    final token = await _storage.getToken(deviceId);
    final url = 'http://$ip:$port/auth/disconnect';
    try {
      await _dio.post(url, data: {
        'client_id': _storage.clientId,
        'token': token ?? '', // 即使失效也发
      });
    } catch (e) {
      // ignore
    }
  }
}

// 供全局提取依赖和扩展鉴权钩子
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  )); // Timeout 30秒对应挂起时的配对等待操作阈值
});

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthApi(dio, storage);
});
