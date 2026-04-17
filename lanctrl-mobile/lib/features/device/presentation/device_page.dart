import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../data/discovery_service.dart';
import '../data/auth_api.dart';
import '../../../core/storage/storage_service.dart';
import 'package:dio/dio.dart';
import '../../../main.dart';

// 已知设备状态管理
class KnownDevicesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    return ref.watch(storageServiceProvider).getAllKnownDevices();
  }

  void refresh() {
    state = ref.read(storageServiceProvider).getAllKnownDevices();
  }
}

final knownDevicesProvider = NotifierProvider<KnownDevicesNotifier, List<Map<String, dynamic>>>(() {
  return KnownDevicesNotifier();
});

// 当前已连接的桌面 deviceId 集合（支持多台同时连接）
class ConnectedDevicesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void connect(String deviceId) => state = {...state, deviceId};
  void disconnect(String deviceId) => state = state.where((id) => id != deviceId).toSet();
  bool isConnected(String deviceId) => state.contains(deviceId);
}

final connectedDevicesProvider = NotifierProvider<ConnectedDevicesNotifier, Set<String>>(() {
  return ConnectedDevicesNotifier();
});

class DevicePage extends ConsumerStatefulWidget {
  const DevicePage({super.key});

  @override
  ConsumerState<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends ConsumerState<DevicePage> {
  bool _isPairing = false;
  bool _isProbing = false;
  final TextEditingController _ipController = TextEditingController();
  Timer? _autoRefreshTimer;

  // 每台设备的在线状态缓存
  final Map<String, bool> _onlineStatus = {};

  @override
  void initState() {
    super.initState();
    // 用 microtask 确保 Riverpod provider 完全就绪后再探测
    Future.microtask(() => _probeAllDevices());
    // 每 30 秒自动刷新一次
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _probeAllDevices());

    // 监听来自 PC 的断开推送请求，若收到则先粗暴断开本地全部再重新探测一波
    PingServer.disconnectStream.stream.listen((_) {
      ref.read(connectedDevicesProvider.notifier).state = {};
      _probeAllDevices();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// 并发探测所有已知设备的在线状态
  Future<void> _probeAllDevices() async {
    if (_isProbing) return; // 防止并发重入
    setState(() => _isProbing = true);
    final devices = ref.read(knownDevicesProvider);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(milliseconds: 1200),
      receiveTimeout: const Duration(milliseconds: 1200),
    ));

    final futures = devices.map((dev) async {
      // 优先用存储的 ip 字段，兼容旧格式和新格式
      final ip = (dev['ip'] as String?) ?? '';
      if (ip.isEmpty) {
        _onlineStatus[dev['deviceId']] = false;
        return;
      }
      try {
        await dio.post('http://$ip:3000/auth/verify', data: {'client_id': '', 'token': ''});
        _onlineStatus[dev['deviceId']] = true;
      } on DioException catch (e) {
        // 收到 HTTP 响应则端口存活（哪怕是认证失败）
        _onlineStatus[dev['deviceId']] = e.response != null;
      } catch (_) {
        _onlineStatus[dev['deviceId']] = false;
      }
    });

    await Future.wait(futures);
    if (mounted) setState(() => _isProbing = false);
  }

  /// 连接到指定桌面
  Future<void> _connectToDevice(Map<String, dynamic> device) async {
    final deviceId = device['deviceId'] as String;
    final isAlreadyConnected = ref.read(connectedDevicesProvider).contains(deviceId);
    if (isAlreadyConnected) return; // 已经在连接中

    // 调用连接 API
    final api = ref.read(authApiProvider);
    final ok = await api.connectDevice(device['ip'], device['port'], deviceId);
    if (ok) {
      ref.read(connectedDevicesProvider.notifier).connect(deviceId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已连接到 ${device['name']}')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接失败，可能设备离线或已解除配对')));
    }
  }

  /// 断开指定设备连接
  Future<void> _disconnectDevice(Map<String, dynamic> device) async {
    final deviceId = device['deviceId'] as String;
    ref.read(connectedDevicesProvider.notifier).disconnect(deviceId);
    final api = ref.read(authApiProvider);
    await api.disconnectDevice(device['ip'], device['port'], deviceId);
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已断开连接')));
  }

  /// 忘记设备（带二次确认）
  Future<void> _forgetDevice(Map<String, dynamic> device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消信任'),
        content: Text('确定要忘记「${device['name']}」吗？\n\n如果当前正在连接，将会断开该设备的控制。忘记后将清除本地保存的凭证，下次需要重新在电脑端确认配对。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定忘记', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // 如果该设备是当前连接的，先发出断开指令并清除本地状态
    if (ref.read(connectedDevicesProvider).contains(device['deviceId'])) {
      await _disconnectDevice(device);
    }
    await ref.read(storageServiceProvider).removeDevice(device['deviceId']);
    ref.read(knownDevicesProvider.notifier).refresh();
    _onlineStatus.remove(device['deviceId']);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已忘记该设备')));
  }

  /// 配对新设备（从扫描弹窗中触发）
  Future<void> _pairDevice(LanDevice device) async {
    Navigator.pop(context); // 关闭扫描弹窗
    setState(() => _isPairing = true);
    final api = ref.read(authApiProvider);
    final token = await api.pairDevice(device.ip, device.port, device.name, device.deviceId);
    setState(() => _isPairing = false);

    if (token != null) {
      ref.read(knownDevicesProvider.notifier).refresh();
      await _probeAllDevices();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配对成功！设备已加入受信任列表。')));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配对失败：请求超时或被电脑端拒绝。')));
    }
  }

  /// 打开扫描弹窗
  void _openScanDialog() {
    ref.read(discoveryServiceProvider).start();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('探寻局域网设备'),
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: StreamBuilder<List<LanDevice>>(
                stream: ref.read(discoveryServiceProvider).devicesStream,
                builder: (context, snapshot) {
                  final devices = snapshot.data ?? [];
                  final knownDevices = ref.read(knownDevicesProvider);
                  final unknownDevices = devices.where((d) => !knownDevices.any((k) => k['deviceId'] == d.deviceId)).toList();

                  if (unknownDevices.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 48, color: Colors.black26),
                          SizedBox(height: 16),
                          Text('正在扫描中...尚未发现新设备', style: TextStyle(color: Colors.black38)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: unknownDevices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dev = unknownDevices[index];
                      return ListTile(
                        leading: const Icon(Icons.desktop_windows, color: Colors.blueGrey),
                        title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${dev.ip}:${dev.port}'),
                        trailing: ElevatedButton(
                          onPressed: () => _pairDevice(dev),
                          child: const Text('配对'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              // 手动输入 IP 的小入口
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('手动输入IP'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showManualIPDialog();
                },
              ),
              TextButton(
                onPressed: () {
                  ref.read(discoveryServiceProvider).stop();
                  Navigator.pop(ctx);
                },
                child: const Text('关闭'),
              ),
            ],
          );
        });
      },
    ).then((_) {
      ref.read(discoveryServiceProvider).stop();
    });
  }

  /// 手动输入 IP 弹窗
  void _showManualIPDialog() {
    _ipController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('手动输入 IP 配对'),
          content: TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              hintText: '例如: 192.168.1.100',
              labelText: '桌面端 IP 地址',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final ip = _ipController.text.trim();
                if (ip.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() => _isPairing = true);
                  ref.read(authApiProvider).pairDevice(ip, 3000, '未知桌面(直连)', 'manual').then((token) {
                    setState(() => _isPairing = false);
                    if (token != null) {
                      ref.read(knownDevicesProvider.notifier).refresh();
                      _probeAllDevices();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配对成功！')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配对失败或被拒绝。')));
                    }
                  });
                }
              },
              child: const Text('发起配对'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final knownDevices = ref.watch(knownDevicesProvider);
    final connectedIds = ref.watch(connectedDevicesProvider); // Set<String>
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备控制中心'),
        actions: [
          // 手动刷新在线状态
          if (_isProbing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _probeAllDevices,
              tooltip: '刷新在线状态',
            ),
          IconButton(
            icon: const Icon(Icons.sensors),
            onPressed: _openScanDialog,
            tooltip: '探寻内网设备',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _probeAllDevices,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('受信任的桌面 (${knownDevices.length})',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (knownDevices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.devices_other, size: 56, color: Colors.black12),
                          SizedBox(height: 16),
                          Text('暂无受信任的桌面\n点击右上角搜索按钮开始配对', textAlign: TextAlign.center, style: TextStyle(color: Colors.black38)),
                        ],
                      ),
                    ),
                  ),
                ...knownDevices.map((dev) {
                  final deviceId = dev['deviceId'] as String;
                  final isConnected = connectedIds.contains(deviceId);
                  final isOnline = _onlineStatus[deviceId] ?? false;
                  return Card(
                    elevation: isConnected ? 3 : 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: isConnected
                        ? theme.primaryColor.withOpacity(0.08)
                        : (isOnline ? Colors.green.withOpacity(0.03) : Colors.grey.withOpacity(0.03)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isConnected
                          ? BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline ? Colors.green : Colors.grey.shade400,
                              boxShadow: isOnline ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 6)] : [],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: isConnected ? theme.primaryColor : (isOnline ? Colors.green.shade50 : Colors.grey.shade200),
                            child: Icon(Icons.computer, color: isConnected ? Colors.white : (isOnline ? Colors.green : Colors.grey)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(dev['name'] ?? '未知', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isConnected ? theme.primaryColor : null))),
                                    if (isConnected)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
                                        child: const Text('已连接', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('IP: ${dev['ip']} · ${isOnline ? '在线' : '离线'}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          // 操作按钮
                          if (isConnected)
                            TextButton(
                              onPressed: () => _disconnectDevice(dev),
                              child: const Text('断开', style: TextStyle(color: Colors.orange)),
                            )
                          else if (isOnline)
                            TextButton(
                              onPressed: () => _connectToDevice(dev),
                              child: Text('连接', style: TextStyle(color: theme.primaryColor)),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'forget') _forgetDevice(dev);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'forget', child: Text('忘记设备', style: TextStyle(color: Colors.redAccent))),
                            ],
                          ),

                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // 配对遮罩
          if (_isPairing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text('等待电脑端确认...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('请在目标电脑上点击「允许」完成配对', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
