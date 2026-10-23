double parseNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0; // backend Decimal'ni satr sifatida yuboradi
}

enum Role {
  admin('admin', 'Admin'),
  kassir('kassir', 'Kassir'),
  ishchi('ishchi', 'Ishchi');

  const Role(this.code, this.label);
  final String code;
  final String label;

  static Role fromCode(String c) =>
      Role.values.firstWhere((r) => r.code == c, orElse: () => Role.ishchi);
}

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final Role role;
  final bool isActive;
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.isActive = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] ?? '').toString(),
        fullName: (j['full_name'] ?? j['username'] ?? '').toString(),
        role: Role.fromCode((j['role'] ?? 'ishchi').toString()),
        isActive: (j['is_active'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role.code,
        'is_active': isActive,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Product {
  final int id;
  final String name;
  final String sku;
  final String qrCode;
  final String unit; // m2, dona, kg, m
  final double? donaM2; // faqat toshlar uchun (0.25)
  final double price; // bazaviy birlik narxi
  final double costPrice;
  final double stock;
  final String? imageUrl;

  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.qrCode = '',
    required this.unit,
    this.donaM2,
    required this.price,
    this.costPrice = 0,
    this.stock = 0,
    this.imageUrl,
  });

  bool get hasDona => donaM2 != null && donaM2! > 0;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? qrCode,
    String? unit,
    double? donaM2,
    double? price,
    double? costPrice,
    double? stock,
    String? imageUrl,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        qrCode: qrCode ?? this.qrCode,
        unit: unit ?? this.unit,
        donaM2: donaM2 ?? this.donaM2,
        price: price ?? this.price,
        costPrice: costPrice ?? this.costPrice,
        stock: stock ?? this.stock,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        sku: (j['sku'] ?? '').toString(),
        qrCode: (j['qr_code'] ?? '').toString(),
        unit: (j['unit'] ?? 'm²').toString(),
        donaM2: j['dona_m2'] == null ? null : parseNum(j['dona_m2']),
        price: parseNum(j['price']),
        costPrice: parseNum(j['cost_price']),
        stock: parseNum(j['stock']),
        imageUrl: (j['image_url'] != null && j['image_url'].toString().isNotEmpty)
            ? j['image_url'].toString()
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson({double initialStock = 0}) => {
        'name': name,
        'sku': sku.isEmpty ? null : sku,
        'qr_code': qrCode.isEmpty ? null : qrCode,
        'unit': unit,
        'dona_m2': donaM2,
        'price': price,
        'cost_price': costPrice,
        'image_url': imageUrl,
        'initial_stock': initialStock,
      };
}

class CartLine {
  final Product product;
  double quantity;
  bool inDona;
  CartLine(this.product, {this.quantity = 1, this.inDona = false});

  double get baseQty => (inDona && product.hasDona) ? quantity * product.donaM2! : quantity;
  double get lineTotal => baseQty * product.price;
}

class SaleItemRecord {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const SaleItemRecord({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory SaleItemRecord.fromJson(Map<String, dynamic> j) => SaleItemRecord(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        productName: (j['product_name'] ?? '').toString(),
        quantity: parseNum(j['quantity']),
        unitPrice: parseNum(j['unit_price']),
        lineTotal: parseNum(j['line_total']),
      );
}

class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? passport;
  final String? photoUrl;
  final DateTime? createdAt;
  final double totalSpent;
  final double totalDebt;
  final int salesCount;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.passport,
    this.photoUrl,
    this.createdAt,
    this.totalSpent = 0,
    this.totalDebt = 0,
    this.salesCount = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        phone: j['phone'] as String?,
        passport: j['passport'] as String?,
        photoUrl: j['photo_url'] as String?,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
        totalSpent: parseNum(j['total_spent']),
        totalDebt: parseNum(j['total_debt']),
        salesCount: (j['sales_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (passport != null && passport!.isNotEmpty) 'passport': passport,
        if (photoUrl != null && photoUrl!.isNotEmpty) 'photo_url': photoUrl,
      };

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? passport,
    String? photoUrl,
    DateTime? createdAt,
    double? totalSpent,
    double? totalDebt,
    int? salesCount,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        passport: passport ?? this.passport,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        totalSpent: totalSpent ?? this.totalSpent,
        totalDebt: totalDebt ?? this.totalDebt,
        salesCount: salesCount ?? this.salesCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SaleResult {
  final int id;
  final double total;
  final double paid;
  final double debt;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerPassport;
  final String? customerPhotoUrl;
  final int? cashierId;
  final String? cashierName;
  final String? paymentMethod;
  final DateTime? createdAt;
  final List<SaleItemRecord> items;

  const SaleResult({
    required this.id,
    required this.total,
    required this.paid,
    required this.debt,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerPassport,
    this.customerPhotoUrl,
    this.cashierId,
    this.cashierName,
    this.paymentMethod,
    this.createdAt,
    this.items = const [],
  });

  factory SaleResult.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'] as Map<String, dynamic>?;
    final itemsRaw = j['items'] as List<dynamic>?;
    return SaleResult(
      id: (j['id'] as num?)?.toInt() ?? 0,
      total: parseNum(j['total']),
      paid: parseNum(j['paid']),
      debt: parseNum(j['debt']),
      customerId: cust != null ? (cust['id'] as num?)?.toInt() : (j['customer_id'] as num?)?.toInt(),
      customerName: cust != null ? (cust['name'] as String?) : (j['customer_name'] as String?),
      customerPhone: cust != null ? (cust['phone'] as String?) : (j['customer_phone'] as String?),
      customerPassport: cust != null ? (cust['passport'] as String?) : (j['customer_passport'] as String?),
      customerPhotoUrl: cust != null ? (cust['photo_url'] as String?) : (j['customer_photo_url'] as String?),
      cashierId: (j['cashier_id'] as num?)?.toInt(),
      cashierName: j['cashier_name'] as String?,
      paymentMethod: (j['payment_method'] as String?) ?? 'cash',
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
      items: itemsRaw != null
          ? itemsRaw.map((e) => SaleItemRecord.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleResult && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class StockMovementRecord {
  final int id;
  final int productId;
  final String? productName;
  final double qtyDelta;
  final String kind;
  final String? note;
  final String? createdByName;
  final double? unitCost;
  final DateTime createdAt;

  const StockMovementRecord({
    required this.id,
    required this.productId,
    this.productName,
    required this.qtyDelta,
    required this.kind,
    this.note,
    this.createdByName,
    this.unitCost,
    required this.createdAt,
  });

  factory StockMovementRecord.fromJson(Map<String, dynamic> j) => StockMovementRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        productName: j['product_name'] as String?,
        qtyDelta: parseNum(j['qty_delta']),
        kind: (j['kind'] ?? '').toString(),
        note: j['note'] as String?,
        createdByName: j['created_by_name'] as String?,
        unitCost: j['unit_cost'] != null ? parseNum(j['unit_cost']) : null,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovementRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class FinanceSummary {
  final double revenue, cashCollected, cogs, grossProfit, expenses, netProfit, receivables;
  const FinanceSummary({
    required this.revenue,
    required this.cashCollected,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.receivables,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> j) => FinanceSummary(
        revenue: parseNum(j['revenue']),
        cashCollected: parseNum(j['cash_collected']),
        cogs: parseNum(j['cogs']),
        grossProfit: parseNum(j['gross_profit']),
        expenses: parseNum(j['expenses']),
        netProfit: parseNum(j['net_profit']),
        receivables: parseNum(j['receivables']),
      );
}

class ProductionTask {
  final int id;
  final int productId;
  final String productName;
  final String unit;
  final int assignedTo;
  final String workerName;
  final double planned;
  final double produced;
  final String status; // open | done
  const ProductionTask({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.assignedTo,
    required this.workerName,
    required this.planned,
    required this.produced,
    required this.status,
  });

  factory ProductionTask.fromJson(Map<String, dynamic> j) => ProductionTask(
        id: (j['id'] as num?)?.toInt() ?? 0,
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        productName: (j['product_name'] ?? '').toString(),
        unit: (j['unit'] ?? 'm²').toString(),
        assignedTo: (j['assigned_to'] as num?)?.toInt() ?? 0,
        workerName: (j['worker_name'] ?? 'Ishchi').toString(),
        planned: parseNum(j['planned_qty'] ?? j['planned']),
        produced: parseNum(j['produced_qty'] ?? j['produced']),
        status: (j['status'] ?? 'open').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'unit': unit,
        'assigned_to': assignedTo,
        'worker_name': workerName,
        'planned_qty': planned,
        'produced_qty': produced,
        'status': status,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductionTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String kind; // warning | payment | sale | production | system
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        kind: (j['kind'] ?? 'system').toString(),
        isRead: j['is_read'] == true,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        kind: kind,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

