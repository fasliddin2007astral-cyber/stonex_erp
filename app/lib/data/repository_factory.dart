import '../core/config.dart';
import 'api_client.dart';
import 'api_repositories.dart';
import 'mock_repositories.dart';
import 'repositories.dart';

/// Mock <-> API almashtirish FAQAT shu yerda. Ekranlar o'zgarmaydi.
AppRepositories buildRepositories() {
  if (AppConfig.useMock) {
    final s = MockStore();
    return AppRepositories(
      auth: MockAuthRepository(s),
      products: MockProductRepository(s),
      sales: MockSalesRepository(s),
      finance: MockFinanceRepository(s),
      production: MockProductionRepository(s),
      users: MockUserRepository(s),
      stock: MockStockRepository(s),
    );
  }
  final api = ApiClient(AppConfig.apiBaseUrl);
  return AppRepositories(
    auth: ApiAuthRepository(api),
    products: ApiProductRepository(api),
    sales: ApiSalesRepository(api),
    finance: ApiFinanceRepository(api),
    production: ApiProductionRepository(api),
    users: ApiUserRepository(api),
    stock: ApiStockRepository(api),
  );
}
