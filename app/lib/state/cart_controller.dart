import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../domain/models.dart';

class CartController extends ChangeNotifier {
  CartController(this._sales);
  final SalesRepository _sales;

  final List<CartLine> lines = [];
  bool busy = false;

  double get total => lines.fold(0, (a, l) => a + l.lineTotal);

  void add(Product p, {double quantity = 1}) {
    final existing = lines.where((l) => l.product.id == p.id);
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      lines.add(CartLine(p, quantity: quantity));
    }
    notifyListeners();
  }

  void update(CartLine l, {double? quantity, bool? inDona}) {
    if (quantity != null && quantity > 0) l.quantity = quantity;
    if (inDona != null) l.inDona = inDona && l.product.hasDona;
    notifyListeners();
  }

  void remove(CartLine l) {
    lines.remove(l);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }

  /// Muvaffaqiyatli bo'lsa savatni tozalaydi; xato bo'lsa savat saqlanadi va xato yuqoriga uzatiladi.
  Future<SaleResult> checkout({
    required double paid,
    int? customerId,
    String? customerName,
    String? customerPhone,
    String? customerPassport,
    String? customerPhotoUrl,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final res = await _sales.createSale(
        lines: List.of(lines),
        paidAmount: paid,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerPassport: customerPassport,
        customerPhotoUrl: customerPhotoUrl,
      );
      lines.clear();
      return res;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
