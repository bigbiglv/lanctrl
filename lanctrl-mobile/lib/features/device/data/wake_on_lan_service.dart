import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/domain/app_models.dart';

class WakeOnLanService {
  static const _defaultPort = 9;

  Future<bool> wake(KnownDevice device) async {
    final macBytes = _parseMacAddress(device.macAddress);
    if (macBytes == null) {
      return false;
    }

    final packet = Uint8List(6 + 16 * macBytes.length);
    packet.fillRange(0, 6, 0xFF);
    for (var repeat = 0; repeat < 16; repeat++) {
      packet.setRange(
        6 + repeat * macBytes.length,
        6 + (repeat + 1) * macBytes.length,
        macBytes,
      );
    }

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final targets = _wakeTargets(device);
      for (final target in targets) {
        socket.send(packet, target, _defaultPort);
      }
      return targets.isNotEmpty;
    } catch (error) {
      debugPrint('发送 Wake-on-LAN 数据包失败: $error');
      return false;
    } finally {
      socket?.close();
    }
  }

  List<InternetAddress> _wakeTargets(KnownDevice device) {
    final addresses = <String>{
      if (device.broadcastAddress?.isNotEmpty == true) device.broadcastAddress!,
      '255.255.255.255',
    };

    return addresses
        .map((address) => InternetAddress.tryParse(address))
        .whereType<InternetAddress>()
        .where((address) => address.type == InternetAddressType.IPv4)
        .toList(growable: false);
  }

  Uint8List? _parseMacAddress(String? macAddress) {
    if (macAddress == null || macAddress.trim().isEmpty) {
      return null;
    }

    final normalized = macAddress.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.length != 12) {
      return null;
    }

    final bytes = Uint8List(6);
    for (var index = 0; index < bytes.length; index++) {
      final part = normalized.substring(index * 2, index * 2 + 2);
      final value = int.tryParse(part, radix: 16);
      if (value == null) {
        return null;
      }
      bytes[index] = value;
    }
    return bytes;
  }
}

final wakeOnLanServiceProvider = Provider<WakeOnLanService>((ref) {
  return WakeOnLanService();
});
