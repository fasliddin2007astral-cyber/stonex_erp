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
    description: 'Eni va bo‘yi bo‘yicha plita va toshlarni aniq o‘lchamda kesish',
    icon: Icons.content_cut_rounded,
    defaultPrice: 15000,
    defaultProductId: 19,
  ),
  StoneServiceDef(
    key: 'chamfer',
    name: 'Faska ochish',
    unit: 'metr',
    description: 'Zinapoya, podokonnik yoki plita chetlariga faska (qirra) berish',
    icon: Icons.architecture_rounded,
    defaultPrice: 20000,
    defaultProductId: 20,
  ),
  StoneServiceDef(
    key: 'polish',
    name: 'Silliqlash',
    unit: 'metr',
    description: 'Granit va Keramogranit toshlari yuzasi yoki qirrasini jilolash',
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
    'polish_granite': 30000,
    'polish_ceramics': 20000,
    'groove': 10000,
  };

  static double getPrice(String key) {
    if (key == 'polish') {
      return _prices['polish_granite'] ?? 30000;
    }
    return _prices[key] ?? 10000;
  }

  static void setPrice(String key, double price) {
    _prices[key] = price;
  }

  static Map<String, double> getAllPrices() => Map.unmodifiable(_prices);

  /// Repozitoriyadan eng so'nggi xizmat narxlarini yuklash
  static Future<void> syncFromRepo(ProductRepository repo) async {
    try {
      final list = await repo.list();
      for (final p in list) {
        final name = p.name.trim().toLowerCase();
        if (p.id == 19 || name.contains('kesish')) {
          _prices['cut'] = p.price;
        } else if (p.id == 20 || name.contains('faska')) {
          _prices['chamfer'] = p.price;
        } else if (p.id == 21 || (name.contains('silliq') && name.contains('granit'))) {
          _prices['polish_granite'] = p.price;
        } else if (p.id == 23 || (name.contains('silliq') && name.contains('keramo'))) {
          _prices['polish_ceramics'] = p.price;
        } else if (p.id == 22 || name.contains('chizish')) {
          _prices['groove'] = p.price;
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

  // Kesish va o'lchamlar uchun controllerlar
  // Bo'yi faqat santimetrda (sm), Eni esa metrda (m) kiritiladi va hisoblanadi
  final _lengthCtrl = TextEditingController(text: '120'); // Bo'yi (sm)
  final _widthCtrl = TextEditingController(text: '0.6');   // Eni (m)
  final _piecesCtrl = TextEditingController(text: '1');

  // Kesish rejimi: 'perimeter' (4 tomoni), 'length' (bo'yi), 'width' (eni), 'manual' (to'g'ridan-to'g'ri metr)
  String _cutMode = 'perimeter';
  final _manualMetersCtrl = TextEditingController(text: '1.0');

  // Silliqlash uchun tosh turi: 'granite' (Granit) yoki 'ceramics' (Keramogranit)
  String _polishStoneType = 'granite';

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
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _piecesCtrl.dispose();
    _manualMetersCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double _parseVal(TextEditingController ctrl) {
    final v = parseInput(ctrl.text);
    return (v != null && v > 0) ? v : 0.0;
  }

  int _parsePieces() {
    final v = int.tryParse(_piecesCtrl.text.trim());
    return (v != null && v > 0) ? v : 1;
  }

  double get _effectiveLengthM {
    final raw = _parseVal(_lengthCtrl);
    return raw / 100; // Bo'yi faqat santimetrda (sm), metrga o'tkaziladi
  }

  double get _effectiveWidthM {
    final raw = _parseVal(_widthCtrl);
    return raw; // Eni har doim metrda (m) kiritiladi va hisoblanadi
  }

  /// Jami hisoblangan metr yoki miqdor
  double get _calculatedTotalMeters {
    final def = kStoneServices[_selectedServiceIdx];
    final pieces = _parsePieces();

    if (def.key == 'cut') {
      if (_cutMode == 'manual') {
        final m = _parseVal(_manualMetersCtrl);
        return m > 0 ? m : 1.0;
      }
      final l = _effectiveLengthM;
      final w = _effectiveWidthM;

      if (_cutMode == 'perimeter') {
        // 4 tomoni: 2 * (L + W) * dona
        final perim = (l + w) * 2 * pieces;
        return double.parse(perim.toStringAsFixed(2));
      } else if (_cutMode == 'length') {
        // Bo'yi bo'yicha: L * dona
        return double.parse((l * pieces).toStringAsFixed(2));
      } else if (_cutMode == 'width') {
        // Eni bo'yicha: W * dona
        return double.parse((w * pieces).toStringAsFixed(2));
      }
    }

    // Faska, Silliqlash va Chizish uchun:
    if (_cutMode == 'dimension' && (_effectiveLengthM > 0 || _effectiveWidthM > 0)) {
      // O'lcham bo'yicha chetlarini hisoblash
      final l = _effectiveLengthM;
      return double.parse((l * pieces).toStringAsFixed(2));
    }

    final m = _parseVal(_manualMetersCtrl);
    return m > 0 ? m : 1.0;
  }

  /// Joriy tanlangan xizmat narxi (so'm / metr)
  double get _activeUnitPrice {
    final def = kStoneServices[_selectedServiceIdx];
    if (def.key == 'polish') {
      return _polishStoneType == 'granite'
          ? StoneServicesStore.getPrice('polish_granite')
          : StoneServicesStore.getPrice('polish_ceramics');
    }
    return StoneServicesStore.getPrice(def.key);
  }

  double get _calculatedTotalPrice {
    return _calculatedTotalMeters * _activeUnitPrice;
  }

  void _adjustPieces(int delta) {
    final cur = _parsePieces();
    final next = (cur + delta).clamp(1, 9999);
    _piecesCtrl.text = next.toString();
    setState(() {});
  }

  void _adjustManualMeters(double delta) {
    final cur = _parseVal(_manualMetersCtrl);
    final next = (cur + delta);
    if (next < 0.1) return;
    _manualMetersCtrl.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1);
    setState(() {});
  }

  Future<void> _addToCart() async {
    final def = kStoneServices[_selectedServiceIdx];
    final qty = _calculatedTotalMeters;
    final price = _activeUnitPrice;
    final note = _noteCtrl.text.trim();
    final pieces = _parsePieces();
    final l = _effectiveLengthM;
    final w = _effectiveWidthM;

    final repos = context.read<AppRepositories>();
    final cart = context.read<CartController>();

    int targetProductId = def.defaultProductId;
    String serviceDisplayName = def.name;

    if (def.key == 'polish') {
      if (_polishStoneType == 'granite') {
        targetProductId = 21;
        serviceDisplayName = 'Silliqlash (Granit)';
      } else {
        targetProductId = 23;
        serviceDisplayName = 'Silliqlash (Keramogranit)';
      }
    }

    Product? targetProduct;
    try {
      final prods = await repos.products.list();
      targetProduct = prods.where((p) =>
          p.id == targetProductId ||
          p.name.trim().toLowerCase() == serviceDisplayName.toLowerCase()).firstOrNull;
    } catch (_) {}

    targetProduct ??= Product(
      id: targetProductId,
      name: serviceDisplayName,
      category: 'Xizmat',
      unit: def.unit,
      price: price,
      costPrice: 0,
      stock: 999999,
      minStock: 0,
    );

    // O'lcham va spetsifikatsiya matni
    String specText;
    if (def.key == 'cut' && _cutMode != 'manual') {
      final modeName = _cutMode == 'perimeter'
          ? '4 tomoni'
          : (_cutMode == 'length' ? 'bo‘yi' : 'eni');
      final lenVal = _parseVal(_lengthCtrl);
      final widVal = _parseVal(_widthCtrl);
      final lenStr = '${lenVal % 1 == 0 ? lenVal.toInt() : lenVal} sm';
      final widStr = '${widVal % 1 == 0 ? widVal.toInt() : widVal} m';
      specText = '$lenStr × $widStr · $pieces dona ($modeName: $qty m)';
    } else {
      specText = '$qty ${def.unit}';
    }

    if (note.isNotEmpty) {
      specText = '$specText — $note';
    }

    cart.add(
      targetProduct,
      quantity: qty,
      cutLength: l > 0 ? l : null,
      cutWidth: w > 0 ? w : null,
      cutPieces: pieces > 0 ? pieces : null,
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
      Navigator.pop(context, '$serviceDisplayName ($qty ${def.unit}) savatga qo‘shildi');
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
    final curPrice = _activeUnitPrice;
    final total = _calculatedTotalPrice;

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 680),
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
                          'Eni va bo‘yiga qarab kesish, granit va keramagranit silliqlash',
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
                            final price = def.key == 'polish'
                                ? (_polishStoneType == 'granite'
                                    ? StoneServicesStore.getPrice('polish_granite')
                                    : StoneServicesStore.getPrice('polish_ceramics'))
                                : StoneServicesStore.getPrice(def.key);

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

                    const SizedBox(height: 16),

                    // SILLIQLASH TANLANGAN BO'LSA: Granit va Keramogranit tanlovi
                    if (curDef.key == 'polish') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2028) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Silliqlash uchun materialni tanlang:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: context.inkColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  avatar: const Icon(Icons.terrain_rounded, size: 18),
                                  label: Text(
                                    'Granit (${money(StoneServicesStore.getPrice('polish_granite'))} / m)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: _polishStoneType == 'granite' ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                  selected: _polishStoneType == 'granite',
                                  selectedColor: isDark ? AppColors.neonLime : AppColors.darkCard,
                                  labelStyle: TextStyle(
                                    color: _polishStoneType == 'granite'
                                        ? (isDark ? AppColors.ink : Colors.white)
                                        : context.inkColor,
                                  ),
                                  onSelected: (_) => setState(() => _polishStoneType = 'granite'),
                                ),
                                ChoiceChip(
                                  avatar: const Icon(Icons.grid_view_rounded, size: 18),
                                  label: Text(
                                    'Keramogranit (${money(StoneServicesStore.getPrice('polish_ceramics'))} / m)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: _polishStoneType == 'ceramics' ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                  selected: _polishStoneType == 'ceramics',
                                  selectedColor: isDark ? AppColors.neonLime : AppColors.darkCard,
                                  labelStyle: TextStyle(
                                    color: _polishStoneType == 'ceramics'
                                        ? (isDark ? AppColors.ink : Colors.white)
                                        : context.inkColor,
                                  ),
                                  onSelected: (_) => setState(() => _polishStoneType = 'ceramics'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // KESISH TANLANGAN BO'LSA: ENI VA BO'YIGA QARAB KESISH
                    if (curDef.key == 'cut') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2028) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.straighten_rounded,
                                        size: 18,
                                        color: isDark ? AppColors.neonLime : AppColors.ink),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Eni va bo‘yi bo‘yicha kesish:',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: context.inkColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.neonLime : const Color(0xFF16A34A)).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Bo‘yi faqat sm · Eni metrda',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.neonLime : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Eni, Bo'yi va Dona kiritish qatori
                            Row(
                              children: [
                                // Bo'yi (faqat sm)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bo‘yi (sm):',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.mutedColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _lengthCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.inkColor),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: context.cardColor,
                                          isDense: true,
                                          hintText: '120',
                                          suffixText: 'sm',
                                          suffixStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.mutedColor),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Eni (faqat m)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Eni (m):',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.mutedColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _widthCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.inkColor),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: context.cardColor,
                                          isDense: true,
                                          hintText: '0.6',
                                          suffixText: 'm',
                                          suffixStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.mutedColor),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Dona (soni)
                                SizedBox(
                                  width: 130,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Donasi:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.mutedColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          IconButton.filledTonal(
                                            onPressed: () => _adjustPieces(-1),
                                            icon: const Icon(Icons.remove, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _piecesCtrl,
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: context.inkColor),
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: context.cardColor,
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          IconButton.filledTonal(
                                            onPressed: () => _adjustPieces(1),
                                            icon: const Icon(Icons.add, size: 16),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Kesish turi (qirralari)
                            Text(
                              'Kesish usuli (qirralar):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.mutedColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('4 tomoni (Perimetr)'),
                                    selected: _cutMode == 'perimeter',
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() => _cutMode = 'perimeter'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('Bo‘yiga kesish'),
                                    selected: _cutMode == 'length',
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() => _cutMode = 'length'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('Eniga kesish'),
                                    selected: _cutMode == 'width',
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() => _cutMode = 'width'),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text('Oddiy (faqat metr)'),
                                    selected: _cutMode == 'manual',
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) => setState(() => _cutMode = 'manual'),
                                  ),
                                ],
                              ),
                            ),

                            // Agar oddiy metr rejimi tanlangan bo'lsa
                            if (_cutMode == 'manual') ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    'To‘g‘ridan-to‘g‘ri metr: ',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.mutedColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 140,
                                    child: TextField(
                                      controller: _manualMetersCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.inkColor),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: context.cardColor,
                                        suffixText: 'm',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderColor)),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 10),
                            // Jonli hisob tafsiloti
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calculate_rounded, size: 18, color: isDark ? AppColors.neonLime : AppColors.ink),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final lenVal = _parseVal(_lengthCtrl);
                                        final widVal = _parseVal(_widthCtrl);
                                        final lenStr = '${lenVal % 1 == 0 ? lenVal.toInt() : lenVal} sm';
                                        final widStr = '${widVal % 1 == 0 ? widVal.toInt() : widVal} m';
                                        return Text(
                                          _cutMode == 'manual'
                                              ? 'Jami kesish: $_calculatedTotalMeters metr'
                                              : 'O‘lcham: $lenStr × $widStr · ${_parsePieces()} dona → Jami kesish: $_calculatedTotalMeters metr',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: context.inkColor,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // FASKA, CHIZISH YOKI ODDIY REJIM: Miqdor (metr) kiritish
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2028) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xizmat hajmi (metrda):',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.mutedColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => _adjustManualMeters(-1.0),
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
                                Expanded(
                                  child: TextField(
                                    controller: _manualMetersCtrl,
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
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () => _adjustManualMeters(1.0),
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
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [1, 2, 5, 10, 20, 50].map((q) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text('+$q m'),
                                      labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.inkColor),
                                      backgroundColor: context.cardColor,
                                      side: BorderSide(color: context.borderColor),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      onPressed: () => _adjustManualMeters(q.toDouble()),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Izoh yoki buyurtma tafsiloti
                    Text(
                      'Izoh yoki buyurtma tafsiloti (ixtiyoriy):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.mutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteCtrl,
                      style: TextStyle(fontSize: 13, color: context.inkColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.cardColor,
                        hintText: 'Masalan: 3-etaj pillapoyaga, Angola toshiga...',
                        hintStyle: TextStyle(fontSize: 13, color: context.mutedColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.borderColor)),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Jami: $_calculatedTotalMeters metr · ',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${money(curPrice)} / m',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                        onPressed: _calculatedTotalMeters > 0 ? _addToCart : null,
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
  late final TextEditingController _cutCtrl;
  late final TextEditingController _chamferCtrl;
  late final TextEditingController _polishGraniteCtrl;
  late final TextEditingController _polishCeramicsCtrl;
  late final TextEditingController _grooveCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cutCtrl = TextEditingController(text: StoneServicesStore.getPrice('cut').round().toString());
    _chamferCtrl = TextEditingController(text: StoneServicesStore.getPrice('chamfer').round().toString());
    _polishGraniteCtrl = TextEditingController(text: StoneServicesStore.getPrice('polish_granite').round().toString());
    _polishCeramicsCtrl = TextEditingController(text: StoneServicesStore.getPrice('polish_ceramics').round().toString());
    _grooveCtrl = TextEditingController(text: StoneServicesStore.getPrice('groove').round().toString());
  }

  @override
  void dispose() {
    _cutCtrl.dispose();
    _chamferCtrl.dispose();
    _polishGraniteCtrl.dispose();
    _polishCeramicsCtrl.dispose();
    _grooveCtrl.dispose();
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

      final cutVal = parseInput(_cutCtrl.text);
      final chamferVal = parseInput(_chamferCtrl.text);
      final polishGraniteVal = parseInput(_polishGraniteCtrl.text);
      final polishCeramicsVal = parseInput(_polishCeramicsCtrl.text);
      final grooveVal = parseInput(_grooveCtrl.text);

      if (cutVal != null && cutVal >= 0) StoneServicesStore.setPrice('cut', cutVal);
      if (chamferVal != null && chamferVal >= 0) StoneServicesStore.setPrice('chamfer', chamferVal);
      if (polishGraniteVal != null && polishGraniteVal >= 0) StoneServicesStore.setPrice('polish_granite', polishGraniteVal);
      if (polishCeramicsVal != null && polishCeramicsVal >= 0) StoneServicesStore.setPrice('polish_ceramics', polishCeramicsVal);
      if (grooveVal != null && grooveVal >= 0) StoneServicesStore.setPrice('groove', grooveVal);

      // Bazadagi mahsulotlarni yangilash
      for (final p in prods) {
        final name = p.name.trim().toLowerCase();
        double? newPrice;

        if (p.id == 19 || name == 'razmer kesish') {
          newPrice = cutVal;
        } else if (p.id == 20 || name == 'faska ochish') {
          newPrice = chamferVal;
        } else if (p.id == 21 || (name.contains('silliq') && name.contains('granit'))) {
          newPrice = polishGraniteVal;
        } else if (p.id == 23 || (name.contains('silliq') && name.contains('keramo'))) {
          newPrice = polishCeramicsVal;
        } else if (p.id == 22 || name == 'chizish') {
          newPrice = grooveVal;
        }

        if (newPrice != null && newPrice >= 0 && newPrice != p.price) {
          try {
            await repos.products.update(p.copyWith(price: newPrice));
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
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

  Widget _buildPriceRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required TextEditingController controller,
    required bool isDark,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? AppColors.neonLime : AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.inkColor,
                  ),
                ),
                Text(
                  subtitle,
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
              controller: controller,
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 540,
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
                          'Admin: kesish, faska, granit va keramagranit silliqlash narxlari',
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

                  _buildPriceRow(
                    title: 'Razmer kesish',
                    subtitle: 'Eni va bo‘yiga kesish (1 metr)',
                    icon: Icons.content_cut_rounded,
                    controller: _cutCtrl,
                    isDark: isDark,
                    context: context,
                  ),
                  _buildPriceRow(
                    title: 'Faska ochish',
                    subtitle: 'Qirra berish (1 metr)',
                    icon: Icons.architecture_rounded,
                    controller: _chamferCtrl,
                    isDark: isDark,
                    context: context,
                  ),
                  _buildPriceRow(
                    title: 'Silliqlash — Granit',
                    subtitle: 'Tabiiy tosh jilolash (1 metr)',
                    icon: Icons.terrain_rounded,
                    controller: _polishGraniteCtrl,
                    isDark: isDark,
                    context: context,
                  ),
                  _buildPriceRow(
                    title: 'Silliqlash — Keramogranit',
                    subtitle: 'Keramogranit / Kafel jilolash (1 metr)',
                    icon: Icons.grid_view_rounded,
                    controller: _polishCeramicsCtrl,
                    isDark: isDark,
                    context: context,
                  ),
                  _buildPriceRow(
                    title: 'Chizish',
                    subtitle: 'Antislip yo‘l chizish (1 metr)',
                    icon: Icons.line_weight_rounded,
                    controller: _grooveCtrl,
                    isDark: isDark,
                    context: context,
                  ),
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

/// Bo'yi va Eni birliklarini (m / sm) mustaqil tanlash uchun miniatyura chip
class _UnitChoicePill extends StatelessWidget {
  const _UnitChoicePill({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.neonLime : AppColors.darkCard)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.neonLime : AppColors.darkCard)
                : context.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected
                ? (isDark ? AppColors.ink : Colors.white)
                : context.mutedColor,
          ),
        ),
      ),
    );
  }
}
