import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/app/app_controller.dart';
import 'features/app/presentation/app_root_page.dart';
import 'features/device/data/session_socket_service.dart';

class PingServer {
  static HttpServer? _server;
  static final StreamController<void> disconnectStream =
      StreamController<void>.broadcast();
  static final StreamController<void> taskChangedStream =
      StreamController<void>.broadcast();

  static Future<void> start() async {
    if (_server != null) {
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 3001);
      _server?.listen((request) {
        request.response.headers.add('Access-Control-Allow-Origin', '*');

        if (request.uri.path == '/ping') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('pong')
            ..close();
          return;
        }

        if (request.uri.path == '/disconnect') {
          disconnectStream.add(null);
          request.response
            ..statusCode = HttpStatus.ok
            ..close();
          return;
        }

        if (request.uri.path == '/tasks-changed') {
          taskChangedStream.add(null);
          request.response
            ..statusCode = HttpStatus.ok
            ..close();
          return;
        }

        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      });
    } catch (error) {
      debugPrint('移动端心跳服务启动失败: $error');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await StorageService.init();
  await PingServer.start();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const LanCtrlApp(),
    ),
  );
}

class LanCtrlApp extends ConsumerWidget {
  const LanCtrlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);

    return MaterialApp(
      title: 'LanCtrl',
      debugShowCheckedModeBanner: false,
      themeMode: themeModeFromPreference(state.themeMode),
      theme: buildAppTheme(state.theme, Brightness.light),
      darkTheme: buildAppTheme(state.theme, Brightness.dark),
      home: LanCtrlRootPage(
        disconnectStreams: [
          PingServer.disconnectStream.stream,
          SessionSocketService.instance.disconnectStream,
        ],
        taskChangedStreams: [
          PingServer.taskChangedStream.stream,
          SessionSocketService.instance.taskSyncStream,
        ],
      ),
    );
  }
}
