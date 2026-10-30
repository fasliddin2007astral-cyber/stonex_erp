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
  final double salary;
  final String salaryType; // 'monthly', 'daily', 'hourly'
  final bool isActive;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.salary = 0,
    this.salaryType = 'monthly',
    this.isActive = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] ?? '').toString(),
        fullName: (j['full_name'] ?? j['username'] ?? '').toString(),
        role: Role.fromCode((j['role'] ?? 'ishchi').toString()),
        salary: parseNum(j['salary']),
        salaryType: (j['salary_type'] ?? 'monthly').toString(),
        isActive: (j['is_active'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role.code,
        'salary': salary,
        'salary_type': salaryType,
        'is_active': isActive,
      };

  AppUser copyWith({
    int? id,
    String? username,
    String? fullName,
    Role? role,
    double? salary,
    String? salaryType,
    bool? isActive,
  }) =>
      AppUser(
        id: id ?? this.id,
        username: username ?? this.username,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        salary: salary ?? this.salary,
        salaryType: salaryType ?? this.salaryType,
        isActive: isActive ?? this.isActive,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AttendanceRecord {
  final int id;
  final int userId;
  final String? userName;
  final String date; // YYYY-MM-DD
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double workedHours;
  final String status; // 'present', 'late', 'absent', 'half_day'
  final String? note;

  const AttendanceRecord({
    required this.id,
    required this.userId,
    this.userName,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.workedHours = 0,
    this.status = 'present',
    this.note,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        userName: j['user_name']?.toString(),
        date: (j['date'] ?? '').toString(),
        checkIn: j['check_in'] != null ? DateTime.tryParse(j['check_in'].toString()) : null,
        checkOut: j['check_out'] != null ? DateTime.tryParse(j['check_out'].toString()) : null,
        workedHours: parseNum(j['worked_hours']),
        status: (j['status'] ?? 'present').toString(),
        note: j['note']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'date': date,
        'check_in': checkIn?.toIso8601String(),
        'check_out': checkOut?.toIso8601String(),
        'worked_hours': workedHours,
        'status': status,
        'note': note,
      };

  AttendanceRecord copyWith({
    int? id,
    int? userId,
    String? userName,
    String? date,
    DateTime? checkIn,
    DateTime? checkOut,
    double? workedHours,
    String? status,
    String? note,
  }) =>
      AttendanceRecord(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        date: date ?? this.date,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        workedHours: workedHours ?? this.workedHours,
        status: status ?? this.status,
        note: note ?? this.note,
      );
}

class SalaryReportItem {
  final int userId;
  final String fullName;
  final String role;
  final double baseSalary;
  final String salaryType;
  final int daysWorked;
  final double hoursWorked;
  final int daysLate;
  final double calculatedSalary;
  double bonus;
  double deduction;
  final double netSalary;
  bool isPaid;

  SalaryReportItem({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.baseSalary,
    this.salaryType = 'monthly',
    this.daysWorked = 0,
    this.hoursWorked = 0,
    this.daysLate = 0,
    required this.calculatedSalary,
    this.bonus = 0,
    this.deduction = 0,
    required this.netSalary,
    this.isPaid = false,
  });

  factory SalaryReportItem.fromJson(Map<String, dynamic> j) => SalaryReportItem(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        fullName: (j['full_name'] ?? '').toString(),
        role: (j['role'] ?? 'ishchi').toString(),
        baseSalary: parseNum(j['base_salary']),
        salaryType: (j['salary_type'] ?? 'monthly').toString(),
        daysWorked: (j['days_worked'] as num?)?.toInt() ?? 0,
        hoursWorked: parseNum(j['hours_worked']),
        daysLate: (j['days_late'] as num?)?.toInt() ?? 0,
        calculatedSalary: parseNum(j['calculated_salary']),
        bonus: parseNum(j['bonus']),
        deduction: parseNum(j['deduction']),
        netSalary: parseNum(j['net_salary']),
        isPaid: (j['is_paid'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'role': role,
        'base_salary': baseSalary,
        'salary_type': salaryType,
        'days_worked': daysWorked,
        'hours_worked': hoursWorked,
        'days_late': daysLate,
        'calculated_salary': calculatedSalary,
        'bonus': bonus,
        'deduction': deduction,
        'net_salary': netSalary,
        'is_paid': isPaid,
      };
}

class Product {
  final int id;
  final String name;
  final String sku;
  final String qrCode;
  final String unit; // m2, dona, kg, m
  final double? donaM2; // faqat toshlar uchun (0.25)
  final String? sort; // 1, 1.5, 2, 3, oliy
  final bool hasSorts; // 1, 1.5, 2 sortlari mavjudligi (kassada tanlanadi)
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
    this.sort,
    this.hasSorts = false,
    required this.price,
    this.costPrice = 0,
    this.stock = 0,
    this.imageUrl,
  });

  bool get hasDona => donaM2 != null && donaM2! > 0;

  String get sortLabel {
    if (sort != null && sort!.isNotEmpty) {
      return sort == 'oliy' ? 'Oliy sort' : '$sort-sort';
    }
    if (hasSorts) {
      return '1 • 1.5 • 2 sort';
    }
    return '';
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? qrCode,
    String? unit,
    double? donaM2,
    String? sort,
    bool? hasSorts,
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
        sort: sort ?? this.sort,
        hasSorts: hasSorts ?? this.hasSorts,
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
        sort: j['sort']?.toString(),
        hasSorts: j['has_sorts'] == true,
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
        'sort': sort,
        'has_sorts': hasSorts,
        'price': price,
        'cost_price': costPrice,
        'initial_stock': initialStock,
        'image_url': imageUrl,
      };
}

class CartLine {
  final Product product;
  double quantity;
  bool inDona;
  String? sort; // '1', '1.5', '2'
  double? cutLength; // metrda
  double? cutWidth; // metrda
  int? cutPieces; // donasi
  String? cutSpec; // masalan: '1.2 × 0.6 m (5 dona)'

  CartLine(
    this.product, {
    this.quantity = 1,
    this.inDona = false,
    this.sort,
    this.cutLength,
    this.cutWidth,
    this.cutPieces,
    this.cutSpec,
  }) {
    if (product.hasSorts && sort == null) {
      sort = '1.5';
    }
  }

  double get baseQty => (inDona && product.hasDona) ? quantity * product.donaM2! : quantity;
  double get lineTotal => baseQty * product.price;

  String get displayName {
    final s = (sort != null && sort!.isNotEmpty) ? ' ($sort-sort)' : '';
    final c = (cutSpec != null && cutSpec!.isNotEmpty) ? ' [$cutSpec]' : '';
    return '${product.name}$s$c';
  }

  CartLine copy() => CartLine(
        product,
        quantity: quantity,
        inDona: inDona,
        sort: sort,
        cutLength: cutLength,
        cutWidth: cutWidth,
        cutPieces: cutPieces,
        cutSpec: cutSpec,
      );
}

class HeldCart {
  final String id;
  final String label;
  final DateTime createdAt;
  final List<CartLine> lines;

  HeldCart({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lines,
  });

  double get total => lines.fold(0, (a, l) => a + l.lineTotal);
  int get count => lines.length;
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

  bool get isCut =>
      (productName.contains('[') && (productName.contains(']') || productName.contains('dona)'))) ||
      productName.toLowerCase().contains('kesil') ||
      productName.toLowerCase().contains('maxsus razmer');

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
  final String status; // 'completed' | 'order' | 'cancelled'
  final String? note;
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

  bool get isOrder => status == 'order';

  const SaleResult({
    required this.id,
    required this.total,
    required this.paid,
    required this.debt,
    this.status = 'completed',
    this.note,
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

  SaleResult copyWith({
    int? id,
    double? total,
    double? paid,
    double? debt,
    String? status,
    String? note,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? customerPassport,
    String? customerPhotoUrl,
    int? cashierId,
    String? cashierName,
    String? paymentMethod,
    DateTime? createdAt,
    List<SaleItemRecord>? items,
  }) =>
      SaleResult(
        id: id ?? this.id,
        total: total ?? this.total,
        paid: paid ?? this.paid,
        debt: debt ?? this.debt,
        status: status ?? this.status,
        note: note ?? this.note,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        customerPassport: customerPassport ?? this.customerPassport,
        customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
        cashierId: cashierId ?? this.cashierId,
        cashierName: cashierName ?? this.cashierName,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        createdAt: createdAt ?? this.createdAt,
        items: items ?? this.items,
      );

  factory SaleResult.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'] as Map<String, dynamic>?;
    final itemsRaw = j['items'] as List<dynamic>?;
    return SaleResult(
      id: (j['id'] as num?)?.toInt() ?? 0,
      total: parseNum(j['total']),
      paid: parseNum(j['paid']),
      debt: parseNum(j['debt']),
      status: (j['status'] as String?) ?? 'completed',
      note: j['note'] as String?,
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

