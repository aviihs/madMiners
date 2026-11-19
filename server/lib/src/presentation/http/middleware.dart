import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';

import '../../application/app_exception.dart';

final _rng = Random();

String _requestId() => List.generate(8, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

const _jsonHeaders = {HttpHeaders.contentTypeHeader: 'application/json'};

Response ok(Object? data, {int status = 200}) =>
    Response(status, body: jsonEncode({'success': true, 'data': data}), headers: _jsonHeaders);

Response errorResponse(AppException e, String requestId) => Response(
  e.status,
  body: jsonEncode({
    'success': false,
    'error': {'code': e.code, 'message': e.message, 'requestId': requestId},
  }),
  headers: _jsonHeaders,
);

/// Maps exceptions to the standard error envelope (SRS §8.7).
Middleware errorHandling() => (inner) => (request) async {
  final id = _requestId();
  try {
    return await inner(request.change(context: {'requestId': id}));
  } on AppException catch (e) {
    return errorResponse(e, id);
  } on FormatException {
    return errorResponse(AppException.badRequest('INVALID_JSON', 'Malformed request body.'), id);
  } catch (e, st) {
    stderr.writeln('[$id] $e\n$st');
    return errorResponse(const AppException(500, 'INTERNAL', 'Something went wrong.'), id);
  }
};

Middleware cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
  return (inner) => (request) async {
    if (request.method == 'OPTIONS') return Response.ok('', headers: headers);
    final res = await inner(request);
    return res.change(headers: headers);
  };
}

/// Fixed-window limiter per client IP (NFR-014).
Middleware rateLimit({int perWindow = 60, Duration window = const Duration(seconds: 10)}) {
  final hits = <String, (DateTime, int)>{};
  return (inner) => (request) {
    if (request.url.path.startsWith('ws/')) return inner(request);
    final info = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final ip = info?.remoteAddress.address ?? 'unknown';
    final now = DateTime.now();
    final (start, count) = hits[ip] ?? (now, 0);
    final fresh = now.difference(start) > window;
    final next = fresh ? (now, 1) : (start, count + 1);
    hits[ip] = next;
    if (hits.length > 10000) hits.removeWhere((_, v) => now.difference(v.$1) > window);
    if (next.$2 > perWindow) throw AppException.rateLimited;
    return inner(request);
  };
}

Future<Map<String, dynamic>> readJson(Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return {};
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) throw const FormatException();
  return decoded;
}

String? bearerToken(Request request) {
  final h = request.headers[HttpHeaders.authorizationHeader];
  if (h == null || !h.startsWith('Bearer ')) return null;
  return h.substring(7).trim();
}
