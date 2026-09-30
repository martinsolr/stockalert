import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:8080/api',
                  ))
              .replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Future<DashboardData> fetchDashboard() async {
    final json = await _get('/dashboard');
    return DashboardData.fromJson(json);
  }

  Future<List<Product>> fetchProducts() async {
    final json = await _get('/products');
    return (json['products'] as List<dynamic>? ?? const [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createProduct({
    required String name,
    required String sku,
    required String category,
    required int stock,
    required int minimumStock,
    required ProductStatus status,
  }) async {
    final json = await _send(
      'POST',
      '/products',
      body: {
        'name': name,
        'sku': sku,
        'category': category,
        'stock': stock,
        'minimumStock': minimumStock,
        'status': productStatusToJson(status),
      },
    );
    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  Future<Product> updateProduct(Product product) async {
    final json = await _send(
      'PATCH',
      '/products/${product.id}',
      body: product.toJson(),
    );
    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) async => _send('DELETE', '/products/$id');

  Future<Product> adjustStock({
    required int id,
    required int change,
    required String reason,
  }) async {
    final json = await _send(
      'POST',
      '/products/$id/adjust',
      body: {'change': change, 'reason': reason},
    );
    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  Future<CheckResult> checkAlerts() async {
    final json = await _send('POST', '/alerts/check');
    return CheckResult.fromJson(json);
  }

  Future<NotificationSettings> fetchSettings() async {
    final json = await _get('/settings');
    return NotificationSettings.fromJson(
      json['settings'] as Map<String, dynamic>,
    );
  }

  Future<NotificationSettings> saveSettings({
    required String token,
    required String chatId,
    required bool enabled,
    required int frequencyMinutes,
  }) async {
    final json = await _send(
      'PUT',
      '/settings',
      body: {
        if (token.trim().isNotEmpty) 'botToken': token.trim(),
        'chatId': chatId.trim(),
        'enabled': enabled,
        'frequencyMinutes': frequencyMinutes,
      },
    );
    return NotificationSettings.fromJson(
      json['settings'] as Map<String, dynamic>,
    );
  }

  Future<void> testTelegram({
    required String token,
    required String chatId,
  }) async {
    await _send(
      'POST',
      '/settings/test',
      body: {'botToken': token.trim(), 'chatId': chatId.trim()},
    );
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(_headers);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> get _headers => const {'accept': 'application/json'};

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException(
          'Resposta inválida do servidor.',
          statusCode: response.statusCode,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['error'] as String? ?? 'Não foi possível concluir a operação.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }
}
