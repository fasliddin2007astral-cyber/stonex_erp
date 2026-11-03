import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/cart_controller.dart';
import 'common.dart';

/// Toshga ishlov berish xizmatlari modeli
class StoneServiceDef {
  final String key;
  final String name;
  final String unit;
  final String description;
  final IconData icon;
  final double defaultPrice;
  final int defaultProductId;

  const StoneServiceDef({
    required this.key,
    required this.name,
    required this.unit,
    required this.description,
    required this.icon,
    required this.defaultPrice,
    required this.defaultProductId,
  });
}

const List<StoneServiceDef> kStoneServices = [
  StoneServiceDef(
    key: 'cut',
    name: 'Razmer kesish',
    unit: 'metr',
    description: 'Plita va toshlarni buyurtma bo‘yicha aniq o‘lchamda kesish',
    icon: Icons.content_cut_rounded,
    defaultPrice: 15000,
    defaultProductId: 19,
  ),
  StoneServiceDef(
    key: 'chamfer',
    name: 'Faska ochish',
    unit: 'metr',
    description: 'Zinapoya, podokonnik yoki plita chetlariga faska berish',
    icon: Icons.architecture_rounded,
    defaultPrice: 20000,
    defaultProductId: 20,
  ),
  StoneServiceDef(
    key: 'polish',
    name: 'Silliqlash',
    unit: 'metr',
    description: 'Tosh yuzasini yoki qirralarini tekislash va jilolash',
    icon: Icons.auto_awesome_rounded,
    defaultPrice: 25000,
    defaultProductId: 21,
  ),
  StoneServiceDef(
    key: 'groove',
    name: 'Chizish',
    unit: 'metr',
    description: 'Zinapoyalarga sirpanishga qarshi (antislip) yo‘llar chizish',
    icon: Icons.line_weight_rounded,
    defaultPrice: 10000,
    defaultProductId: 22,
  ),
];

/// Xizmat narxlarini doimiy saqlash (in-memory + database sync)
class StoneServicesStore {
  static final Map<String, double> _prices = {
    'cut': 15000,
    'chamfer': 20000,
    'polish': 25000,
    'groove': 10000,
  };

  static double getPrice(String key) => _prices[key] ?? 10000;

  static void setPrice(String key, double price) {
    _prices[key] = price;
  }

  static Map<String, double> getAllPrices() => Map.unmodifiable(_prices);

  /// Repozitoriyadan eng so'nggi xizmat narxlarini yuklash
  static Future<void> syncFromRepo(ProductRepository repo) async {
    try {
      final list = await repo.list();
      for (final def in kStoneServices) {
        final p = list.where((prod) =>
            prod.id == def.defaultProductId ||
            prod.name.trim().toLowerCase() == def.name.toLowerCase()).firstOrNull;
        if (p != null && p.price > 0) {
          _prices[def.key] = p.price;
        }
      }
    } catch (_) {}
  }
}

/// Kassada xizmatlarni tanlash va savatga qo'shish oynasi
class StoneServicesDialog extends StatefulWidget {
  const StoneServicesDialog({super.key, required this.user});
  final AppUser user;

  static Future<void> show(BuildContext context, {required AppUser user}) async {
    final msg = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StoneServicesDialog(user: user),
    );
    if (msg != null && context.mounted) {
      showMessage(context, msg);
    }
  }

  @override
  State<StoneServicesDialog> createState() => _StoneServicesDialogState();
}

class _StoneServicesDialogState extends State<StoneServicesDialog> {
  int _selectedServiceIdx = 0;
  final _qtyCtrl = TextEditingController(text: '1.0');
  final _noteCtrl = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    setState(() => _syncing = true);
    final repo = context.read<AppRepositories>().products;
    await StoneServicesStore.syncFromRepo(repo);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _currentQty {
    final v = double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
    return (v != null && v > 0) ? v : 1.0;
  }

  void _adjustQty(double delta) {
    final next = (_currentQty + delta);
    if (next < 0.1) return;
    final formatted = next == next.roundToDouble()
        ? next.toInt().toString()
        : next.toStringAsFixed(1);
    _qtyCtrl.text = formatted;
    setState(() {});
  }

  void _setQty(double val) {
    if (val <= 0) return;
    final formatted = val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    _qtyCtrl.text = formatted;
    setState(() {});
  }

  Future<void> _addToCart() async {
    final def = kStoneServices[_selectedServiceIdx];
    final qty = _currentQty;
    final price = StoneServicesStore.getPrice(def.key);
    final note = _noteCtrl.text.trim();

    final repos = context.read<AppRepositories>();
    final cart = context.read<CartController>();

    Product? targetProduct;
    try {
      final prods = await repos.products.list();
      targetProduct = prods.where((p) =>
          p.id == def.defaultProductId ||
          p.name.trim().toLowerCase() == def.name.toLowerCase()).firstOrNull;
    } catch (_) {}

    targetProduct ??= Product(
      id: def.defaultProductId,
      name: def.name,
      category: 'Xizmat',
      unit: def.unit,
      price: price,
      costPrice: 0,
      stock: 999999,
      minStock: 0,
    );

    final specText = note.isNotEmpty ? '$note ($qty ${def.unit})' : '$qty ${def.unit}';

    cart.add(
      targetProduct,
      quantity: qty,
      cutSpec: specText,
    );

    // Agar narx yangilangan bo'lsa override qo'llaymiz
    if (cart.lines.isNotEmpty) {
      final line = cart.lines.last;
      if (line.product.id == targetProduct.id && line.unitPrice != price) {
        cart.update(line, unitPriceOverride: price);
      }
    }

    if (mounted) {
      Navigator.pop(context, '${def.name} ($qty ${def.unit}) savatga qo‘shildi');
    }
  }

  Future<void> _openAdminPriceConfig() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const ServicesPriceConfigDialog(),
    );
    if (updated == true && mounted) {
      showMessage(context, 'Xizmatlar narxi muvaffaqiyatli saqlandi');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isAdmin = widget.user.role == Role.admin;
    final curDef = kStoneServices[_selectedServiceIdx];
    final curPrice = StoneServicesStore.getPrice(curDef.key);
    final total = _currentQty * curPrice;

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 660,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: context.dialogBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sarlavha paneli
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.neonLime.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.neonLime.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.design_services_rounded,
                      color: isDark ? AppColors.neonLime : AppColors.ink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xizmatlar (Toshga ishlov berish)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.inkColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kesish, faska, silliqlash va chizish xizmatlarini savatga qo‘shish',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Xizmatlar narxini sozlash (Admin)',
                      child: OutlinedButton.icon(
                        onPressed: _openAdminPriceConfig,
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: Text(
                          isCompact ? 'Narx' : 'Narxlarni sozlash',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.neonLime : AppColors.ink,
                          side: BorderSide(
                            color: isDark ? AppColors.neonLime.withValues(alpha: 0.5) : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Yopish',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Xizmatlarni tanlash va parametrlari
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 4 ta Xizmat tanlash kartalari
                    Text(
                      'Xizmat turini tanlang:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.mutedColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 480;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 4 : 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: isWide ? 1.15 : 1.4,
                          ),
                          itemCount: kStoneServices.length,
                          itemBuilder: (ctx, i) {
                            final def = kStoneServices[i];
                            final sel = i == _selectedServiceIdx;
                            final price = StoneServicesStore.getPrice(def.key);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedServiceIdx = i;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? (isDark
                                          ? AppColors.neonLime.withValues(alpha: 0.12)
                                          : const Color(0xFFF0FDF4))
                                      : context.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: sel
                                        ? (isDark ? AppColors.neonLime : const Color(0xFF16A34A))
                                        : context.borderColor,
                                    width: sel ? 1.6 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      def.icon,
                                      size: 24,
                                      color: sel
                                          ? (isDark ? AppColors.neonLime : const Color(0xFF16A34A))
                                          : context.mutedColor,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      def.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                        color: sel ? context.inkColor : context.inkColor.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${money(price)} / ${def.unit}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? (isDark ? AppColors.neonLime : const Color(0xFF16A34A))
                                            : context.mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // Tanlangan xizmat tavsifi
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(curDef.icon, size: 20, color: isDark ? AppColors.neonLime : AppColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  curDef.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: context.inkColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  curDef.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF232832) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${money(curPrice)} / ${curDef.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: context.inkColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Miqdor kiritish (metr)
                    Text(
                      'Miqdor (${curDef.unit}):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.mutedColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        // Kamaytirish
                        IconButton.filledTonal(
                          onPressed: () => _adjustQty(-1.0),
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: context.cardColor,
                            foregroundColor: context.inkColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: context.borderColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Matn maydoni
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: context.inkColor,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.cardColor,
                              suffixText: curDef.unit,
                              suffixStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.mutedColor,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: context.borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark ? AppColors.neonLime : AppColors.ink,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Ko'paytirish
                        IconButton.filledTonal(
                          onPressed: () => _adjustQty(1.0),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: context.cardColor,
                            foregroundColor: context.inkColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: context.borderColor),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Tezkor miqdor tugmalari
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1, 2, 5, 10, 20, 50].map((q) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text('+$q ${curDef.unit}'),
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: context.inkColor,
                              ),
                              backgroundColor: context.cardColor,
                              side: BorderSide(color: context.borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              onPressed: () => _adjustQty(q.toDouble()),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Izoh yoki tosh nomi
                    Text(
                      'Izoh yoki buyurtma tafsiloti (ixtiyoriy):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.mutedColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      style: TextStyle(fontSize: 13, color: context.inkColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.cardColor,
                        hintText: 'Masalan: 3-etaj pillapoyaga, Angola toshiga...',
                        hintStyle: TextStyle(fontSize: 13, color: context.mutedColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.neonLime : AppColors.ink,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Pastki xulosa va Savatga qo'shish paneli
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hisoblangan summa:',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        money(total),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.neonLime : const Color(0xFF16A34A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Bekor qilish',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.mutedColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _currentQty > 0 ? _addToCart : null,
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: const Text(
                          'Savatga qo‘shish',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? AppColors.neonLime : AppColors.darkCard,
                          foregroundColor: isDark ? AppColors.ink : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin uchun xizmatlar narxini sozlash va belgilash oynasi
class ServicesPriceConfigDialog extends StatefulWidget {
  const ServicesPriceConfigDialog({super.key});

  @override
  State<ServicesPriceConfigDialog> createState() => _ServicesPriceConfigDialogState();
}

class _ServicesPriceConfigDialogState extends State<ServicesPriceConfigDialog> {
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final def in kStoneServices)
        def.key: TextEditingController(
          text: StoneServicesStore.getPrice(def.key).round().toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repos = context.read<AppRepositories>();
      final prods = await repos.products.list();

      for (final def in kStoneServices) {
        final val = parseInput(_ctrls[def.key]?.text ?? '');
        if (val != null && val >= 0) {
          StoneServicesStore.setPrice(def.key, val);

          // Bazadagi tegishli mahsulot narxini ham yangilaymiz
          final p = prods.where((prod) =>
              prod.id == def.defaultProductId ||
              prod.name.trim().toLowerCase() == def.name.toLowerCase()).firstOrNull;

          if (p != null) {
            final updated = p.copyWith(price: val);
            await repos.products.update(updated);
          }
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        showMessage(context, 'Xizmatlar narxi muvaffaqiyatli saqlandi');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Xatolik: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: context.dialogBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sarlavha
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.neonLime.withValues(alpha: 0.15)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.price_change_rounded,
                      color: isDark ? AppColors.neonLime : AppColors.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xizmatlar narxini belgilash',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: context.inkColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Faqat Admin uchun: har bir xizmatning 1 metr narxi',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Form elementlari
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  for (final def in kStoneServices) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(def.icon, size: 18, color: isDark ? AppColors.neonLime : AppColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.inkColor,
                                  ),
                                ),
                                Text(
                                  '1 ${def.unit} uchun',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _ctrls[def.key],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.inkColor,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: context.cardColor,
                                isDense: true,
                                suffixText: " so'm",
                                suffixStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.mutedColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark ? AppColors.neonLime : AppColors.ink,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // Amallar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(
                      'Bekor qilish',
                      style: TextStyle(color: context.mutedColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? AppColors.neonLime : AppColors.darkCard,
                      foregroundColor: isDark ? AppColors.ink : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? AppColors.ink : Colors.white,
                            ),
                          )
                        : const Text(
                            'Saqlash',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
