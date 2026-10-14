import '../domain/models.dart';
import 'api_client.dart';
import 'repositories.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);
  final ApiClient _api;

  @override
  Future<AppUser> login(String username, String password, Role role) async {
    final j = await _api.post('/auth/login',
        body: {'username': username, 'password': password, 'role': role.code});
    _api.token = j['access_token'] as String;
    return AppUser.fromJson(j['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async => _api.token = null;
}

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Product>> list({String? query}) async {
    final j = await _api.get('/products',
        query: (query == null || query.isEmpty) ? null : {'q': query}) as List;
    return j.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product?> findByCode(String code) async {
    try {
      final j = await _api.get('/products/by-code/${Uri.encodeComponent(code)}');
      return Product.fromJson(j as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Product> create(Product p, {double initialStock = 0}) async =>
      Product.fromJson(await _api.post('/products', body: p.toJson(initialStock: initialStock)));

  @override
  Future<Product> update(Product p) async {
    final body = p.toJson()..remove('initial_stock');
    return Product.fromJson(await _api.patch('/products/${p.id}', body: body));
  }

  @override
  Future<void> deactivate(int id) async => _api.delete('/products/$id');
}

class ApiSalesRepository implements SalesRepository {
  ApiSalesRepository(this._api);
  final ApiClient _api;

  @override
  Future<SaleResult> createSale({
    required List<CartLine> lines,
    required double paidAmount,
    String? customerName,
    String? customerPhone,
  }) async {
    final j = await _api.post('/sales', body: {
      'items': [
        for (final l in lines)
          {
            'product_id': l.product.id,
            'quantity': l.quantity,
            'unit': (l.inDona && l.product.hasDona) ? 'dona' : 'base',
          }
      ],
      'paid_amount': paidAmount,
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customer_phone': customerPhone,
    });
    return SaleResult.fromJson(j as Map<String, dynamic>);
  }
  @override
  Future<List<SaleResult>> listDebts() async {
    final j = await _api.get('/sales/debts') as List;
    return j.map((e) => SaleResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<SaleResult> payDebt(int saleId, double amount, {String method = 'cash'}) async {
    final j = await _api.post('/sales/$saleId/payments', body: {
      'amount': amount,
      'method': method,
    });
    return SaleResult.fromJson(j as Map<String, dynamic>);
  }
}

class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository(this._api);
  final ApiClient _api;

  @override
  Future<FinanceSummary> summary() async =>
      FinanceSummary.fromJson(await _api.get('/finance/summary') as Map<String, dynamic>);
}

class ApiProductionRepository implements ProductionRepository {
  ApiProductionRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<ProductionTask>> list() async {
    final j = await _api.get('/production') as List;
    return j.map((e) => ProductionTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<AppUser>> workers() async {
    final j = await _api.get('/users', query: {'role': 'ishchi'}) as List;
    return j.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> create({required int productId, required int workerId, required double plannedQty}) async =>
      _api.post('/production',
          body: {'product_id': productId, 'assigned_to': workerId, 'planned_qty': plannedQty});

  @override
  Future<void> report(int taskId, double producedQty) async =>
      _api.post('/production/$taskId/report', body: {'produced_qty': producedQty});
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<AppUser>> list({String? role}) async {
    final j = await _api.get(
      '/users',
      query: (role != null && role.isNotEmpty) ? {'role': role} : null,
    ) as List;
    return j.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AppUser> create({
    required String username,
    required String fullName,
    required String password,
    required Role role,
  }) async {
    final j = await _api.post('/users', body: {
      'username': username,
      'full_name': fullName,
      'password': password,
      'role': role.code,
    });
    return AppUser.fromJson(j as Map<String, dynamic>);
  }

  @override
  Future<AppUser> update(
    int id, {
    String? fullName,
    String? password,
    Role? role,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (password != null && password.isNotEmpty) 'password': password,
      if (role != null) 'role': role.code,
      if (isActive != null) 'is_active': isActive,
    };
    final j = await _api.patch('/users/$id', body: body);
    return AppUser.fromJson(j as Map<String, dynamic>);
  }
}

class ApiStockRepository implements StockRepository {
  ApiStockRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<StockMovementRecord>> movements({int? productId}) async {
    final j = await _api.get(
      '/stock/movements',
      query: productId != null ? {'product_id': productId.toString()} : null,
    ) as List;
    return j.map((e) => StockMovementRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> purchase({
    required int productId,
    required double quantity,
    required double unitCost,
    String? note,
  }) async {
    await _api.post('/stock/purchase', body: {
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  @override
  Future<void> adjust({
    required int productId,
    required double delta,
    required String note,
  }) async {
    await _api.post('/stock/adjust', body: {
      'product_id': productId,
      'delta': delta,
      'note': note,
    });
  }
}
