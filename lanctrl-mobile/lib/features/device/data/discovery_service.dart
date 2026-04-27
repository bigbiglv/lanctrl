import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../../../core/storage/storage_service.dart';
import '../../app/domain/app_models.dart';

class LanDevice {
  const LanDevice({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    this.macAddress,
    this.broadcastAddress,
  });

  final String deviceId;
  final String name;
  final String ip;
  final int port;
  final String? macAddress;
  final String? broadcastAddress;
}

class DiscoveryService {
  DiscoveryService(this._storage);

  final StorageService _storage;
  final StreamController<List<LanDevice>> _controller =
      StreamController<List<LanDevice>>.broadcast();

  nsd.Discovery? _discovery;
  VoidCallback? _listener;

  Stream<List<LanDevice>> get devicesStream => _controller.stream;

  Future<void> start() async {
    if (_discovery != null) {
      _emitDevices();
      return;
    }

    _controller.add(const <LanDevice>[]);

    _discovery = await nsd.startDiscovery(
      '_lanctrl._tcp',
      ipLookupType: nsd.IpLookupType.any,
    );

    _listener = _emitDevices;
    _discovery?.addListener(_listener!);
    _emitDevices();
  }

  Future<void> stop() async {
    if (_discovery != null) {
      if (_listener != null) {
        _discovery?.removeListener(_listener!);
      }
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
      _listener = null;
    }
  }

  void _emitDevices() {
    final discovery = _discovery;
    if (discovery == null) {
      _controller.add(const <LanDevice>[]);
      return;
    }

    final devicesById = <String, LanDevice>{};
    for (final service in discovery.services) {
      final txt = service.txt;
      if (txt == null || !txt.containsKey('deviceId')) {
        continue;
      }

      try {
        final rawDeviceId = txt['deviceId'];
        if (rawDeviceId == null) {
          continue;
        }

        final deviceId = utf8.decode(rawDeviceId);
        final deviceName = txt['deviceName'] != null
            ? utf8.decode(txt['deviceName']!)
            : (service.name ?? '未知电脑');
        final macAddress = txt['macAddress'] != null
            ? utf8.decode(txt['macAddress']!)
            : null;
        final broadcastAddress = txt['broadcastAddress'] != null
            ? utf8.decode(txt['broadcastAddress']!)
            : null;
        final endpoint = _resolveEndpoint(service);
        final port = service.port ?? 3000;

        if (endpoint == null || endpoint.isEmpty) {
          continue;
        }

        final device = LanDevice(
          deviceId: deviceId,
          name: deviceName,
          ip: endpoint,
          port: port,
          macAddress: macAddress,
          broadcastAddress: broadcastAddress,
        );
        devicesById[deviceId] = device;

        final knownDevice = KnownDevice.fromMap(_storage.getDevice(deviceId));
        if (knownDevice.deviceId.isNotEmpty &&
            (knownDevice.ip != endpoint ||
                knownDevice.port != port ||
                knownDevice.name != deviceName ||
                knownDevice.macAddress != macAddress ||
                knownDevice.broadcastAddress != broadcastAddress)) {
          _storage.saveDevice(
            deviceId,
            deviceName,
            endpoint,
            port,
            macAddress: macAddress,
            broadcastAddress: broadcastAddress,
          );
        }
      } catch (error, stackTrace) {
        debugPrint('局域网设备解析失败: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    _controller.add(devicesById.values.toList(growable: false));
  }

  String? _resolveEndpoint(nsd.Service service) {
    final addresses = service.addresses;
    if (addresses != null && addresses.isNotEmpty) {
      for (final address in addresses) {
        if (address.type.name == 'IPv4' &&
            !address.address.startsWith('127.') &&
            !address.address.startsWith('169.254.')) {
          return address.address;
        }
      }

      for (final address in addresses) {
        if (!address.address.startsWith('127.') &&
            !address.address.startsWith('169.254.')) {
          return address.address;
        }
      }
    }

    final host = service.host;
    if (host == null || host.isEmpty) {
      return null;
    }

    return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
  }
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService(ref.watch(storageServiceProvider));
});
