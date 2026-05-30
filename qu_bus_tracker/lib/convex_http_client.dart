import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'convex_config.dart';

/// Lightweight Convex client using the HTTP API (no native Rust dependency).
class ConvexHttpClient {
  ConvexHttpClient._();

  static final ConvexHttpClient instance = ConvexHttpClient._();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String get _baseUrl => QuConvexConfig.deploymentUrl;

  Future<void> ping() async {
    await query('health:ping', {});
    _isConnected = true;
  }

  Future<dynamic> query(
    String name,
    Map<String, dynamic> args,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/query'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'path': name,
        'args': args,
        'format': 'json',
      }),
    );

    if (response.statusCode != 200) {
      _isConnected = false;
      throw Exception('Convex query failed (${response.statusCode}): ${response.body}');
    }

    _isConnected = true;
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('value')) {
      return decoded['value'];
    }
    return decoded;
  }

  Future<dynamic> mutation(
    String name,
    Map<String, dynamic> args,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/mutation'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'path': name,
        'args': args,
        'format': 'json',
      }),
    );

    if (response.statusCode != 200) {
      _isConnected = false;
      throw Exception('Convex mutation failed (${response.statusCode}): ${response.body}');
    }

    _isConnected = true;
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded.containsKey('value')) {
      return decoded['value'];
    }
    return decoded;
  }

  void markDisconnected() {
    _isConnected = false;
  }
}
