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
  group('Xizmatlar (Eni-bo‘yi kesish, Granit va Keramogranit silliqlash)', () {
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

    test('4 ta xizmat mavjudligi va Silliqlashda Granit va Keramogranit narxlari', () {
      expect(kStoneServices.length, 4);
      final names = kStoneServices.map((s) => s.name).toList();
      expect(names, containsAll(['Razmer kesish', 'Faska ochish', 'Silliqlash', 'Chizish']));

      expect(StoneServicesStore.getPrice('cut'), 15000);
      expect(StoneServicesStore.getPrice('chamfer'), 20000);
      expect(StoneServicesStore.getPrice('polish_granite'), 30000);
      expect(StoneServicesStore.getPrice('polish_ceramics'), 20000);
      expect(StoneServicesStore.getPrice('groove'), 10000);
    });

    test('Eni va bo‘yiga qarab kesish hisobi: 1.2 x 0.6 m · 5 dona (4 tomoni perimetr = 18m)', () {
      const l = 1.2;
      const w = 0.6;
      const pieces = 5;
      final perimeter = (l + w) * 2 * pieces;
      expect(perimeter, 18.0);

      final pricePerM = StoneServicesStore.getPrice('cut');
      final total = perimeter * pricePerM;
      expect(total, 270000.0);
    });

    testWidgets('StoneServicesDialog: Eni va bo‘yiga kesish hamda Silliqlash (Granit vs Keramogranit)', (tester) async {
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

      // Dialog va Eni-bo'yi kesish qismi render bo'lganini tekshiramiz
      expect(find.text('Xizmatlar (Toshga ishlov berish)'), findsOneWidget);
      expect(find.text('Eni va bo‘yi bo‘yicha kesish:'), findsOneWidget);
      expect(find.text('4 tomoni (Perimetr)'), findsOneWidget);

      // Savatga qo'shish
      await tester.tap(find.text('Savatga qo‘shish'));
      await tester.pumpAndSettle();

      expect(cart.lines.isNotEmpty, true);
      expect(cart.lines.first.product.name, 'Razmer kesish');
      expect(cart.lines.first.cutLength, 1.2);
      expect(cart.lines.first.cutWidth, 0.6);

      // Endi Silliqlashni ochib, Keramogranitni tanlash
      await tester.tap(find.text('Ochish'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Silliqlash'));
      await tester.pumpAndSettle();

      // Granit va Keramogranit tanlovi borligini tekshiramiz
      expect(find.text('Silliqlash uchun materialni tanlang:'), findsOneWidget);
      expect(find.byIcon(Icons.terrain_rounded), findsWidgets);
      expect(find.byIcon(Icons.grid_view_rounded), findsWidgets);

      // Keramogranit chipini tanlaymiz
      await tester.tap(find.textContaining('Keramogranit'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Savatga qo'shish
      await tester.tap(find.text('Savatga qo‘shish'));
      await tester.pumpAndSettle();

      final silliqLine = cart.lines.firstWhere((l) => l.product.name.contains('Silliqlash'));
      expect(silliqLine.product.name, contains('Keramogranit'));
      expect(silliqLine.unitPrice, 20000);
    });

    testWidgets('ServicesPriceConfigDialog: Granit va Keramogranit alohida narx belgilash', (tester) async {
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
      expect(find.text('Silliqlash — Granit'), findsOneWidget);
      expect(find.text('Silliqlash — Keramogranit'), findsOneWidget);

      // Saqlash
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
    });
  });
}
