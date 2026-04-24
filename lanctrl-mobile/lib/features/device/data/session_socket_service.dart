import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/device/device_identity_service.dart';
import '../../../core/storage/storage_service.dart';
import '../../app/domain/app_models.dart';

class SessionSocketService {
  SessionSocketService._();

  static final SessionSocketService instance = SessionSocketService._();
  static const _heartbeatInterval = Duration(seconds: 8);
  static const _connectTimeout = Duration(seconds: 5);

  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  final StreamController<void> _taskSyncController =
      StreamController<void>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  bool _closing = false;

  Stream<void> get disconnectStream => _disconnectController.stream;
  Stream<void> get taskSyncStream => _taskSyncController.stream;
  bool get isConnected => _channel != null;

  Future<bool> connect(KnownDevice device, StorageService storage) async {
    final token = await storage.getToken(device.deviceId);
    if (token == null) {
      return false;
    }

    await close();

    final clientName = await DeviceIdentityService.currentClientName();
    final uri = Uri(
      scheme: 'ws',
      host: device.ip,
      port: device.port,
      path: '/ws/session',
      queryParameters: <String, String>{
        'client_id': storage.clientId,
        'token': token,
        'client_name': clientName,
      },
    );

    final ready = Completer<bool>();
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _closing = false;

    _subscription = channel.stream.listen(
      (event) {
        _handleMessage(
          event,
          onReady: () {
            if (!ready.isCompleted) {
              ready.complete(true);
            }
          },
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('WebSocket 会话异常: $error');
        if (!ready.isCompleted) {
          ready.complete(false);
        }
        _handleSocketClosed(emitDisconnect: !_closing);
      },
      onDone: () {
        if (!ready.isCompleted) {
          ready.complete(false);
        }
        _handleSocketClosed(emitDisconnect: !_closing);
      },
      cancelOnError: true,
    );

    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => _send(<String, dynamic>{'type': 'heartbeat'}),
    );

    final connected = await ready.future.timeout(
      _connectTimeout,
      onTimeout: () => false,
    );
    if (!connected) {
      await close();
      return false;
    }

    _send(<String, dynamic>{'type': 'request_tasks_sync'});
    return true;
  }

  Future<void> close() async {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    _closing = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _send(<String, dynamic>{'type': 'disconnect'});
    await _subscription?.cancel();
    _subscription = null;
    await channel.sink.close();
    _channel = null;
    _closing = false;
  }

  void _handleMessage(dynamic event, {required VoidCallback onReady}) {
    final payload = switch (event) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes),
      _ => '',
    };
    if (payload.isEmpty) {
      return;
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return;
    }
    final json = decoded.cast<String, dynamic>();

    switch (json['type']) {
      case 'session_ready':
        onReady();
        break;
      case 'tasks_sync':
        _taskSyncController.add(null);
        break;
      case 'disconnect':
        unawaited(close());
        _disconnectController.add(null);
        break;
      default:
        break;
    }
  }

  void _handleSocketClosed({required bool emitDisconnect}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription = null;
    _channel = null;
    _closing = false;

    if (emitDisconnect) {
      _disconnectController.add(null);
    }
  }

  void _send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    try {
      channel.sink.add(jsonEncode(message));
    } catch (error) {
      debugPrint('WebSocket 发送失败: $error');
    }
  }
}
