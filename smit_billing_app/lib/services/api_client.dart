import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'https://demo.billing.smit34.ru/mobile-api/v1';
  final _storage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;

  Future<void> loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.deleteAll();
  }

  bool get isAuthenticated => _accessToken != null;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        await saveTokens(
          data['access'],
          data['refresh'] ?? _refreshToken!,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> login(String contract, String password) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'contract': contract, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      await saveTokens(data['access'], data['refresh']);
      return data;
    }
    final error = jsonDecode(resp.body);
    throw ApiException(error['detail'] ?? 'Ошибка авторизации', resp.statusCode);
  }

  Future<Map<String, dynamic>> get(String path) async {
    var resp = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders,
    );
    if (resp.statusCode == 401 && await _refreshAccessToken()) {
      resp = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders,
      );
    }
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw ApiException(
      _parseError(resp.body),
      resp.statusCode,
    );
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    var resp = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
    if (resp.statusCode == 401 && await _refreshAccessToken()) {
      resp = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders,
        body: body != null ? jsonEncode(body) : null,
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body);
    }
    throw ApiException(
      _parseError(resp.body),
      resp.statusCode,
    );
  }

  Future<Map<String, dynamic>> delete(String path) async {
    var resp = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _authHeaders,
    );
    if (resp.statusCode == 401 && await _refreshAccessToken()) {
      resp = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: _authHeaders,
      );
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body);
    }
    throw ApiException(
      _parseError(resp.body),
      resp.statusCode,
    );
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail'] ?? 'Ошибка сервера';
    } catch (_) {
      return 'Ошибка сервера';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
