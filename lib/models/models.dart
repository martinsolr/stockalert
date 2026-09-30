enum ProductStatus { active, paused }

ProductStatus productStatusFromJson(String? value) =>
    value == 'paused' ? ProductStatus.paused : ProductStatus.active;

String productStatusToJson(ProductStatus value) =>
    value == ProductStatus.paused ? 'paused' : 'active';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.stock,
    required this.minimumStock,
    required this.status,
  });

  final int id;
  final String name;
  final String sku;
  final String category;
  final int stock;
  final int minimumStock;
  final ProductStatus status;

  bool get isCritical =>
      status == ProductStatus.active && stock <= minimumStock;
  bool get isOutOfStock => stock == 0;

  Product copyWith({
    String? name,
    String? sku,
    String? category,
    int? stock,
    int? minimumStock,
    ProductStatus? status,
  }) => Product(
    id: id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    category: category ?? this.category,
    stock: stock ?? this.stock,
    minimumStock: minimumStock ?? this.minimumStock,
    status: status ?? this.status,
  );

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    sku: json['sku'] as String,
    category: json['category'] as String,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    minimumStock: (json['minimumStock'] as num?)?.toInt() ?? 0,
    status: productStatusFromJson(json['status'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'sku': sku,
    'category': category,
    'stock': stock,
    'minimumStock': minimumStock,
    'status': productStatusToJson(status),
  };
}

class InventoryAlert {
  const InventoryAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.stock,
    required this.minimumStock,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String productName;
  final String sku;
  final int stock;
  final int minimumStock;
  final String message;
  final String status;
  final DateTime createdAt;

  factory InventoryAlert.fromJson(Map<String, dynamic> json) => InventoryAlert(
    id: (json['id'] as num).toInt(),
    productId: (json['productId'] as num).toInt(),
    productName: json['productName'] as String? ?? 'Produto',
    sku: json['sku'] as String? ?? '',
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    minimumStock: (json['minimumStock'] as num?)?.toInt() ?? 0,
    message: json['message'] as String? ?? '',
    status: json['status'] as String? ?? 'open',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.frequencyMinutes,
    required this.chatId,
    required this.tokenConfigured,
    required this.maskedToken,
    required this.lastCheckAt,
  });

  final bool enabled;
  final int frequencyMinutes;
  final String? chatId;
  final bool tokenConfigured;
  final String? maskedToken;
  final DateTime? lastCheckAt;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        enabled: json['enabled'] == true,
        frequencyMinutes: (json['frequencyMinutes'] as num?)?.toInt() ?? 5,
        chatId: json['chatId'] as String?,
        tokenConfigured: json['tokenConfigured'] == true,
        maskedToken: json['maskedToken'] as String?,
        lastCheckAt: DateTime.tryParse(json['lastCheckAt'] as String? ?? ''),
      );
}

class DashboardData {
  const DashboardData({
    required this.products,
    required this.alerts,
    required this.settings,
  });

  final List<Product> products;
  final List<InventoryAlert> alerts;
  final NotificationSettings settings;

  int get criticalProducts =>
      products.where((product) => product.isCritical).length;
  int get outOfStock =>
      products.where((product) => product.isOutOfStock).length;
  List<Product> get critical =>
      products.where((product) => product.isCritical).toList();

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    products: ((json['products'] as List<dynamic>?) ?? const [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(),
    alerts: ((json['alerts'] as List<dynamic>?) ?? const [])
        .map((item) => InventoryAlert.fromJson(item as Map<String, dynamic>))
        .toList(),
    settings: NotificationSettings.fromJson(
      (json['settings'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

class CheckResult {
  const CheckResult({
    required this.checked,
    required this.created,
    required this.sent,
  });

  final int checked;
  final int created;
  final int sent;

  factory CheckResult.fromJson(Map<String, dynamic> json) => CheckResult(
    checked: (json['checked'] as num?)?.toInt() ?? 0,
    created: (json['created'] as num?)?.toInt() ?? 0,
    sent: (json['sent'] as num?)?.toInt() ?? 0,
  );
}
