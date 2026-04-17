import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'core/storage/storage_service.dart';
import 'features/device/presentation/device_page.dart';

class PingServer {
  static HttpServer? _server;
  static final StreamController<void> disconnectStream = StreamController<void>.broadcast();

  static Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 3001);
      _server!.listen((HttpRequest request) {
        request.response.headers.add('Access-Control-Allow-Origin', '*'); 
        if (request.uri.path == '/ping') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('pong')
            ..close();
        } else if (request.uri.path == '/disconnect') {
          disconnectStream.add(null);
          request.response
            ..statusCode = HttpStatus.ok
            ..close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });
    } catch (e) {
      debugPrint('移动端微服务占用/异常: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  PingServer.start();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const LanCtrlApp(),
    ),
  );
}

class LanCtrlApp extends StatelessWidget {
  const LanCtrlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanCtrl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DevicePage(),
    const Center(child: Text('定时任务 (待开发)\n此处将展示配置的定时任务列表', textAlign: TextAlign.center)),
    const Center(child: Text('操作日志 (待开发)\n此处将展示近期的控制与访问日志', textAlign: TextAlign.center)),
    const Center(child: Text('应用设置 (待开发)\n此处将展示基础参数配置', textAlign: TextAlign.center)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // 固定文字显示
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: '设备',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: '任务',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: '日志',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
