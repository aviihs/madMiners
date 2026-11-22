import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const _discoveryPort = 41234;

/// Android only delivers Wi-Fi broadcasts while a multicast lock is held
/// (see MainActivity.kt). Other platforms don't need it.
const _lan = MethodChannel('mad_miners/lan');

Future<void> _lock(bool on) async {
  if (!Platform.isAndroid) return;
  try {
    await _lan.invokeMethod<bool>(on ? 'acquire' : 'release');
  } catch (_) {}
}

/// Listens for the server's LAN broadcast and returns `http://ip:port`.
Future<String?> listenForLanServer({Duration timeout = const Duration(seconds: 3)}) async {
  // Widget tests run in fake time; a real socket there would never close.
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  RawDatagramSocket? socket;
  await _lock(true);
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
    unawaited(_lock(false));
  }
}
