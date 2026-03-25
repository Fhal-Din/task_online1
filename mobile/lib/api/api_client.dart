import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({required this.baseUrl});

  void setToken(String? token) {
    _token = token;
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final resp = await http.get(uri, headers: _headers());
    return _decode(resp);
  }

  Future<dynamic> postJson(String path, Object body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    return _decode(resp);
  }

  Future<dynamic> putJson(String path, Object body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.put(uri, headers: _headers(), body: jsonEncode(body));
    return _decode(resp);
  }

  Future<dynamic> deleteJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.delete(uri, headers: _headers());
    return _decode(resp);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(resp.body);
    }
    String message;
    try {
      final obj = jsonDecode(resp.body);
      message = (obj is Map && obj['error'] is String) ? obj['error'] as String : resp.body;
    } catch (_) {
      message = resp.body.isNotEmpty ? resp.body : 'Request failed';
    }
    throw ApiException(resp.statusCode, message);
  }
}

