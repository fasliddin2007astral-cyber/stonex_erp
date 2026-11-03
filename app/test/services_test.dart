import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/data/repositories.dart';
import 'package:stonex_erp/domain/models.dart';
import 'package:stonex_erp/state/auth_controller.dart';
import 'package:stonex_erp/state/cart_controller.dart';
import 'package:stonex_erp/state/currency_controller.dart';
import 'package:stonex_erp/state/theme_controller.dart';
import 'package:stonex_erp/ui/stone_services_dialog.dart';

void main() {
  group('Xizmatlar (Toshga ishlov berish: kesish, faska, silliqlash, chizish)', () {
    late MockStore store;
    late AppRepositories repos;
    late CartController cart;

    setUp(() {
      store = MockStore();
      repos = AppRepositories(
        auth: MockAuthRepository(store),
        products: MockProductRepository(store),
        sales: MockSalesRepository(store),
        finance: MockFinanceRepository(store),
        production: MockProductionRepository(store),
        users: MockUserRepository(store),
        stock: MockStockRepository(store),
        notifications: MockNotificationRepository(store),
        customers: MockCustomerRepository(store),
        attendance: MockAttendanceRepository(store),
      );
      cart = CartController(repos.sales);
    });

    test('4 ta xizmat mavjudligi va standart narxlari', () {
      expect(kStoneServices.length, 4);
      final names = kStoneServices.map((s) => s.name).toList();
      expect(names, containsAll(['Razmer kesish', 'Faska ochish', 'Silliqlash', 'Chizish']));

      expect(StoneServicesStore.getPrice('cut'), 15000);
      expect(StoneServicesStore.getPrice('chamfer'), 20000);
      expect(StoneServicesStore.getPrice('polish'), 25000);
      expect(StoneServicesStore.getPrice('groove'), 10000);
    });

    test('Xizmat savatga to‘g‘ri qo‘shiladi va jami summa hisoblanadi', () async {
      final cutDef = kStoneServices.firstWhere((s) => s.key == 'cut');
      final product = await repos.products.findByCode(cutDef.key) ??
          Product(
            id: cutDef.defaultProductId,
            name: cutDef.name,
            category: 'Xizmat',
            unit: 'metr',
            price: 15000,
            costPrice: 0,
            stock: 999999,
          );

      // 12 metr razmer kesish
      cart.add(product, quantity: 12, cutSpec: '12 metr');
      expect(cart.lines.length, 1);
      final line = cart.lines.first;
      expect(line.product.name, 'Razmer kesish');
      expect(line.quantity, 12);
      expect(line.unitPrice, 15000);
      expect(line.lineTotal, 180000);
    });

    testWidgets('StoneServicesDialog render bo‘ladi va xizmat savatga qo‘shiladi', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final adminUser = const AppUser(
        id: 1,
        username: 'admin',
        fullName: 'Admin Boshliq',
        role: Role.admin,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppRepositories>.value(value: repos),
            ChangeNotifierProvider(create: (_) => AuthController(repos.auth)),
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider(create: (_) => CurrencyController()),
            ChangeNotifierProvider(create: (_) => ThemeController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => StoneServicesDialog.show(ctx, user: adminUser),
                    child: const Text('Ochish'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ochish'));
      await tester.pumpAndSettle();

      // Dialog ochilganini tekshiramiz
      expect(find.text('Xizmatlar (Toshga ishlov berish)'), findsOneWidget);
      expect(find.text('Razmer kesish'), findsWidgets);
      expect(find.text('Faska ochish'), findsWidgets);
      expect(find.text('Silliqlash'), findsWidgets);
      expect(find.text('Chizish'), findsWidgets);

      // Admin uchun narxlarni sozlash tugmasi mavjudligini tekshiramiz
      expect(find.text('Narxlarni sozlash'), findsOneWidget);

      // Savatga qo'shish
      await tester.tap(find.text('Savatga qo‘shish'));
      await tester.pumpAndSettle();

      expect(cart.lines.isNotEmpty, true);
      expect(cart.lines.first.product.name, 'Razmer kesish');
    });

    testWidgets('ServicesPriceConfigDialog admin orqali narxlarni yangilash', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppRepositories>.value(value: repos),
            ChangeNotifierProvider.value(value: cart),
            ChangeNotifierProvider(create: (_) => CurrencyController()),
            ChangeNotifierProvider(create: (_) => ThemeController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ServicesPriceConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Xizmatlar narxini belgilash'), findsOneWidget);
      expect(find.text('Faqat Admin uchun: har bir xizmatning 1 metr narxi'), findsOneWidget);

      // Saqlash tugmasini bosish
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
    });
  });
}
