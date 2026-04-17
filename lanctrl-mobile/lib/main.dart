import 'package:flutter/material.dart';

void main() {
  runApp(const LanCtrlApp());
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
    const Center(child: Text('设备概览 (待开发)\n此处将展示局域网内所有在线和离线电脑', textAlign: TextAlign.center)),
    const Center(child: Text('定时任务 (待开发)\n此处将展示配置的定时任务列表', textAlign: TextAlign.center)),
    const Center(child: Text('操作日志 (待开发)\n此处将展示近期的控制与访问日志', textAlign: TextAlign.center)),
    const Center(child: Text('应用设置 (待开发)\n此处将展示基础参数配置', textAlign: TextAlign.center)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LanCtrl 控制中心'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
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
