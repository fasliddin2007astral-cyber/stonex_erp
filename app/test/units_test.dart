import 'package:flutter_test/flutter_test.dart';
import 'package:stonex_erp/core/format.dart';
import 'package:stonex_erp/core/units.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/domain/models.dart';
import 'package:stonex_erp/state/cart_controller.dart';

void main() {
  test('1 dona = 0.25 m2 faqat tosh uchun', () {
    expect(Units.donaToBase(8, 0.25), 2.0);
    expect(() => Units.donaToBase(1, null), throwsArgumentError);
  });

  test('pul formati', () {
    expect(money(1234567), '1 234 567 so‘m');
  });

  test('mock savdo qoldiqni kamaytiradi va ortiqcha sotishga yo‘l qo‘ymaydi', () async {
    final s = MockStore();
    final sales = MockSalesRepository(s);
    final angola = s.products.first; // 200 m2
    final res = await sales.createSale(lines: [CartLine(angola, quantity: 8, inDona: true)], paidAmount: 360000);
    expect(res.total, 360000);
    expect(res.debt, 0);
    expect(s.products.first.stock, 198);

    expect(
      () => sales.createSale(lines: [CartLine(s.products.first, quantity: 99999)], paidAmount: 0, customerName: 'A'),
      throwsA(isA<Exception>()),
    );
  });

  test('nasiya uchun mijoz shart', () async {
    final s = MockStore();
    final sales = MockSalesRepository(s);
    expect(
      () => sales.createSale(lines: [CartLine(s.products[4], quantity: 1)], paidAmount: 0),
      throwsA(isA<Exception>()),
    );
  });

  test('CartController kechiktirilgan savatlar (hold / restore cart) ishlaydi', () {
    final s = MockStore();
    final sales = MockSalesRepository(s);
    final ctrl = CartController(sales);

    final p1 = s.products[0];
    final p2 = s.products[1];

    // 1-mijoz savati
    ctrl.add(p1, quantity: 5);
    expect(ctrl.lines.length, 1);
    expect(ctrl.total, 5 * p1.price);

    // 1-mijozni kutishga qo'yamiz (Kechiktirish)
    ctrl.holdCurrentCart(label: '1-mijoz');
    expect(ctrl.lines.isEmpty, true);
    expect(ctrl.heldCarts.length, 1);
    expect(ctrl.heldCarts.first.label, '1-mijoz');
    expect(ctrl.heldCarts.first.lines.first.quantity, 5);

    // 2-mijoz keldi, unga tovar qo'shamiz
    ctrl.add(p2, quantity: 2);
    expect(ctrl.lines.length, 1);
    expect(ctrl.total, 2 * p2.price);

    // 1-mijoz qaytib keldi, savatini tiklaymiz (2-mijoz avtomatik kutishga o'tadi)
    final held1 = ctrl.heldCarts.first;
    ctrl.restoreHeldCart(held1);
    expect(ctrl.lines.length, 1);
    expect(ctrl.lines.first.product.id, p1.id);
    expect(ctrl.lines.first.quantity, 5);
    expect(ctrl.heldCarts.length, 1); // 2-mijoz savati kutishga o'tdi

    // Kutishdagi savatni o'chirish
    ctrl.removeHeldCart(ctrl.heldCarts.first);
    expect(ctrl.heldCarts.isEmpty, true);
  });

  test('MockAttendanceRepository check-in, check-out va oylik hisobot to‘g‘ri ishlaydi', () async {
    final s = MockStore();
    final attRepo = MockAttendanceRepository(s);

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final monthStr = '${today.year}-${today.month.toString().padLeft(2, '0')}';

    // 1-xodim (Admin) uchun keldi qilish
    final record = await attRepo.checkIn(1, note: 'Keldi');
    expect(record.userId, 1);
    expect(record.checkIn != null, true);
    expect(record.date, todayStr);

    // Ketdi qilish
    final updated = await attRepo.checkOut(1, note: 'Ish tugadi');
    expect(updated.checkOut != null, true);

    // Oylik hisobot olish
    final reports = await attRepo.getSalaryReport(month: monthStr);
    expect(reports.isNotEmpty, true);
    final adminReport = reports.firstWhere((r) => r.userId == 1);
    expect(adminReport.netSalary > 0, true);
  });

  test('Mahsulot qo‘shishda sort tanlash (1, 1.5, 2, oliy va hasSorts) to‘g‘ri saqlanadi', () async {
    final s = MockStore();
    final repo = MockProductRepository(s);

    // 1-sort tosh mahsuloti
    final p1 = await repo.create(const Product(
      id: 0,
      name: 'Marmar Oq (1-sort)',
      unit: 'm2',
      sort: '1',
      price: 220000,
      costPrice: 150000,
    ));
    expect(p1.sort, '1');
    expect(p1.sortLabel, '1-sort');

    // 2-sort tosh mahsuloti
    final p2 = await repo.create(const Product(
      id: 0,
      name: 'Marmar Oq (2-sort)',
      unit: 'm2',
      sort: '2',
      price: 180000,
      costPrice: 120000,
    ));
    expect(p2.sort, '2');
    expect(p2.sortLabel, '2-sort');

    // 3 xil sorti bor mahsulot (kassada tanlanadi)
    final pMulti = await repo.create(const Product(
      id: 0,
      name: 'Granit Granit',
      unit: 'm2',
      hasSorts: true,
      price: 300000,
      costPrice: 200000,
    ));
    expect(pMulti.hasSorts, true);
    expect(pMulti.sortLabel, '1 • 1.5 • 2 sort');

    // CartController ga qo'shilganda mahsulot sorti avtomatik biriktiriladi
    final sales = MockSalesRepository(s);
    final cart = CartController(sales);
    cart.add(p2);
    expect(cart.lines.first.sort, '2');
  });

  test('Mahsulotni qaytarish (Vozvrat) qoidalari: 10 kunlik muddat va kesilgan kafellar olinmasligi', () async {
    final s = MockStore();
    final salesRepo = MockSalesRepository(s);
    final prodRepo = MockProductRepository(s);

    final pWhole = await prodRepo.create(const Product(
      id: 0,
      name: 'Marmar Butun Plita',
      unit: 'dona',
      price: 100000,
      costPrice: 60000,
    ), initialStock: 50);

    // 1. Savdo qilish: 10 dona butun plita
    final sale1 = await salesRepo.createSale(
      lines: [CartLine(pWhole, quantity: 10)],
      paidAmount: 1000000,
    );
    expect(s.products.firstWhere((p) => p.id == pWhole.id).stock, 40); // 50 - 10

    // 2. Butun plitadan 4 dona qaytarish (10 kun ichida) -> muvaffaqiyatli
    final updated1 = await salesRepo.returnSale(
      sale1.id,
      items: [(productId: pWhole.id, quantity: 4)],
      reason: 'Ortib qolgan butun plitalar',
    );
    expect(updated1.status, 'partially_returned');
    expect(updated1.total, 600000); // 1000000 - 400000
    // Ombor qoldig'i 4 taga oshishi kerak: 40 + 4 = 44
    final reloadedP = s.products.firstWhere((p) => p.id == pWhole.id);
    expect(reloadedP.stock, 44);

    // 3. Kesilgan mahsulot qaytarilishiga yo'l qo'yilmaydi
    final cutLine = CartLine(pWhole, quantity: 2, cutLength: 1.2, cutWidth: 0.6, cutPieces: 4, cutSpec: '1.2×0.6m (4 dona)');
    expect(cutLine.displayName.contains('['), true);
    final saleCut = await salesRepo.createSale(
      lines: [cutLine],
      paidAmount: 200000,
    );
    expect(
      () => salesRepo.returnSale(saleCut.id, items: [(productId: pWhole.id, quantity: 1)]),
      throwsA(isA<Exception>()),
    );

    // 4. 10 kundan oshgan chek qaytarilishiga yo'l qo'yilmaydi
    final oldSale = sale1.copyWith(
      id: 9999,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );
    s.sales.add(MockSaleEntry(result: oldSale, cost: 400000));
    expect(
      () => salesRepo.returnSale(9999, items: [(productId: pWhole.id, quantity: 1)]),
      throwsA(isA<Exception>()),
    );
  });
}
