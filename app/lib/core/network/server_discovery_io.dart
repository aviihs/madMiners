import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _discoveryPort = 41234;

/// Listens for the server's LAN broadcast and returns `http://ip:port`.
Future<String?> listenForLanServer({Duration timeout = const Duration(seconds: 3)}) async {
  // Widget tests run in fake time; a real socket there would never close.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
    socket.broadcastEnabled = true;
    final found = Completer<String?>();
    final sub = socket.listen((event) {
      if (event != RawSocketEvent.read || found.isCompleted) return;
      final dg = socket!.receive();
      if (dg == null) return;
      try {
        final j = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        if (j['mm'] == 'mad-miners') found.complete('http://${dg.address.address}:${j['port']}');
      } catch (_) {}
    });
    final result = await found.future.timeout(timeout, onTimeout: () => null);
    await sub.cancel();
    return result;
  } catch (_) {
    return null;
  } finally {
    socket?.close();
  }
}
