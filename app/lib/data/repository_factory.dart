import '../core/config.dart';
import 'api_client.dart';
import 'api_repositories.dart';
import 'mock_repositories.dart';
import 'repositories.dart';

/// Mock <-> API almashtirish FAQAT shu yerda. Ekranlar o'zgarmaydi.
final appApiClient = ApiClient(AppConfig.apiBaseUrl);

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
      notifications: MockNotificationRepository(s),
    );
  }
  return AppRepositories(
    auth: ApiAuthRepository(appApiClient),
    products: ApiProductRepository(appApiClient),
    sales: ApiSalesRepository(appApiClient),
    finance: ApiFinanceRepository(appApiClient),
    production: ApiProductionRepository(appApiClient),
    users: ApiUserRepository(appApiClient),
    stock: ApiStockRepository(appApiClient),
    notifications: ApiNotificationRepository(appApiClient),
  );
}
