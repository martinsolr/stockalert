import 'dart:convert';
import 'dart:io';

class InventoryStore {
  InventoryStore(this.filePath);

  final String filePath;
  Map<String, dynamic> _state = {};

  Future<void> load() async {
    final file = File(filePath);
    if (await file.exists()) {
      _state = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return;
    }
    _state = {
      'nextProductId': 6,
      'nextAlertId': 1,
      'nextMovementId': 1,
      'products': [
        _product(1, 'Café especial 250g', 'CAF-250', 'Mercearia', 6, 10),
        _product(2, 'Leite integral 1L', 'LEI-1L', 'Laticínios', 24, 12),
        _product(3, 'Biscoito de aveia', 'BIS-AVE', 'Mercearia', 8, 8),
        _product(4, 'Sabonete líquido 300ml', 'SAB-300', 'Higiene', 42, 15),
        _product(5, 'Água mineral 500ml', 'AGU-500', 'Bebidas', 0, 20),
      ],
      'movements': <Map<String, dynamic>>[],
      'alerts': <Map<String, dynamic>>[],
      'settings': {
        'botToken': '',
        'chatId': '',
        'enabled': false,
        'frequencyMinutes': 5,
        'lastCheckAt': null
      },
    };
    await save();
  }

  Future<void> save() async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(_state));
  }

  List<Map<String, dynamic>> get products =>
      ((_state['products'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get alerts =>
      ((_state['alerts'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get movements =>
      ((_state['movements'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();
  Map<String, dynamic> get settings =>
      (_state['settings'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> dashboard() => {
        'products': products,
        'alerts': alerts
            .where((alert) => alert['status'] != 'resolved')
            .map(_withProductInfo)
            .toList()
            .reversed
            .toList(),
        'stats': {
          'totalProducts': products.length,
          'criticalProducts': products.where(_isCritical).length,
          'outOfStock':
              products.where((product) => product['stock'] == 0).length,
          'healthyProducts':
              products.where((product) => !_isCritical(product)).length,
        },
        'settings': publicSettings(),
      };

  Map<String, dynamic> publicSettings() {
    final token = settings['botToken'] as String? ?? '';
    return {
      'enabled': settings['enabled'] == true,
      'frequencyMinutes': settings['frequencyMinutes'] ?? 5,
      'chatId': (settings['chatId'] as String?)?.isNotEmpty == true
          ? settings['chatId']
          : null,
      'tokenConfigured': token.isNotEmpty,
      'maskedToken': token.isEmpty
          ? null
          : '${token.substring(0, token.length > 5 ? 5 : token.length)}•••',
      'lastCheckAt': settings['lastCheckAt'],
    };
  }

  Map<String, dynamic> createProduct(Map<String, dynamic> input) {
    final sku = (input['sku'] as String).trim().toUpperCase();
    if (products.any((product) => product['sku'] == sku))
      throw StateError('SKU já cadastrado.');
    final product = _product(
      (_state['nextProductId'] as num).toInt(),
      (input['name'] as String).trim(),
      sku,
      (input['category'] as String).trim(),
      (input['stock'] as num).toInt(),
      (input['minimumStock'] as num).toInt(),
      status: input['status'] as String? ?? 'active',
    );
    _state['nextProductId'] = (_state['nextProductId'] as num).toInt() + 1;
    products.add(product);
    return product;
  }

  Map<String, dynamic> updateProduct(int id, Map<String, dynamic> input) {
    final product = findProduct(id);
    final nextSku = ((input['sku'] as String?) ?? product['sku'] as String)
        .trim()
        .toUpperCase();
    if (products.any((item) => item['id'] != id && item['sku'] == nextSku))
      throw StateError('SKU já cadastrado.');
    product
      ..['name'] =
          ((input['name'] as String?) ?? product['name']).toString().trim()
      ..['sku'] = nextSku
      ..['category'] = ((input['category'] as String?) ?? product['category'])
          .toString()
          .trim()
      ..['stock'] = (input['stock'] as num?)?.toInt() ?? product['stock']
      ..['minimumStock'] =
          (input['minimumStock'] as num?)?.toInt() ?? product['minimumStock']
      ..['status'] = input['status'] ?? product['status']
      ..['updatedAt'] = _now();
    return product;
  }

  Map<String, dynamic> findProduct(int id) {
    final matches = products.where((product) => product['id'] == id);
    if (matches.isEmpty) throw StateError('Produto não encontrado.');
    return matches.first;
  }

  Map<String, dynamic> adjustStock(int id, int change, String reason) {
    final product = findProduct(id);
    final previous = (product['stock'] as num).toInt();
    final next = (previous + change).clamp(0, 1000000);
    product['stock'] = next;
    product['updatedAt'] = _now();
    movements.add({
      'id': _next('nextMovementId'),
      'productId': id,
      'change': next - previous,
      'stockAfter': next,
      'reason': reason,
      'createdAt': _now()
    });
    return product;
  }

  void deleteProduct(int id) {
    findProduct(id);
    products.removeWhere((product) => product['id'] == id);
    movements.removeWhere((movement) => movement['productId'] == id);
    alerts.removeWhere((alert) => alert['productId'] == id);
  }

  Map<String, dynamic> saveSettings(Map<String, dynamic> input) {
    final token = (input['botToken'] as String?)?.trim();
    if (token != null && token.isNotEmpty) settings['botToken'] = token;
    settings
      ..['chatId'] =
          (input['chatId'] as String? ?? settings['chatId'] ?? '').trim()
      ..['enabled'] = input['enabled'] == true
      ..['frequencyMinutes'] =
          (input['frequencyMinutes'] as num?)?.toInt() ?? 5;
    return publicSettings();
  }

  Future<Map<String, dynamic>> checkStocks(
      Future<bool> Function(String token, String chatId, String text)
          sendTelegram) async {
    var created = 0;
    var sent = 0;
    var resolved = 0;
    final active = <int>{};
    for (final product
        in products.where((product) => product['status'] == 'active')) {
      final critical = _isCritical(product);
      final open = alerts
          .where((alert) =>
              alert['productId'] == product['id'] &&
              alert['status'] != 'resolved')
          .toList();
      if (critical) {
        active.add(product['id'] as int);
        final alert = open.isEmpty ? _createAlert(product) : open.last;
        if (open.isEmpty) created++;
        final token = settings['botToken'] as String? ?? '';
        final chatId = settings['chatId'] as String? ?? '';
        if (settings['enabled'] == true &&
            token.isNotEmpty &&
            chatId.isNotEmpty &&
            alert['status'] == 'open') {
          final ok =
              await sendTelegram(token, chatId, alert['message'] as String);
          if (ok) {
            alert['status'] = 'sent';
            alert['sentAt'] = _now();
            sent++;
          } else {
            alert['status'] = 'failed';
          }
        }
      } else if (open.isNotEmpty) {
        for (final alert in open) {
          alert['status'] = 'resolved';
          alert['resolvedAt'] = _now();
          resolved++;
        }
      }
    }
    settings['lastCheckAt'] = _now();
    await save();
    return {
      'checked': products.length,
      'created': created,
      'sent': sent,
      'resolved': resolved,
      'failed': 0,
      'checkedAt': settings['lastCheckAt']
    };
  }

  Map<String, dynamic> _createAlert(Map<String, dynamic> product) {
    final stock = (product['stock'] as num).toInt();
    final minimum = (product['minimumStock'] as num).toInt();
    final alert = {
      'id': _next('nextAlertId'),
      'productId': product['id'],
      'severity': 'critical',
      'status': 'open',
      'message': stock == 0
          ? '🚨 Sem estoque: ${product['name']} (${product['sku']}). Reposição necessária agora.'
          : '⚠️ Estoque baixo: ${product['name']} (${product['sku']}) está com $stock unidade(s). Mínimo: $minimum.',
      'sentAt': null,
      'resolvedAt': null,
      'createdAt': _now()
    };
    alerts.add(alert);
    return alert;
  }

  Map<String, dynamic> _withProductInfo(Map<String, dynamic> alert) {
    final product =
        products.where((item) => item['id'] == alert['productId']).firstOrNull;
    return {
      ...alert,
      'productName': product?['name'] ?? 'Produto',
      'sku': product?['sku'] ?? '',
      'stock': product?['stock'] ?? 0,
      'minimumStock': product?['minimumStock'] ?? 0
    };
  }

  bool _isCritical(Map<String, dynamic> product) =>
      product['status'] == 'active' &&
      (product['stock'] as num).toInt() <=
          (product['minimumStock'] as num).toInt();
  int _next(String key) {
    final value = (_state[key] as num).toInt();
    _state[key] = value + 1;
    return value;
  }

  static String _now() => DateTime.now().toUtc().toIso8601String();

  static Map<String, dynamic> _product(int id, String name, String sku,
          String category, int stock, int minimumStock,
          {String status = 'active'}) =>
      {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'stock': stock,
        'minimumStock': minimumStock,
        'status': status,
        'createdAt': _now(),
        'updatedAt': _now()
      };
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
