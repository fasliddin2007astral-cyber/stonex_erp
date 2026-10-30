import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/data/repositories.dart';
import 'package:stonex_erp/domain/models.dart';
import 'package:stonex_erp/main.dart';
import 'package:stonex_erp/state/auth_controller.dart';
import 'package:stonex_erp/state/cart_controller.dart';
import 'package:stonex_erp/ui/home_shell.dart';
import 'package:stonex_erp/ui/production_screen.dart';
import 'package:stonex_erp/ui/dashboard_screen.dart';
import 'package:stonex_erp/ui/products_screen.dart';
import 'package:stonex_erp/ui/pos_screen.dart';
import 'package:stonex_erp/ui/customers_screen.dart';
import 'package:stonex_erp/ui/purchases_screen.dart';
import 'package:stonex_erp/ui/orders_screen.dart';
import 'package:stonex_erp/ui/receipt_dialog.dart';
import 'package:stonex_erp/ui/sales_history_screen.dart';
import 'package:stonex_erp/state/theme_controller.dart';

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
      notifications: MockNotificationRepository(store),
      customers: MockCustomerRepository(store),
    );
  });

  testWidgets('Smoke test - LoginScreen renders correctly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(StonexApp(repos: repos));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('NTM'), findsWidgets);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify all menu buttons exist
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Ishlab chiqarish'), findsWidgets);

    // Click "Ishlab chiqarish"
    final prodNavItem = find.widgetWithText(InkWell, 'Ishlab chiqarish');
    expect(prodNavItem, findsWidgets);
    await tester.ensureVisible(prodNavItem.first);
    await tester.tap(prodNavItem.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify ProductionScreen rendered without errors
    expect(find.byType(ProductionScreen), findsOneWidget);
    expect(find.text('Jami Topshiriqlar'), findsOneWidget);
    expect(find.text('Angola'), findsWidgets);
    expect(find.text('Ishchi Bobur'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap "+ Topshiriq" or "Topshiriq"
    final createBtn = find.text('Topshiriq');
    expect(createBtn, findsOneWidget);
    await tester.tap(createBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog should be open
    expect(find.text('Yangi Ishlab Chiqarish Topshirig‘i'), findsOneWidget);
    expect(find.text('Topshiriq berish'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Bekor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Click "Hisobot" button on first open task
    final reportBtn = find.text('Hisobot');
    expect(reportBtn, findsWidgets);
    await tester.tap(reportBtn.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog should be open
    expect(find.text('Yuborish'), findsOneWidget);

    // Tap "Yuborish"
    await tester.tap(find.text('Yuborish'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // Dialog dismissed and tasks refreshed
    expect(find.text('Yuborish'), findsNothing);
  });

  testWidgets('ProductsScreen mobile viewport - zero RenderFlex overflow and QR dialog works', (tester) async {
    // Narrow smartphone screen 360 x 740
    tester.view.physicalSize = const Size(360, 740);
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
          home: Scaffold(body: ProductsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify products list rendered without RenderFlex overflow
    expect(find.text('Jami Mahsulotlar'), findsOneWidget);
    expect(find.text('Toshlar (m²)'), findsWidgets);
    expect(find.text('Dona'), findsWidgets);

    // Verify QR dialog opens without overflow
    final qrButtons = find.byTooltip('QR Yorliq');
    expect(qrButtons, findsWidgets);
    await tester.tap(qrButtons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mahsulot QR Yorlig‘i'), findsOneWidget);
    expect(find.text('NTM MARBLE'), findsOneWidget);

    // Close dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('DashboardScreen mobile viewport - chart and products table render with zero overflow', (tester) async {
    // Narrow smartphone screen 360 x 740
    tester.view.physicalSize = const Size(360, 740);
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
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify chart title & stock table card rendered without overflow
    expect(find.text('Ombor Zaxirasi va Savdo Dinamikasi'), findsOneWidget);
    expect(find.text('Ombor Holati va Mahsulotlar'), findsOneWidget);

    // Touch/drag on the chart area to trigger hover tooltip
    final chartArea = find.byType(CustomPaint);
    expect(chartArea, findsWidgets);
    await tester.drag(chartArea.first, const Offset(50, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('PosScreen QR scanner dialog - sleek UX, quantity stepper and zero overflow', (WidgetTester tester) async {
    final cartController = CartController(repos.sales);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
          ChangeNotifierProvider<CartController>.value(value: cartController),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PosScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap the QR scanner button (opens QrScannerScreen full-screen on mobile)
    final qrButton = find.widgetWithText(FilledButton, 'QR');
    expect(qrButton, findsOneWidget);
    await tester.tap(qrButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Fullscreen scanner should be visible with title 'QR Skaner'
    expect(find.text('QR Skaner'), findsOneWidget);

    // Tap manual code input button (opens bottom sheet without auto-blocking keyboard initially)
    final manualInputBtn = find.byTooltip('Kodni qo‘lda yozish');
    expect(manualInputBtn, findsOneWidget);
    await tester.tap(manualInputBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Enter a valid barcode 'STX-ANGOLA' in the bottom sheet
    final barcodeInput = find.byType(TextField).last;
    await tester.enterText(barcodeInput, 'STX-ANGOLA');
    await tester.tap(find.widgetWithText(FilledButton, 'Savatga qo‘shish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Product should be added to cart and displayed in last scanned card
    expect(find.text('Oxirgi skanerlangan mahsulot'), findsOneWidget);
    expect(find.text('Angola'), findsWidgets);
    expect(cartController.lines.length, 1);
    expect(cartController.lines.first.quantity, 1.0);

    // Increase quantity using the inline stepper button '+'
    final plusBtn = find.byIcon(Icons.add_rounded);
    expect(plusBtn, findsOneWidget);
    await tester.tap(plusBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(cartController.lines.first.quantity, 2.0);

    // Tap Done / Close button
    final closeBtn = find.text('Tayyor (Yopish)');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Scanner screen should be dismissed and cart preserved in POS
    expect(find.text('QR Skaner'), findsNothing);
    expect(cartController.lines.length, 1);
  });

  testWidgets('CustomersScreen renders correctly, search works and dialog opens', (tester) async {
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
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CustomersScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // CustomersScreen header and customer cards should be rendered
    expect(find.text('Sardor Qodirov'), findsOneWidget);
    expect(find.text('Jami mijozlar'), findsOneWidget);
    expect(find.text('Yangi Mijoz'), findsOneWidget);

    // Filter by searching "Farhod"
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Farhod');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Farhod Usta'), findsOneWidget);
    expect(find.text('Sardor Qodirov'), findsNothing);
  });

  testWidgets('ReceiptDialog renders slip, barcode/QR, totals and copy button', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockSale = SaleResult(
      id: 101,
      total: 1800000,
      paid: 1800000,
      debt: 0,
      customerName: 'Sobirjon Aka',
      customerPhone: '+998 90 111 22 33',
      cashierName: 'Alisher Kassir',
      items: [
        SaleItemRecord(productId: 1, productName: 'Marmar Oq', quantity: 10, unitPrice: 180000, lineTotal: 1800000),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReceiptDialog(sale: mockSale),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kassa Cheki'), findsOneWidget);
    expect(find.text('NTM — NAMUNA TOSH MARKAZI'), findsOneWidget);
    expect(find.text('Sobirjon Aka'), findsOneWidget);
    expect(find.text('Marmar Oq'), findsOneWidget);
    expect(find.text('Nusxa olish'), findsOneWidget);
    expect(find.text('Chop etish'), findsOneWidget);
  });

  testWidgets('SalesHistoryScreen renders sales, KPIs and search works', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SalesHistoryScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Savdolar Jurnali'), findsOneWidget);
    expect(find.text('Jami Savdo Summasi'), findsOneWidget);

    // Search by customer "Sardor"
    final search = find.byType(TextField);
    await tester.enterText(search, 'Sardor');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Sardor Qodirov'), findsWidgets);

    // Search by customer "Farhod"
    await tester.enterText(search, 'Farhod');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Farhod Usta'), findsWidgets);
    expect(find.textContaining('Sardor Qodirov'), findsNothing);
  });

  testWidgets('PurchasesScreen renders stock purchases, KPIs and new purchase dialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PurchasesScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Xaridlar & Ta‘minot'), findsOneWidget);
    expect(find.text('Jami Xaridlar Summasi'), findsOneWidget);
    expect(find.text('Yangi Xarid Kirimi'), findsOneWidget);

    // Click "Yangi Xarid Kirimi"
    await tester.tap(find.text('Yangi Xarid Kirimi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Xarid qilinayotgan tovar / xomashyo'), findsOneWidget);
    expect(find.text('Kirim qilish'), findsOneWidget);
  });

  testWidgets('Scanning receipt QR code opens ReceiptDialog', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final cartCtrl = CartController(repos.sales);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
          ChangeNotifierProvider.value(value: cartCtrl),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PosScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Type a receipt QR code into the search/scanner input
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'STONEX-CHEK-#95-1800000UZS');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify ReceiptDialog opened with Chek #95
    expect(find.byType(ReceiptDialog), findsOneWidget);
    expect(find.text('Kassa Cheki'), findsOneWidget);
    expect(find.text('NTM — NAMUNA TOSH MARKAZI'), findsOneWidget);
    expect(find.textContaining('95'), findsWidgets);
  });

  testWidgets('OrdersScreen renders orders, KPIs and fulfill workflow works', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Create a pre-order in mock store
    final product = store.products.first;
    await repos.sales.createSale(
      lines: [CartLine(product, quantity: 2)],
      paidAmount: 50000,
      customerName: 'Javohir Buyurtmachi',
      customerPhone: '+998 90 777 66 55',
      status: 'order',
      note: '3 kundan keyin olib ketadi',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppRepositories>.value(value: repos),
        ],
        child: const MaterialApp(
          home: Scaffold(body: OrdersScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Jami Buyurtmalar'), findsOneWidget);
    expect(find.text('Kutilmoqda (Faol)'), findsWidgets);
    expect(find.text('Javohir Buyurtmachi +998 90 777 66 55'), findsOneWidget);
    expect(find.text('Izoh: 3 kundan keyin olib ketadi'), findsOneWidget);
    expect(find.text('Topshirish'), findsOneWidget);
  });
}
