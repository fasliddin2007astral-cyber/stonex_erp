import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../domain/models.dart';

class CartController extends ChangeNotifier {
  CartController(this._sales);
  final SalesRepository _sales;

  final List<CartLine> lines = [];
  final List<HeldCart> heldCarts = [];
  bool busy = false;

  double get total => lines.fold(0, (a, l) => a + l.lineTotal);

  void add(
    Product p, {
    double quantity = 1,
    String? sort,
    double? cutLength,
    double? cutWidth,
    int? cutPieces,
    String? cutSpec,
  }) {
    final effectiveSort = sort ?? (p.hasSorts ? '1.5' : (p.sort != null && p.sort!.isNotEmpty ? p.sort : null));
    final existing = lines.where((l) =>
        l.product.id == p.id &&
        l.sort == effectiveSort &&
        l.cutSpec == cutSpec);
    if (existing.isNotEmpty && cutSpec == null) {
      existing.first.quantity += quantity;
    } else {
      lines.add(CartLine(
        p,
        quantity: quantity,
        sort: effectiveSort,
        cutLength: cutLength,
        cutWidth: cutWidth,
        cutPieces: cutPieces,
        cutSpec: cutSpec,
      ));
    }
    notifyListeners();
  }

  void update(
    CartLine l, {
    double? quantity,
    bool? inDona,
    String? sort,
    double? cutLength,
    double? cutWidth,
    int? cutPieces,
    String? cutSpec,
  }) {
    if (quantity != null && quantity > 0) l.quantity = quantity;
    if (inDona != null) l.inDona = inDona && l.product.hasDona;
    if (sort != null) l.sort = sort;
    if (cutLength != null) l.cutLength = cutLength;
    if (cutWidth != null) l.cutWidth = cutWidth;
    if (cutPieces != null) l.cutPieces = cutPieces;
    if (cutSpec != null) l.cutSpec = cutSpec;
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

  /// Joriy savatni kechiktirish (boshqa mijozga navbat berish uchun saqlab qo'yish)
  void holdCurrentCart({String? label}) {
    if (lines.isEmpty) return;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final defaultLabel = '${heldCarts.length + 1}-mijoz ($timeStr)';

    heldCarts.add(HeldCart(
      id: now.millisecondsSinceEpoch.toString(),
      label: (label != null && label.trim().isNotEmpty) ? label.trim() : defaultLabel,
      createdAt: now,
      lines: lines.map((l) => l.copy()).toList(),
    ));
    lines.clear();
    notifyListeners();
  }

  /// Kechiktirilgan savatni qayta tiklash
  void restoreHeldCart(HeldCart cart) {
    if (!heldCarts.contains(cart)) return;

    // Agar kassa savatida tovarlar bo'lsa, uni avtomatik kechiktiramiz (swap)
    if (lines.isNotEmpty) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      heldCarts.add(HeldCart(
        id: now.millisecondsSinceEpoch.toString(),
        label: '${heldCarts.length + 1}-mijoz ($timeStr)',
        createdAt: now,
        lines: lines.map((l) => l.copy()).toList(),
      ));
    }

    lines.clear();
    lines.addAll(cart.lines.map((l) => l.copy()));
    heldCarts.remove(cart);
    notifyListeners();
  }

  /// Kechiktirilgan savatni o'chirish (mijoz qaytib kelmasa)
  void removeHeldCart(HeldCart cart) {
    heldCarts.remove(cart);
    notifyListeners();
  }

  /// Muvaffaqiyatli bo'lsa savatni tozalaydi; xato bo'lsa savat saqlanadi va xato yuqoriga uzatiladi.
  Future<SaleResult> checkout({
    required double paid,
    String status = 'completed',
    String? note,
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
        status: status,
        note: note,
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
