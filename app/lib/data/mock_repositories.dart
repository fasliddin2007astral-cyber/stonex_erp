import '../domain/models.dart';
import 'api_client.dart' show ApiException;
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

  final List<Product> products = [
    const Product(id: 1, name: 'Angola', qrCode: 'STX-ANGOLA', unit: 'm2', donaM2: 0.25, price: 180000, costPrice: 120000, stock: 200),
    const Product(id: 2, name: 'Miramir', qrCode: 'STX-MIRAMIR', unit: 'm2', donaM2: 0.25, price: 170000, costPrice: 110000, stock: 150),
    const Product(id: 3, name: 'Tan Brown', qrCode: 'STX-TANBROWN', unit: 'm2', donaM2: 0.25, price: 190000, costPrice: 130000, stock: 120),
    const Product(id: 4, name: 'Metalogranit', qrCode: 'STX-METALOGRANIT', unit: 'm2', price: 150000, costPrice: 95000, stock: 80),
    const Product(id: 5, name: 'Kley', qrCode: 'STX-KLEY', unit: 'dona', price: 45000, costPrice: 30000, stock: 100),
    const Product(id: 6, name: 'Sim', qrCode: 'STX-SIM', unit: 'm', price: 12000, costPrice: 7000, stock: 500),
    const Product(id: 7, name: 'Disk', qrCode: 'STX-DISK', unit: 'dona', price: 250000, costPrice: 170000, stock: 30),
  ];

  /// Faqat mock rejimi uchun test akkauntlari (haqiqiy backendda parollar xeshlangan).
  final Map<String, ({String password, AppUser user})> users = {
    'admin': (password: 'admin123', user: const AppUser(id: 1, username: 'admin', fullName: 'Xo‘jayin', role: Role.admin)),
    'kassir': (password: 'kassir123', user: const AppUser(id: 2, username: 'kassir', fullName: 'Kassir Aziz', role: Role.kassir)),
    'ishchi': (password: 'ishchi123', user: const AppUser(id: 3, username: 'ishchi', fullName: 'Ishchi Bobur', role: Role.ishchi)),
  };

  final List<MockSaleEntry> sales = [
    MockSaleEntry(
      result: SaleResult(
        id: 99,
        total: 540000,
        paid: 300000,
        debt: 240000,
        customerName: 'Akmal aka',
        customerPhone: '+998 90 123 45 67',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      cost: 360000,
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
    StockMovementRecord(id: 1, productId: 1, qtyDelta: 200, kind: 'opening', note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now().subtract(const Duration(days: 5))),
    StockMovementRecord(id: 2, productId: 2, qtyDelta: 150, kind: 'opening', note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now().subtract(const Duration(days: 5))),
    StockMovementRecord(id: 3, productId: 3, qtyDelta: 120, kind: 'opening', note: 'Boshlang‘ich qoldiq', createdAt: DateTime.now().subtract(const Duration(days: 5))),
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
    await Future.delayed(const Duration(milliseconds: 250));
    final rec = _s.users[username.trim()];
    if (rec == null || rec.password != password) throw ApiException('Login yoki parol noto‘g‘ri', 401);
    if (rec.user.role != role) throw ApiException('Bu akkaunt tanlangan rol uchun emas', 403);
    return rec.user;
  }

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
      donaM2: p.donaM2, price: p.price, costPrice: p.costPrice, stock: initialStock,
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
      price: p.price, costPrice: p.costPrice, stock: old.stock, // qoldiq faqat harakatlar orqali o'zgaradi
    );
    _s.products[i] = updated;
    return updated;
  }

  @override
  Future<void> deactivate(int id) async => _s.products.removeWhere((p) => p.id == id);
}

class MockSalesRepository implements SalesRepository {
  MockSalesRepository(this._s);
  final MockStore _s;

  @override
  Future<SaleResult> createSale({
    required List<CartLine> lines,
    required double paidAmount,
    String? customerName,
    String? customerPhone,
  }) async {
    if (lines.isEmpty) throw ApiException('Savat bo‘sh', 400);
    final reserved = <int, double>{};
    var total = 0.0, cost = 0.0;
    for (final l in lines) {
      final i = _s.indexOf(l.product.id);
      if (i < 0) throw ApiException('Mahsulot topilmadi', 404);
      final p = _s.products[i];
      final q = l.baseQty;
      final available = p.stock - (reserved[p.id] ?? 0);
      if (q <= 0) throw ApiException('${p.name}: miqdor 0 dan katta bo‘lsin', 400);
      if (q > available + 1e-9) throw ApiException('${p.name}: omborda yetarli emas (bor: $available ${p.unit})', 400);
      reserved[p.id] = (reserved[p.id] ?? 0) + q;
      total += q * p.price;
      cost += q * p.costPrice;
    }
    if (paidAmount < 0 || paidAmount > total + 1e-6) throw ApiException('To‘lov summasi noto‘g‘ri', 400);
    final debt = total - paidAmount;
    if (debt > 0.005 && (customerName == null || customerName.trim().isEmpty)) {
      throw ApiException('Nasiya uchun mijoz ko‘rsatilishi shart', 400);
    }
    final saleId = _s.nextId++;
    reserved.forEach((id, q) {
      _s.setStock(id, _s.products[_s.indexOf(id)].stock - q);
      _s.movements.add(StockMovementRecord(
        id: _s.nextId++, productId: id, qtyDelta: -q, kind: 'sale',
        note: 'Savdo #$saleId', createdAt: DateTime.now(),
      ));
    });

    final res = SaleResult(
      id: saleId, total: total, paid: paidAmount, debt: debt,
      customerName: customerName, customerPhone: customerPhone, createdAt: DateTime.now(),
    );
    _s.sales.add(MockSaleEntry(result: res, cost: cost));
    return res;
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
    final updated = SaleResult(
      id: entry.result.id,
      total: entry.result.total,
      paid: newPaid,
      debt: newDebt,
      customerName: entry.result.customerName,
      customerPhone: entry.result.customerPhone,
      createdAt: entry.result.createdAt,
    );
    entry.result = updated;
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
  }) async {
    if (_s.users.containsKey(username.trim())) {
      throw ApiException('Bu login allaqachon mavjud', 409);
    }
    final user = AppUser(
      id: _s.nextUserId++,
      username: username.trim(),
      fullName: fullName.trim(),
      role: role,
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
      isActive: isActive ?? oldUser.isActive,
    );
    _s.users[entry.key] = (
      password: (password != null && password.isNotEmpty) ? password : entry.value.password,
      user: updated,
    );
    return updated;
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
      id: _s.nextId++, productId: productId, qtyDelta: quantity, kind: 'purchase',
      note: note ?? 'Xarid kirimi', createdAt: DateTime.now(),
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
  }
}
