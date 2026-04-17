import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd_pkg;
import '../../../core/storage/storage_service.dart';
import 'dart:async';
import 'dart:convert';

class LanDevice {
  final String deviceId;
  final String name;
  final String ip;
  final int port;

  LanDevice(this.deviceId, this.name, this.ip, this.port);
}

class DiscoveryService {
  final StorageService storage;
  nsd_pkg.Discovery? _discovery;
  final StreamController<List<LanDevice>> _controller = StreamController.broadcast();
  List<LanDevice> _foundDevices = [];

  DiscoveryService(this.storage);

  Stream<List<LanDevice>> get devicesStream => _controller.stream;

  Future<void> start() async {
    _foundDevices = [];
    _controller.add(_foundDevices);
    
    _discovery = await nsd_pkg.startDiscovery('_lanctrl._tcp', ipLookupType: nsd_pkg.IpLookupType.v4);
    _discovery!.addListener(() {
      _foundDevices = [];
      for (var service in _discovery!.services) {
        if (service.txt != null && service.txt!.containsKey('deviceId')) {
          try {
            // TXT values are commonly Uint8List in nsd
            final deviceId = utf8.decode(service.txt!['deviceId']!);
            final deviceName = service.txt!.containsKey('deviceName') 
                ? utf8.decode(service.txt!['deviceName']!) 
                : 'Unknown PC';
            
            final ip = service.host ?? '';
            final port = service.port ?? 3000;

            if (ip.isNotEmpty) {
              _foundDevices.add(LanDevice(deviceId, deviceName, ip, port));
              
              // 自动识别由于局域网路由造成的动态 IP 变动并覆写维持失联设备状态
              var known = storage.getDevice(deviceId);
              if (known.isNotEmpty && known['ip'] != ip) {
                storage.saveDevice(deviceId, deviceName, ip, port);
              }
            }
          } catch(e) {
            // 解析错误则略过异常设备
          }
        }
      }
      _controller.add(List.from(_foundDevices));
    });
  }

  Future<void> stop() async {
    if (_discovery != null) {
      await nsd_pkg.stopDiscovery(_discovery!);
      _discovery = null;
    }
  }
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return DiscoveryService(storage);
});
