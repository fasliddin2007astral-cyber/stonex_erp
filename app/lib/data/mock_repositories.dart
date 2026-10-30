import 'dart:convert';

import '../domain/models.dart';
import 'api_client.dart' show ApiException;
import 'local_image_store.dart';
import 'repositories.dart';

class MockSaleEntry {
  SaleResult result;
  final double cost;
  MockSaleEntry({required this.result, required this.cost});
}

/// Xotiradagi vaqtinchalik "baza". Ilova yopilganda tozalanadi.
/// Mock repository'lar bir xil MockStore'ni bo'lishadi, shuning uchun savdo qoldiqni
/// kamaytiradi, ishlab chiqarish qoldiqni oshiradi — xuddi haqiqiy backend kabi.
class MockStore {
  int nextProductId = 100;
  int nextId = 100;
  int nextUserId = 10;
  int nextAttendanceId = 100;

  final List<Product> products = [
    const Product(id: 1, name: 'Angola', qrCode: 'STX-ANGOLA', unit: 'm2', donaM2: 0.25, hasSorts: true, price: 180000, costPrice: 120000, stock: 200, imageUrl: 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=400&auto=format&fit=crop&q=80'),
    const Product(id: 2, name: 'Miramir', qrCode: 'STX-MIRAMIR', unit: 'm2', donaM2: 0.25, hasSorts: true, price: 170000, costPrice: 110000, stock: 150, imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400&auto=format&fit=crop&q=80'),
    const Product(id: 3, name: 'Tan Brown', qrCode: 'STX-TANBROWN', unit: 'm2', donaM2: 0.25, hasSorts: true, price: 190000, costPrice: 130000, stock: 120, imageUrl: 'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=400&auto=format&fit=crop&q=80'),
    const Product(id: 4, name: 'Metalogranit', qrCode: 'STX-METALOGRANIT', unit: 'm2', price: 150000, costPrice: 95000, stock: 80, imageUrl: 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=400&auto=format&fit=crop&q=80'),
    const Product(id: 5, name: 'Kley', qrCode: 'STX-KLEY', unit: 'dona', price: 45000, costPrice: 30000, stock: 100, imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=400&auto=format&fit=crop&q=80'),
    const Product(id: 6, name: 'Sim', qrCode: 'STX-SIM', unit: 'm', price: 12000, costPrice: 7000, stock: 500),
    const Product(id: 7, name: 'Disk', qrCode: 'STX-DISK', unit: 'dona', price: 250000, costPrice: 170000, stock: 30),
  ];

  /// Faqat mock rejimi uchun test akkauntlari (haqiqiy backendda parollar xeshlangan).
  final Map<String, ({String password, AppUser user})> users = {
    'admin': (
      password: 'admin12345',
      user: const AppUser(
        id: 1,
        username: 'admin',
        fullName: 'Xo‘jayin',
        role: Role.admin,
        salary: 12000000,
        salaryType: 'monthly',
      ),
    ),
    'kassir': (
      password: 'kassir123',
      user: const AppUser(
        id: 2,
        username: 'kassir',
        fullName: 'Kassir Aziz',
        role: Role.kassir,
        salary: 6500000,
        salaryType: 'monthly',
      ),
    ),
    'ishchi': (
      password: 'ishchi123',
      user: const AppUser(
        id: 3,
        username: 'ishchi',
        fullName: 'Ishchi Bobur',
        role: Role.ishchi,
        salary: 5200000,
        salaryType: 'monthly',
      ),
    ),
  };

  final List<AttendanceRecord> attendances = [
    AttendanceRecord(
      id: 1,
      userId: 2,
      userName: 'Kassir Aziz',
      date: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      checkIn: DateTime.now().copyWith(hour: 8, minute: 45),
      checkOut: null,
      workedHours: 0,
      status: 'present',
      note: 'Vaqtida keldi',
    ),
    AttendanceRecord(
      id: 2,
      userId: 3,
      userName: 'Ishchi Bobur',
      date: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      checkIn: DateTime.now().copyWith(hour: 9, minute: 25),
      checkOut: null,
      workedHours: 0,
      status: 'late',
      note: 'Tirbandlik sababli 10 daqiqa kechikdi',
    ),
  ];

  final List<MockSaleEntry> sales = [
    MockSaleEntry(
      result: SaleResult(
        id: 95,
        total: 1800000,
        paid: 1800000,
        debt: 0,
        customerName: 'Sardor Qodirov',
        customerPhone: '+998 90 999 11 22',
        cashierName: 'Alisher (Kassir)',
        paymentMethod: 'cash',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
        items: const [
          SaleItemRecord(productId: 1, productName: 'Angola', quantity: 10, unitPrice: 180000, lineTotal: 1800000),
        ],
      ),
      cost: 1200000,
    ),
    MockSaleEntry(
      result: SaleResult(
        id: 96,
        total: 900000,
        paid: 900000,
        debt: 0,
        customerName: 'Farhod Usta',
        customerPhone: '+998 91 888 22 33',
        cashierName: 'Alisher (Kassir)',
        paymentMethod: 'karta',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        items: const [
          SaleItemRecord(productId: 5, productName: 'Kley', quantity: 20, unitPrice: 45000, lineTotal: 900000),
        ],
      ),
      cost: 600000,
    ),
    MockSaleEntry(
      result: SaleResult(
        id: 97,
        total: 1500000,
        paid: 1000000,
        debt: 500000,
        customerName: 'Javohir Toshkent',
        customerPhone: '+998 93 777 33 44',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        items: const [
          SaleItemRecord(productId: 4, productName: 'Metalogranit', quantity: 10, unitPrice: 150000, lineTotal: 1500000),
        ],
      ),
      cost: 950000,
    ),
    MockSaleEntry(
      result: SaleResult(
        id: 98,
        total: 512000,
        paid: 512000,
        debt: 0,
        customerName: 'Botir Qurilish',
        customerPhone: '+998 94 666 44 55',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        items: const [
          SaleItemRecord(productId: 7, productName: 'Disk', quantity: 2, unitPrice: 250000, lineTotal: 500000),
          SaleItemRecord(productId: 6, productName: 'Sim', quantity: 1, unitPrice: 12000, lineTotal: 12000),
        ],
      ),
      cost: 347000,
    ),
    MockSaleEntry(
      result: SaleResult(
        id: 99,
        total: 850000,
        paid: 600000,
        debt: 250000,
        customerName: 'Akmal aka',
        customerPhone: '+998 90 123 45 67',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        items: const [
          SaleItemRecord(productId: 2, productName: 'Miramir', quantity: 5, unitPrice: 170000, lineTotal: 850000),
        ],
      ),
      cost: 550000,
    ),
    MockSaleEntry(
      result: SaleResult(
        id: 100,
        total: 1900000,
        paid: 1900000,
        debt: 0,
        customerName: 'Sobirjon',
        customerPhone: '+998 99 555 12 34',
        createdAt: DateTime.now(),
        items: const [
          SaleItemRecord(productId: 3, productName: 'Tan Brown', quantity: 10, unitPrice: 190000, lineTotal: 1900000),
        ],
      ),
      cost: 1300000,
    ),
  ];
  final List<Customer> customers = [
    const Customer(
      id: 1,
      name: 'Sardor Qodirov',
      phone: '+998 90 999 11 22',
      passport: 'AB 1234567',
      totalSpent: 1800000,
      totalDebt: 0,
      salesCount: 1,
    ),
    const Customer(
      id: 2,
      name: 'Farhod Usta',
      phone: '+998 91 888 22 33',
      passport: 'AC 9876543',
      totalSpent: 900000,
      totalDebt: 0,
      salesCount: 1,
    ),
    const Customer(
      id: 3,
      name: 'Javohir Toshkent',
      phone: '+998 93 777 33 44',
      passport: 'AA 5556677',
      totalSpent: 1500000,
      totalDebt: 500000,
      salesCount: 1,
    ),
    const Customer(
      id: 4,
      name: 'Komil Samarkand',
      phone: '+998 99 555 12 34',
      passport: 'AD 1122334',
      totalSpent: 1900000,
      totalDebt: 700000,
      salesCount: 1,
    ),
  ];
  final List<ProductionTask> tasks = [
    const ProductionTask(
      id: 1,
      productId: 1,
      productName: 'Angola',
      unit: 'm2',
      assignedTo: 3,
      workerName: 'Ishchi Bobur',
      planned: 120,
      produced: 85,
      status: 'open',
    ),
    const ProductionTask(
      id: 2,
      productId: 2,
      productName: 'Miramir',
      unit: 'm2',
      assignedTo: 3,
      workerName: 'Ishchi Bobur',
      planned: 80,
      produced: 80,
      status: 'done',
    ),
    const ProductionTask(
      id: 3,
      productId: 3,
      productName: 'Tan Brown',
      unit: 'm2',
      assignedTo: 3,
      workerName: 'Ishchi Bobur',
      planned: 60,
      produced: 25,
      status: 'open',
    ),
  ];
  final List<StockMovementRecord> movements = [
    StockMovementRecord(id: 1, productId: 1, productName: 'Angola', qtyDelta: 200, kind: 'opening', note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now().subtract(const Duration(days: 10))),
    StockMovementRecord(id: 2, productId: 2, productName: 'Miramir', qtyDelta: 150, kind: 'opening', note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now().subtract(const Duration(days: 10))),
    StockMovementRecord(id: 3, productId: 4, productName: 'Metalogranit', qtyDelta: 80, kind: 'purchase', note: 'Navoiy Granit MCHJ / Partiya #12', createdByName: 'Admin', unitCost: 95000, createdAt: DateTime.now().subtract(const Duration(days: 4))),
    StockMovementRecord(id: 4, productId: 5, productName: 'Kley', qtyDelta: 100, kind: 'purchase', note: 'Akfix Rasmiy Diler / Shartnoma #88', createdByName: 'Admin', unitCost: 30000, createdAt: DateTime.now().subtract(const Duration(days: 2))),
    StockMovementRecord(id: 5, productId: 7, productName: 'Disk', qtyDelta: 30, kind: 'purchase', note: 'Toshkent Asbob Bozori / Naqd', createdByName: 'Admin', unitCost: 180000, createdAt: DateTime.now().subtract(const Duration(hours: 18))),
  ];
  final List<AppNotification> notifications = [
    AppNotification(
      id: 1,
      title: 'Ombor ogohlantirishi',
      message: 'Metalogranit zaxirasi 80 m² qoldi. Yangi partiya xaridini rejalashtiring.',
      kind: 'warning',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    AppNotification(
      id: 2,
      title: 'Qarz to‘lovi qabul qilindi',
      message: 'Mijoz Akmal aka 300 000 so‘m qarzini naqd to‘ladi.',
      kind: 'payment',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 3,
      title: 'Yangi savdo amalga oshirildi',
      message: 'Kassir Aziz tomonidan 1 850 000 so‘mlik savdo qilindi.',
      kind: 'sale',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 4,
      title: 'Ishlab chiqarish topshirig‘i',
      message: 'Ishchi Bobur 50 m² Angola toshini qayta ishlashni yakunladi.',
      kind: 'production',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  int indexOf(int productId) => products.indexWhere((p) => p.id == productId);

  void setStock(int productId, double newStock) {
    final i = indexOf(productId);
    if (i < 0) return;
    final p = products[i];
    products[i] = Product(
      id: p.id, name: p.name, sku: p.sku, qrCode: p.qrCode, unit: p.unit, donaM2: p.donaM2,
      price: p.price, costPrice: p.costPrice, stock: newStock,
    );
  }
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._s);
  final MockStore _s;

  @override
  Future<AppUser> login(String username, String password, Role role) async {
    final rec = _s.users[username.trim()];
    if (rec == null) throw ApiException('Login yoki parol noto‘g‘ri', 401);
    final isMatch = rec.password == password ||
        (username.trim() == 'admin' && (password == 'admin12345' || password == 'admin123'));
    if (!isMatch) throw ApiException('Login yoki parol noto‘g‘ri', 401);
    if (rec.user.role != role) throw ApiException('Bu akkaunt tanlangan rol uchun emas', 403);
    return rec.user;
  }

  @override
  Future<AppUser?> tryRestoreSession() async => null;

  @override
  Future<void> logout() async {}
}

class MockProductRepository implements ProductRepository {
  MockProductRepository(this._s);
  final MockStore _s;

  @override
  Future<List<Product>> list({String? query}) async {
    final q = (query ?? '').trim().toLowerCase();
    final all = _s.products.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.qrCode.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q));
    return all.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Product?> findByCode(String code) async {
    final c = code.trim().toLowerCase();
    for (final p in _s.products) {
      if (p.qrCode.toLowerCase() == c || (p.sku.isNotEmpty && p.sku.toLowerCase() == c)) return p;
    }
    return null;
  }

  @override
  Future<Product> create(Product p, {double initialStock = 0}) async {
    if (p.qrCode.isNotEmpty && _s.products.any((e) => e.qrCode == p.qrCode)) {
      throw ApiException('SKU yoki QR-kod allaqachon mavjud', 409);
    }
    final created = Product(
      id: _s.nextProductId++, name: p.name, sku: p.sku, qrCode: p.qrCode, unit: p.unit,
      donaM2: p.donaM2, sort: p.sort, hasSorts: p.hasSorts, price: p.price, costPrice: p.costPrice, stock: initialStock,
      imageUrl: p.imageUrl,
    );
    _s.products.add(created);
    if (initialStock > 0) {
      _s.movements.add(StockMovementRecord(
        id: _s.nextId++, productId: created.id, qtyDelta: initialStock, kind: 'opening',
        note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now(),
      ));
    }
    return created;
  }

  @override
  Future<Product> update(Product p) async {
    final i = _s.indexOf(p.id);
    if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
    final old = _s.products[i];
    final updated = Product(
      id: p.id, name: p.name, sku: p.sku, qrCode: p.qrCode, unit: p.unit, donaM2: p.donaM2,
      sort: p.sort, hasSorts: p.hasSorts, price: p.price, costPrice: p.costPrice, stock: old.stock, // qoldiq faqat harakatlar orqali o'zgaradi
      imageUrl: p.imageUrl ?? old.imageUrl,
    );
    _s.products[i] = updated;
    return updated;
  }

  @override
  Future<void> deactivate(int id) async => _s.products.removeWhere((p) => p.id == id);

  @override
  Future<String> uploadImage(List<int> bytes, String filename) async {
    return 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=600&auto=format&fit=crop&q=80';
  }

  @override
  Future<Product> uploadProductImage(int productId, List<int> bytes, String filename) async {
    final p = _s.products.firstWhere((e) => e.id == productId);
    final updated = p.copyWith(imageUrl: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=600&auto=format&fit=crop&q=80');
    final i = _s.products.indexWhere((e) => e.id == productId);
    if (i >= 0) _s.products[i] = updated;
    return updated;
  }
}

class MockSalesRepository implements SalesRepository {
  MockSalesRepository(this._s);
  final MockStore _s;

  @override
  Future<SaleResult> createSale({
    required List<CartLine> lines,
    required double paidAmount,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? customerPassport,
    String? customerPhotoUrl,
    String status = 'completed',
    String? note,
  }) async {
    if (lines.isEmpty) throw ApiException('Savat bo‘sh', 400);
    final isOrder = status == 'order';
    if (isOrder && (customerName == null || customerName.trim().isEmpty)) {
      throw ApiException('Buyurtma rasmiylashtirish uchun mijoz ko‘rsatilishi shart', 400);
    }

    final reserved = <int, double>{};
    var total = 0.0, cost = 0.0;
    for (final l in lines) {
      final i = _s.indexOf(l.product.id);
      if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
      final p = _s.products[i];
      final q = l.baseQty;
      if (q <= 0) throw ApiException('${p.name}: miqdor 0 dan katta bo‘lsin', 400);
      if (!isOrder) {
        final available = p.stock - (reserved[p.id] ?? 0);
        if (q > available + 1e-9) throw ApiException('${p.name}: omborda yetarli emas (bor: $available ${p.unit})', 400);
      }
      reserved[p.id] = (reserved[p.id] ?? 0) + q;
      total += q * p.price;
      cost += q * p.costPrice;
    }
    if (paidAmount < 0 || paidAmount > total + 1e-6) throw ApiException('To‘lov summasi noto‘g‘ri', 400);
    final debt = total - paidAmount;
    if (!isOrder && debt > 0.005 && (customerName == null || customerName.trim().isEmpty)) {
      throw ApiException('Nasiya uchun mijoz ko‘rsatilishi shart', 400);
    }
    final saleId = _s.nextId++;

    if (!isOrder) {
      reserved.forEach((id, q) {
        _s.setStock(id, _s.products[_s.indexOf(id)].stock - q);
        _s.movements.add(StockMovementRecord(
          id: _s.nextId++, productId: id, qtyDelta: -q, kind: 'sale',
          note: 'Savdo #$saleId', createdAt: DateTime.now(),
        ));
      });
    }

    final res = SaleResult(
      id: saleId,
      total: total,
      paid: paidAmount,
      debt: debt,
      status: status,
      note: note,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerPassport: customerPassport,
      customerPhotoUrl: customerPhotoUrl,
      cashierId: 1,
      cashierName: 'Alisher (Kassir)',
      paymentMethod: 'cash',
      createdAt: DateTime.now(),
      items: lines.map((l) => SaleItemRecord(
        productId: l.product.id,
        productName: l.displayName,
        quantity: l.baseQty,
        unitPrice: l.product.price,
        lineTotal: l.lineTotal,
      )).toList(),
    );
    _s.sales.add(MockSaleEntry(result: res, cost: cost));

    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: isOrder ? 'Yangi buyurtma qabul qilindi' : 'Yangi savdo amalga oshirildi',
      message: isOrder
          ? 'Buyurtma #$saleId: ${total.round()} so‘m (${customerName ?? 'Mijoz'})${paidAmount > 0 ? ', avans: ${paidAmount.round()} so‘m' : ''}'
          : 'Savdo #$saleId: ${total.round()} so‘m${customerName != null && customerName.isNotEmpty ? ' ($customerName)' : ''}',
      kind: isOrder ? 'order' : 'sale',
      isRead: false,
      createdAt: DateTime.now(),
    ));

    if (!isOrder) {
      reserved.forEach((id, q) {
        final p = _s.products[_s.indexOf(id)];
        if (p.stock <= 20) {
          _s.notifications.add(AppNotification(
            id: _s.nextId++,
            title: 'Ombor ogohlantirishi: Zaxira kam',
            message: '${p.name} mahsulotidan atigi ${p.stock.toStringAsFixed(1)} ${p.unit} qoldi!',
            kind: 'warning',
            isRead: false,
            createdAt: DateTime.now(),
          ));
        }
      });
    }

    return res;
  }

  @override
  Future<List<SaleResult>> listSales({int limit = 50, String? status}) async {
    Iterable<MockSaleEntry> entries = _s.sales;
    if (status != null && status.isNotEmpty) {
      entries = entries.where((e) => e.result.status == status);
    }
    final all = entries.map((e) => e.result).toList().reversed.toList();
    if (all.length > limit) return all.sublist(0, limit);
    return all;
  }

  @override
  Future<List<SaleResult>> listDebts() async {
    return _s.sales
        .where((e) => e.result.debt > 0.005)
        .map((e) => e.result)
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<SaleResult> payDebt(int saleId, double amount, {String method = 'cash'}) async {
    final entry = _s.sales.firstWhere(
      (e) => e.result.id == saleId,
      orElse: () => throw ApiException('Savdo topilmadi', 404),
    );
    if (amount <= 0 || amount > entry.result.debt + 0.01) {
      throw ApiException('To‘lov summasi noto‘g‘ri yoki qarzdan ortiq', 400);
    }
    final newPaid = entry.result.paid + amount;
    final newDebt = (entry.result.total - newPaid).clamp(0, double.infinity).toDouble();
    final updated = entry.result.copyWith(paid: newPaid, debt: newDebt);
    entry.result = updated;
    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Qarz to‘lovi qabul qilindi',
      message: 'Mijoz ${entry.result.customerName ?? 'Mijoz'} ${amount.round()} so‘m to‘ladi ($method)',
      kind: 'payment',
      isRead: false,
      createdAt: DateTime.now(),
    ));
    return updated;
  }

  @override
  Future<SaleResult> fulfillOrder(int saleId) async {
    final entry = _s.sales.firstWhere(
      (e) => e.result.id == saleId,
      orElse: () => throw ApiException('Buyurtma topilmadi', 404),
    );
    if (entry.result.status != 'order') {
      throw ApiException('Faqat faol buyurtmalarni topshirish mumkin', 400);
    }

    // Omborda mahsulot yetarliligini tekshiramiz
    for (final item in entry.result.items) {
      final idx = _s.indexOf(item.productId);
      if (idx < 0) throw ApiException('${item.productName}: mahsulot omborda topilmadi', 404);
      final p = _s.products[idx];
      if (item.quantity > p.stock + 1e-9) {
        throw ApiException('${p.name}: omborda yetarli emas (mavjud: ${p.stock.toStringAsFixed(1)} ${p.unit}, kerak: ${item.quantity.toStringAsFixed(1)})', 400);
      }
    }

    // Ombordan yechamiz va harakat yozamiz
    for (final item in entry.result.items) {
      final idx = _s.indexOf(item.productId);
      final p = _s.products[idx];
      _s.setStock(p.id, p.stock - item.quantity);
      _s.movements.add(StockMovementRecord(
        id: _s.nextId++,
        productId: p.id,
        qtyDelta: -item.quantity,
        kind: 'sale',
        note: 'Buyurtma topshirildi #$saleId (${entry.result.customerName ?? ''})',
        createdAt: DateTime.now(),
      ));
    }

    final updated = entry.result.copyWith(status: 'completed');
    entry.result = updated;

    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Buyurtma topshirildi',
      message: 'Buyurtma #$saleId mijozga topshirildi (${entry.result.customerName ?? 'Mijoz'})',
      kind: 'order',
      isRead: false,
      createdAt: DateTime.now(),
    ));

    return updated;
  }

  @override
  Future<SaleResult> cancelOrder(int saleId) async {
    final entry = _s.sales.firstWhere(
      (e) => e.result.id == saleId,
      orElse: () => throw ApiException('Buyurtma topilmadi', 404),
    );
    if (entry.result.status == 'completed') {
      throw ApiException('Topshirilgan buyurtmani bekor qilib bo‘lmaydi', 400);
    }

    final updated = entry.result.copyWith(status: 'cancelled');
    entry.result = updated;

    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Buyurtma bekor qilindi',
      message: 'Buyurtma #$saleId bekor qilindi (${entry.result.customerName ?? 'Mijoz'})',
      kind: 'warning',
      isRead: false,
      createdAt: DateTime.now(),
    ));

    return updated;
  }
}

class MockFinanceRepository implements FinanceRepository {
  MockFinanceRepository(this._s);
  final MockStore _s;

  @override
  Future<FinanceSummary> summary() async {
    final revenue = _s.sales.fold<double>(0, (a, e) => a + e.result.total);
    final cogs = _s.sales.fold<double>(0, (a, e) => a + e.cost);
    final paid = _s.sales.fold<double>(0, (a, e) => a + e.result.paid);
    final receivables = _s.sales.fold<double>(0, (a, e) => a + e.result.debt);
    return FinanceSummary(
      revenue: revenue, cashCollected: paid, cogs: cogs, grossProfit: revenue - cogs,
      expenses: 0, netProfit: revenue - cogs, receivables: receivables,
    );
  }
}

class MockProductionRepository implements ProductionRepository {
  MockProductionRepository(this._s);
  final MockStore _s;

  @override
  Future<List<ProductionTask>> list() async => _s.tasks.reversed.toList();

  @override
  Future<List<AppUser>> workers() async =>
      _s.users.values.map((e) => e.user).where((u) => u.role == Role.ishchi && u.isActive).toList();

  @override
  Future<void> create({required int productId, required int workerId, required double plannedQty}) async {
    final i = _s.indexOf(productId);
    if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
    final w = _s.users.values
        .map((e) => e.user)
        .firstWhere((u) => u.id == workerId,
            orElse: () => const AppUser(id: 3, username: 'ishchi', fullName: 'Ishchi Bobur', role: Role.ishchi));
    final p = _s.products[i];
    _s.tasks.add(ProductionTask(
      id: _s.nextId++, productId: p.id, productName: p.name, unit: p.unit, assignedTo: w.id,
      workerName: w.fullName, planned: plannedQty, produced: 0, status: 'open',
    ));
    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Yangi ishlab chiqarish topshirig‘i',
      message: '${w.fullName}: ${p.name} ($plannedQty ${p.unit}) biriktirildi',
      kind: 'production',
      isRead: false,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> report(int taskId, double producedQty) async {
    final ti = _s.tasks.indexWhere((t) => t.id == taskId);
    if (ti < 0) throw ApiException('Topshiriq topilmadi', 404);
    final t = _s.tasks[ti];
    if (t.status == 'done') throw ApiException('Topshiriq yopilgan', 400);
    final produced = t.produced + producedQty;
    _s.tasks[ti] = ProductionTask(
      id: t.id, productId: t.productId, productName: t.productName, unit: t.unit,
      assignedTo: t.assignedTo, workerName: t.workerName, planned: t.planned,
      produced: produced, status: produced >= t.planned ? 'done' : 'open',
    );
    final pi = _s.indexOf(t.productId);
    if (pi >= 0) {
      _s.setStock(t.productId, _s.products[pi].stock + producedQty);
    }
    _s.movements.add(StockMovementRecord(
      id: _s.nextId++, productId: t.productId, qtyDelta: producedQty, kind: 'production',
      note: 'Topshiriq #${t.id} bajarilishi', createdAt: DateTime.now(),
    ));
    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: produced >= t.planned ? 'Ishlab chiqarish yakunlandi' : 'Ishlab chiqarish qayd etildi',
      message: '${t.workerName}: ${t.productName} ($producedQty ${t.unit} tayyorlandi)',
      kind: 'production',
      isRead: false,
      createdAt: DateTime.now(),
    ));
  }
}

class MockUserRepository implements UserRepository {
  MockUserRepository(this._s);
  final MockStore _s;

  @override
  Future<List<AppUser>> list({String? role}) async {
    final all = _s.users.values.map((e) => e.user);
    if (role != null && role.isNotEmpty) {
      return all.where((u) => u.role.code == role).toList();
    }
    return all.toList();
  }

  @override
  Future<AppUser> create({
    required String username,
    required String fullName,
    required String password,
    required Role role,
    double salary = 0,
    String salaryType = 'monthly',
  }) async {
    if (_s.users.containsKey(username.trim())) {
      throw ApiException('Bu login allaqachon mavjud', 409);
    }
    final user = AppUser(
      id: _s.nextUserId++,
      username: username.trim(),
      fullName: fullName.trim(),
      role: role,
      salary: salary,
      salaryType: salaryType,
      isActive: true,
    );
    _s.users[username.trim()] = (password: password, user: user);
    return user;
  }

  @override
  Future<AppUser> update(
    int id, {
    String? fullName,
    String? password,
    Role? role,
    double? salary,
    String? salaryType,
    bool? isActive,
  }) async {
    final entry = _s.users.entries.firstWhere(
      (e) => e.value.user.id == id,
      orElse: () => throw ApiException('Foydalanuvchi topilmadi', 404),
    );
    final oldUser = entry.value.user;
    final updated = AppUser(
      id: oldUser.id,
      username: oldUser.username,
      fullName: fullName ?? oldUser.fullName,
      role: role ?? oldUser.role,
      salary: salary ?? oldUser.salary,
      salaryType: salaryType ?? oldUser.salaryType,
      isActive: isActive ?? oldUser.isActive,
    );
    _s.users[entry.key] = (
      password: (password != null && password.isNotEmpty) ? password : entry.value.password,
      user: updated,
    );
    return updated;
  }
}

class MockAttendanceRepository implements AttendanceRepository {
  MockAttendanceRepository(this._s);
  final MockStore _s;

  @override
  Future<List<AttendanceRecord>> list({String? date, String? month, int? userId}) async {
    var items = List<AttendanceRecord>.from(_s.attendances);
    if (date != null && date.isNotEmpty) {
      items = items.where((a) => a.date == date).toList();
    } else if (month != null && month.isNotEmpty) {
      items = items.where((a) => a.date.startsWith(month)).toList();
    }
    if (userId != null) {
      items = items.where((a) => a.userId == userId).toList();
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Future<AttendanceRecord> checkIn(int userId, {DateTime? time, String? note}) async {
    final now = time ?? DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final user = _s.users.values.firstWhere((u) => u.user.id == userId, orElse: () => throw ApiException('Xodim topilmadi', 404)).user;

    final isLate = now.hour > 9 || (now.hour == 9 && now.minute > 15);
    final idx = _s.attendances.indexWhere((a) => a.userId == userId && a.date == dateStr);

    if (idx >= 0) {
      final existing = _s.attendances[idx];
      double hours = 0;
      if (existing.checkOut != null) {
        hours = double.parse((existing.checkOut!.difference(now).inMinutes / 60.0).clamp(0.0, 24.0).toStringAsFixed(1));
      }
      final updated = existing.copyWith(
        checkIn: now,
        workedHours: hours > 0 ? hours : existing.workedHours,
        status: isLate ? 'late' : existing.status,
        note: note ?? existing.note,
      );
      _s.attendances[idx] = updated;
      return updated;
    } else {
      final rec = AttendanceRecord(
        id: _s.nextAttendanceId++,
        userId: userId,
        userName: user.fullName,
        date: dateStr,
        checkIn: now,
        status: isLate ? 'late' : 'present',
        note: note,
      );
      _s.attendances.add(rec);
      return rec;
    }
  }

  @override
  Future<AttendanceRecord> checkOut(int userId, {DateTime? time, String? note}) async {
    final now = time ?? DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final user = _s.users.values.firstWhere((u) => u.user.id == userId, orElse: () => throw ApiException('Xodim topilmadi', 404)).user;
    final idx = _s.attendances.indexWhere((a) => a.userId == userId && a.date == dateStr);

    if (idx >= 0) {
      final existing = _s.attendances[idx];
      double hours = 0;
      if (existing.checkIn != null) {
        hours = double.parse((now.difference(existing.checkIn!).inMinutes / 60.0).clamp(0.0, 24.0).toStringAsFixed(1));
      }
      final updated = existing.copyWith(
        checkOut: now,
        workedHours: hours,
        note: note ?? existing.note,
      );
      _s.attendances[idx] = updated;
      return updated;
    } else {
      final rec = AttendanceRecord(
        id: _s.nextAttendanceId++,
        userId: userId,
        userName: user.fullName,
        date: dateStr,
        checkOut: now,
        status: 'present',
        note: note,
      );
      _s.attendances.add(rec);
      return rec;
    }
  }

  @override
  Future<AttendanceRecord> saveRecord(AttendanceRecord record) async {
    final idx = _s.attendances.indexWhere((a) => a.id == record.id || (a.userId == record.userId && a.date == record.date));
    if (idx >= 0) {
      _s.attendances[idx] = record;
      return record;
    } else {
      final rec = record.copyWith(id: record.id > 0 ? record.id : _s.nextAttendanceId++);
      _s.attendances.add(rec);
      return rec;
    }
  }

  @override
  Future<List<SalaryReportItem>> getSalaryReport({required String month, int totalWorkingDays = 26}) async {
    final users = _s.users.values.map((e) => e.user).where((u) => u.isActive).toList();
    final atts = _s.attendances.where((a) => a.date.startsWith(month)).toList();

    final userAtts = <int, List<AttendanceRecord>>{};
    for (final a in atts) {
      userAtts.putIfAbsent(a.userId, () => []).add(a);
    }

    final list = <SalaryReportItem>[];
    for (final u in users) {
      final uList = userAtts[u.id] ?? [];
      final worked = uList.where((a) => a.status != 'absent').toList();
      final daysWorked = worked.length;
      final hoursWorked = worked.fold(0.0, (sum, a) => sum + a.workedHours);
      final daysLate = uList.where((a) => a.status == 'late').length;

      double calculated = 0;
      if (u.salaryType == 'daily') {
        calculated = u.salary * daysWorked;
      } else if (u.salaryType == 'hourly') {
        calculated = u.salary * hoursWorked;
      } else {
        final perDay = totalWorkingDays > 0 ? (u.salary / totalWorkingDays) : 0;
        calculated = (perDay * (daysWorked > 0 ? daysWorked : totalWorkingDays)).roundToDouble();
      }

      final dayRate = totalWorkingDays > 0 ? (u.salary / totalWorkingDays) : 0;
      final deduction = (dayRate * 0.1 * daysLate).roundToDouble();
      final net = (calculated - deduction).clamp(0.0, double.infinity);

      list.add(SalaryReportItem(
        userId: u.id,
        fullName: u.fullName,
        role: u.role.label,
        baseSalary: u.salary,
        salaryType: u.salaryType,
        daysWorked: daysWorked > 0 ? daysWorked : totalWorkingDays,
        hoursWorked: hoursWorked > 0 ? hoursWorked : (totalWorkingDays * 8.0),
        daysLate: daysLate,
        calculatedSalary: calculated,
        deduction: deduction,
        netSalary: net,
        isPaid: false,
      ));
    }
    return list;
  }

  @override
  Future<void> paySalary(int userId, String month, double amount) async {
    // To'lov amalga oshirildi deb belgilash
  }
}

class MockStockRepository implements StockRepository {
  MockStockRepository(this._s);
  final MockStore _s;

  @override
  Future<List<StockMovementRecord>> movements({int? productId}) async {
    if (productId != null) {
      return _s.movements.where((m) => m.productId == productId).toList().reversed.toList();
    }
    return _s.movements.reversed.toList();
  }

  @override
  Future<void> purchase({
    required int productId,
    required double quantity,
    required double unitCost,
    String? note,
  }) async {
    final i = _s.indexOf(productId);
    if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
    final p = _s.products[i];
    final oldStock = p.stock < 0 ? 0 : p.stock;
    final newStock = oldStock + quantity;
    final newCost = ((oldStock * p.costPrice) + (quantity * unitCost)) / newStock;
    _s.products[i] = Product(
      id: p.id, name: p.name, sku: p.sku, qrCode: p.qrCode, unit: p.unit, donaM2: p.donaM2,
      price: p.price, costPrice: newCost, stock: newStock,
    );
    _s.movements.add(StockMovementRecord(
      id: _s.nextId++, productId: productId, productName: p.name, qtyDelta: quantity, kind: 'purchase',
      note: note ?? 'Xarid kirimi', createdByName: 'Admin', unitCost: unitCost, createdAt: DateTime.now(),
    ));
    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Omborga tovar kirimi',
      message: '${p.name}: +$quantity ${p.unit} qabul qilindi',
      kind: 'system',
      isRead: false,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> adjust({
    required int productId,
    required double delta,
    required String note,
  }) async {
    final i = _s.indexOf(productId);
    if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
    final p = _s.products[i];
    if (p.stock + delta < 0) {
      throw ApiException('Qoldiq manfiy bo‘lib qoladi', 400);
    }
    _s.setStock(productId, p.stock + delta);
    _s.movements.add(StockMovementRecord(
      id: _s.nextId++, productId: productId, qtyDelta: delta, kind: 'adjustment',
      note: note, createdAt: DateTime.now(),
    ));
    final sign = delta > 0 ? '+' : '';
    _s.notifications.add(AppNotification(
      id: _s.nextId++,
      title: 'Ombor qoldig‘i tuzatildi',
      message: '${p.name}: $sign$delta ${p.unit} ($note)',
      kind: 'warning',
      isRead: false,
      createdAt: DateTime.now(),
    ));
  }
}

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._s);
  final MockStore _s;

  @override
  Future<List<AppNotification>> list({int limit = 50}) async {
    final list = _s.notifications.reversed.toList();
    if (list.length > limit) return list.sublist(0, limit);
    return list;
  }

  @override
  Future<void> markRead(int id) async {
    final idx = _s.notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _s.notifications[idx] = _s.notifications[idx].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllRead() async {
    for (int i = 0; i < _s.notifications.length; i++) {
      _s.notifications[i] = _s.notifications[i].copyWith(isRead: true);
    }
  }
}

class MockCustomerRepository implements CustomerRepository {
  MockCustomerRepository(this._s);
  final MockStore _s;

  @override
  Future<List<Customer>> listCustomers({String? query}) async {
    await Future.delayed(const Duration(milliseconds: 60));
    List<Customer> list;
    if (query == null || query.trim().isEmpty) {
      list = List.of(_s.customers);
    } else {
      final q = query.trim().toLowerCase();
      list = _s.customers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            (c.phone ?? '').toLowerCase().contains(q) ||
            (c.passport ?? '').toLowerCase().contains(q);
      }).toList();
    }
    return list.map((c) {
      final local = LocalImageStore.getCustomerImage(c.id, c.phone, c.name);
      if (local != null && local.isNotEmpty) {
        return c.copyWith(photoUrl: local);
      }
      return c;
    }).toList();
  }

  @override
  Future<Customer> getCustomer(int id) async {
    final c = _s.customers.firstWhere((x) => x.id == id, orElse: () => throw ApiException('Mijoz topilmadi', 404));
    final local = LocalImageStore.getCustomerImage(c.id, c.phone, c.name);
    if (local != null && local.isNotEmpty) {
      return c.copyWith(photoUrl: local);
    }
    return c;
  }

  @override
  Future<Customer> createCustomer(Customer customer) async {
    final c = customer.copyWith(id: _s.nextId++, createdAt: DateTime.now());
    _s.customers.add(c);
    if (c.photoUrl != null && c.photoUrl!.isNotEmpty) {
      LocalImageStore.saveCustomerImage(c.id, c.photoUrl, c.phone, c.name);
    }
    return c;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    final idx = _s.customers.indexWhere((x) => x.id == customer.id);
    if (idx < 0) throw ApiException('Mijoz topilmadi', 404);
    _s.customers[idx] = customer;
    if (customer.photoUrl != null && customer.photoUrl!.isNotEmpty) {
      LocalImageStore.saveCustomerImage(customer.id, customer.photoUrl, customer.phone, customer.name);
    }
    return customer;
  }

  @override
  Future<String> uploadCustomerImage(List<int> bytes, String filename) async {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  @override
  Future<void> deleteCustomer(int id) async {
    final idx = _s.customers.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      _s.customers.removeAt(idx);
    }
  }
}

