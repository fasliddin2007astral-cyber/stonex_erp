import '../domain/models.dart';

/// UI faqat shu interfeyslarga murojaat qiladi. Mock yoki API ekanini bilmaydi.
abstract class AuthRepository {
  Future<AppUser> login(String username, String password, Role role);
  Future<AppUser?> tryRestoreSession();
  Future<void> logout();
}

abstract class ProductRepository {
  Future<List<Product>> list({String? query});
  Future<Product?> findByCode(String code);
  Future<Product> create(Product p, {double initialStock = 0});
  Future<Product> update(Product p);
  Future<void> deactivate(int id);
  Future<String> uploadImage(List<int> bytes, String filename);
  Future<Product> uploadProductImage(int productId, List<int> bytes, String filename);
}

abstract class SalesRepository {
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
  });
  Future<List<SaleResult>> listSales({int limit = 50, String? status});
  Future<List<SaleResult>> listDebts();
  Future<SaleResult> payDebt(int saleId, double amount, {String method = 'cash'});
  Future<SaleResult> fulfillOrder(int saleId);
  Future<SaleResult> cancelOrder(int saleId);
}

abstract class CustomerRepository {
  Future<List<Customer>> listCustomers({String? query});
  Future<Customer> getCustomer(int id);
  Future<Customer> createCustomer(Customer customer);
  Future<Customer> updateCustomer(Customer customer);
  Future<String> uploadCustomerImage(List<int> bytes, String filename);
  Future<void> deleteCustomer(int id);
}

abstract class FinanceRepository {
  Future<FinanceSummary> summary();
}

abstract class ProductionRepository {
  Future<List<ProductionTask>> list();
  Future<List<AppUser>> workers();
  Future<void> create({required int productId, required int workerId, required double plannedQty});
  Future<void> report(int taskId, double producedQty);
}

abstract class UserRepository {
  Future<List<AppUser>> list({String? role});
  Future<AppUser> create({
    required String username,
    required String fullName,
    required String password,
    required Role role,
  });
  Future<AppUser> update(
    int id, {
    String? fullName,
    String? password,
    Role? role,
    bool? isActive,
  });
}

abstract class StockRepository {
  Future<List<StockMovementRecord>> movements({int? productId});
  Future<void> purchase({
    required int productId,
    required double quantity,
    required double unitCost,
    String? note,
  });
  Future<void> adjust({
    required int productId,
    required double delta,
    required String note,
  });
}

abstract class NotificationRepository {
  Future<List<AppNotification>> list({int limit = 50});
  Future<void> markRead(int id);
  Future<void> markAllRead();
}

class AppRepositories {
  final AuthRepository auth;
  final ProductRepository products;
  final SalesRepository sales;
  final FinanceRepository finance;
  final ProductionRepository production;
  final UserRepository users;
  final StockRepository stock;
  final NotificationRepository notifications;
  final CustomerRepository customers;

  const AppRepositories({
    required this.auth,
    required this.products,
    required this.sales,
    required this.finance,
    required this.production,
    required this.users,
    required this.stock,
    required this.notifications,
    required this.customers,
  });
}

