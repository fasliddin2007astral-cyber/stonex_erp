import 'package:flutter_test/flutter_test.dart';
import 'package:stonex_erp/core/format.dart';
import 'package:stonex_erp/core/units.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/domain/models.dart';
import 'package:stonex_erp/state/cart_controller.dart';
import 'package:stonex_erp/state/currency_controller.dart';

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

  test('Mahsulot sortiga qarab har xil narx, tosh qalinligi va savat dinamikasi', () async {
    final s = MockStore();
    final salesRepo = MockSalesRepository(s);
    final prodRepo = MockProductRepository(s);

    // Kafel tosh mahsuloti: 3 xil sorti bor, qalinligi 2.0 sm
    final stone = await prodRepo.create(const Product(
      id: 0,
      name: 'Travertin Klassik',
      unit: 'm2',
      hasSorts: true,
      thickness: 2.0,
      price: 200000, // standart / bazaviy
      priceSort1: 220000, // 1-sort narxi
      priceSort1_5: 200000, // 1.5-sort narxi
      priceSort2: 170000, // 2-sort narxi
      costPrice: 120000,
    ), initialStock: 100);

    expect(stone.thickness, 2.0);
    expect(stone.priceForSort('1'), 220000);
    expect(stone.priceForSort('1.5'), 200000);
    expect(stone.priceForSort('2'), 170000);
    expect(stone.priceForSort('oliy'), 200000); // fallback to base

    final cart = CartController(salesRepo);
    cart.add(stone, quantity: 10); // default sort = '1.5'
    expect(cart.lines.first.sort, '1.5');
    expect(cart.lines.first.unitPrice, 200000);
    expect(cart.lines.first.lineTotal, 2000000);
    expect(cart.total, 2000000);

    // Kassir 1-sortni tanlaganda narx avtomatik 220 000 ga o'zgaradi
    cart.update(cart.lines.first, sort: '1');
    expect(cart.lines.first.unitPrice, 220000);
    expect(cart.lines.first.lineTotal, 2200000);
    expect(cart.total, 2200000);

    // Kassir 2-sortni tanlaganda narx avtomatik 170 000 ga o'zgaradi
    cart.update(cart.lines.first, sort: '2');
    expect(cart.lines.first.unitPrice, 170000);
    expect(cart.lines.first.lineTotal, 1700000);
    expect(cart.total, 1700000);

    // Razmer / kesish kalkulyatori: qalinlik (2.0 sm), bo'yi 1.2m, eni 0.6m, 5 dona
    cart.update(
      cart.lines.first,
      cutLength: 1.2,
      cutWidth: 0.6,
      cutThickness: 2.0,
      cutPieces: 5,
      cutSpec: '1.2×0.6m (2 sm, 5 dona)',
    );
    expect(cart.lines.first.cutThickness, 2.0);
    expect(cart.lines.first.displayName, contains('2 sm, 5 dona'));
    expect(cart.lines.first.displayName, contains('2-sort'));

    // Savdoni yakunlash
    final sale = await cart.checkout(paid: cart.total);
    expect(sale.total, 1700000);
    expect(sale.items.first.unitPrice, 170000);
  });

  test('Mahsulot rangi (masalan Angola: Ko‘k, Oq, Qora) va savatda rang tanlash', () async {
    final s = MockStore();
    final salesRepo = MockSalesRepository(s);
    final prodRepo = MockProductRepository(s);

    // Angola toshi: Ko'k, Oq, Qora ranglari mavjud
    final angola = await prodRepo.create(const Product(
      id: 0,
      name: 'Angola Granit',
      unit: 'm2',
      color: 'Ko‘k, Oq, Qora',
      price: 250000,
      costPrice: 160000,
    ), initialStock: 80);

    expect(angola.color, 'Ko‘k, Oq, Qora');
    expect(angola.hasMultipleColors, true);
    expect(angola.availableColors, ['Ko‘k', 'Oq', 'Qora']);

    // Rang bo'yicha qidiruv
    final foundBlue = await prodRepo.list(query: 'ko‘k');
    expect(foundBlue.any((p) => p.id == angola.id), true);

    // Savatga qo'shish
    final cart = CartController(salesRepo);
    cart.add(angola, quantity: 5); // default birinchi rang: Ko'k
    expect(cart.lines.first.color, 'Ko‘k');
    expect(cart.lines.first.displayName, contains('(Ko‘k)'));

    // Rangini Oq ga o'zgartirish
    cart.update(cart.lines.first, color: 'Oq');
    expect(cart.lines.first.color, 'Oq');
    expect(cart.lines.first.displayName, contains('(Oq)'));

    // Bitta aniq rangli mahsulot (masalan Angola Qora)
    final angolaBlack = await prodRepo.create(const Product(
      id: 0,
      name: 'Angola Black',
      unit: 'm2',
      color: 'Qora',
      price: 260000,
      costPrice: 170000,
    ), initialStock: 40);

    expect(angolaBlack.availableColors, ['Qora']);
    expect(angolaBlack.hasMultipleColors, false);

    cart.add(angolaBlack, quantity: 2);
    expect(cart.lines.last.color, 'Qora');

    final sale = await cart.checkout(paid: cart.total);
    expect(sale.items.length, 2);
    expect(sale.items.first.productName, contains('(Oq)'));
  });

  test('Valyuta kursi, So‘m va Dollar ikkalasida savdo va to‘lov', () async {
    // 1. Format tekshirish
    expect(moneyUsd(100), '\$100');
    expect(moneyUsd(100.5), '\$100.50');
    expect(moneyDual(1200000, 12000), '1 200 000 so‘m (\$100)');

    // 2. CurrencyController
    final curr = CurrencyController();
    expect(curr.usdRate, greaterThan(10000));
    final rate = 12000.0;
    curr.setCustomRate(rate);
    expect(curr.isCustom, true);
    expect(curr.usdRate, rate);
    expect(curr.toUsd(120000), 10.0);
    expect(curr.toUzs(10.0), 120000.0);

    // 3. Savdoda so'm va dollar aralash to'lov
    final s = MockStore();
    final salesRepo = MockSalesRepository(s);
    final cart = CartController(salesRepo);
    final p = s.products.first; // 180 000 so'm
    cart.add(p, quantity: 2); // 360 000 so'm ($30 at 12 000 rate)

    // Mijoz $20 dollar naqd berdi ($20 * 12 000 = 240 000 so'm) + 120 000 so'm kesh
    final sale = await cart.checkout(
      paid: 360000,
      currencyRate: rate,
      paidUzs: 120000,
      paidUsd: 20,
    );
    expect(sale.total, 360000);
    expect(sale.paid, 360000);
    expect(sale.currencyRate, 12000);
    expect(sale.paidUzs, 120000);
    expect(sale.paidUsd, 20);
    expect(sale.debt, 0);
  });
}
