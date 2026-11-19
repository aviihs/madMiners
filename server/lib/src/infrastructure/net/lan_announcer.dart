import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Broadcasts "a Mad Miners server is here" on the local network every two
/// seconds so phones on the same Wi‑Fi can find it without typing an IP.
class LanAnnouncer {
  LanAnnouncer({required this.httpPort, this.discoveryPort = defaultDiscoveryPort});

  static const defaultDiscoveryPort = 41234;

  final int httpPort;
  final int discoveryPort;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)..broadcastEnabled = true;
    } catch (e) {
      stderr.writeln('LAN discovery disabled: $e');
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _announce());
    await _announce();
  }

  Future<void> _announce() async {
    final payload = utf8.encode(jsonEncode({'mm': 'mad-miners', 'port': httpPort}));
    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (a.isLoopback) continue;
          final p = a.address.split('.');
          targets.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255')); // assume /24 home network
        }
      }
    } catch (_) {}
    for (final t in targets) {
      try {
        _socket?.send(payload, t, discoveryPort);
      } catch (_) {}
    }
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
  }
}
