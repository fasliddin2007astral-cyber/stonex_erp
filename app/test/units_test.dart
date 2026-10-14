import 'package:flutter_test/flutter_test.dart';
import 'package:stonex_erp/core/format.dart';
import 'package:stonex_erp/core/units.dart';
import 'package:stonex_erp/data/mock_repositories.dart';
import 'package:stonex_erp/domain/models.dart';

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
}
