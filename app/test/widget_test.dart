import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stonex_erp/core/theme.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/data/repositories.dart';
import 'package:stonex_erp/domain/models.dart';
import 'package:stonex_erp/main.dart';
import 'package:stonex_erp/state/auth_controller.dart';
import 'package:stonex_erp/state/cart_controller.dart';
import 'package:stonex_erp/ui/home_shell.dart';
import 'package:stonex_erp/ui/production_screen.dart';

void main() {
  late MockStore store;
  late AppRepositories repos;
  const adminUser = AppUser(id: 1, username: 'admin', fullName: 'Xo‘jayin', role: Role.admin);

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
    );
  });

  testWidgets('Smoke test - LoginScreen renders correctly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(StonexApp(repos: repos));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('STONEX'), findsWidgets);
    expect(find.text('Tizimga kirish'), findsWidgets);
  });

  testWidgets('Desktop HomeShell - zero overflow on smaller desktop heights and sidebar navigation works', (tester) async {
    // Testing on a laptop height with scaling (1024 x 620)
    tester.view.physicalSize = const Size(1024, 620);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authCtrl = AuthController(repos.auth);
    await authCtrl.login('admin', 'admin123', Role.admin);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
          ChangeNotifierProvider.value(value: authCtrl),
          ChangeNotifierProvider(create: (_) => CartController(repos.sales)),
        ],
        child: const MaterialApp(
          home: HomeShell(user: adminUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all menu buttons exist
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Ishlab chiqarish'), findsWidgets);

    // Click "Ishlab chiqarish"
    final prodNavItem = find.widgetWithText(InkWell, 'Ishlab chiqarish');
    expect(prodNavItem, findsWidgets);
    await tester.tap(prodNavItem.first);
    await tester.pumpAndSettle();

    // Verify ProductionScreen rendered without errors
    expect(find.byType(ProductionScreen), findsOneWidget);
    expect(find.text('Jami Topshiriqlar'), findsOneWidget);
    expect(find.text('Angola'), findsWidgets);
    expect(find.text('Ishchi Bobur'), findsWidgets);
  });

  testWidgets('ProductionScreen TaskCreateDialog works seamlessly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authCtrl = AuthController(repos.auth);
    await authCtrl.login('admin', 'admin123', Role.admin);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
          ChangeNotifierProvider.value(value: authCtrl),
          ChangeNotifierProvider(create: (_) => CartController(repos.sales)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProductionScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "+ Topshiriq" or "Topshiriq"
    final createBtn = find.text('Topshiriq');
    expect(createBtn, findsOneWidget);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Dialog should be open
    expect(find.text('Yangi Ishlab Chiqarish Topshirig‘i'), findsOneWidget);
    expect(find.text('Topshiriq berish'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Bekor'));
    await tester.pumpAndSettle();
  });

  testWidgets('ProductionScreen report work dialog and submission works without Future in setState', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authCtrl = AuthController(repos.auth);
    await authCtrl.login('ishchi', 'ishchi123', Role.ishchi);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
          ChangeNotifierProvider.value(value: authCtrl),
          ChangeNotifierProvider(create: (_) => CartController(repos.sales)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProductionScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Click "Hisobot" button on first open task
    final reportBtn = find.text('Hisobot');
    expect(reportBtn, findsWidgets);
    await tester.tap(reportBtn.first);
    await tester.pumpAndSettle();

    // Dialog should be open
    expect(find.text('Yuborish'), findsOneWidget);

    // Tap "Yuborish"
    await tester.tap(find.text('Yuborish'));
    await tester.pumpAndSettle();

    // Dialog dismissed and tasks refreshed
    expect(find.text('Yuborish'), findsNothing);
  });
}
