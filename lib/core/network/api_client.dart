import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _headers({bool jsonContent = false}) async {
    final token = await _tokenStorage.readToken();
    final headers = <String, String>{};
    if (jsonContent) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');

  Future<http.Response> get(String path) async {
    return http.get(_uri(path), headers: await _headers());
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    return http.post(
      _uri(path),
      headers: await _headers(jsonContent: true),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch(String path, {Map<String, dynamic>? body}) async {
    return http.patch(
      _uri(path),
      headers: await _headers(jsonContent: true),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    return http.put(
      _uri(path),
      headers: await _headers(jsonContent: true),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.StreamedResponse> multipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(await _headers());
    req.fields.addAll(fields);
    req.files.addAll(files);
    return req.send();
  }

  static Map<String, dynamic> decodeJsonMap(String raw) {
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
