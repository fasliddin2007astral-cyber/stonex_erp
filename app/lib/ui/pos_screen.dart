import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/cart_controller.dart';
import 'camera_capture_dialog.dart';
import 'common.dart';
import 'qr_scanner_screen.dart';
import 'receipt_dialog.dart';

String _u(String unit) => unit == 'm2' ? 'm²' : unit;

BoxDecoration _cardBox({Color? color, double radius = 22}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
    );

ShapeBorder get _dialogShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _search = TextEditingController();
  late Future<List<Product>> _future;
  String _selectedCategory = 'Barchasi';
  int _mobileTab = 0; // 0: Katalog, 1: Savat
  bool _isScannerOpen = false;

  static const _categories = ['Barchasi', 'Marmar', 'Granit', 'Travertin', 'Onyx', 'Boshqa'];

  ProductRepository get _repo => context.read<AppRepositories>().products;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _future = context.read<AppRepositories>().products.list();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _search.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f2) {
      if (!_isScannerOpen && mounted) {
        _openQrScanner();
      }
      return true;
    }
    return false;
  }

  void _reload() {
    setState(() {
      _future = _repo.list();
    });
  }

  Future<void> _openQrScanner() async {
    if (_isScannerOpen) return;
    _isScannerOpen = true;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide && Platform.isWindows) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _DesktopQrScannerDialog(
          onCartUpdated: () {
            if (mounted) setState(() {});
          },
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (ctx) => QrScannerScreen(
            onCartUpdated: () {
              if (mounted) setState(() {});
            },
            onGoToCart: () {
              if (mounted) {
                setState(() {
                  _mobileTab = 1;
                });
              }
            },
          ),
        ),
      );
    }
    _isScannerOpen = false;
    if (mounted) _reload();
  }

  Future<void> _onSubmit(String text) async {
    final code = text.trim();
    if (code.isEmpty) return;
    try {
      final p = await _repo.findByCode(code);
      if (!mounted) return;
      if (p != null) {
        context.read<CartController>().add(p);
        _search.clear();
        _reload();
      } else {
        showMessage(context, 'Bu kod bo‘yicha mahsulot topilmadi', error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartController = context.watch<CartController>();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final searchAndFilter = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Vault qidiruv paneli va QR Skaner
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _search,
                  autofocus: wide,
                  style: TextStyle(fontSize: 13, color: context.inkColor, fontWeight: FontWeight.w500),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.cardColor,
                    isDense: true,
                    hintText: 'Qidirish yoki kod yozing...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.isDark ? AppColors.neonLime : AppColors.ink, width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _onSubmit,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _openQrScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                label: Text(
                  wide ? 'QR Skaner (F2)' : 'QR',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                  foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Kategoriya pill chiplari
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((c) {
              final sel = _selectedCategory == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : AppColors.ink,
                    ),
                  ),
                  selected: sel,
                  selectedColor: AppColors.darkCard,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: sel ? AppColors.darkCard : AppColors.border),
                  ),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = c;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );

    final products = Column(children: [
      searchAndFilter,
      const SizedBox(height: 14),
      Expanded(
        child: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(message: snap.error.toString(), onRetry: _reload);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var items = snap.data!;

            final query = _search.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              items = items.where((p) {
                final n = p.name.toLowerCase();
                final sku = p.sku.toLowerCase();
                final qr = p.qrCode.toLowerCase();
                return n.contains(query) || sku.contains(query) || qr.contains(query);
              }).toList();
            }

            if (_selectedCategory != 'Barchasi') {
              items = items.where((p) {
                final n = p.name.toLowerCase();
                final cat = _selectedCategory.toLowerCase();
                if (cat == 'boshqa') {
                  return !n.contains('marmar') && !n.contains('granit') && !n.contains('travertin') && !n.contains('onyx');
                }
                return n.contains(cat);
              }).toList();
            }

            if (items.isEmpty) {
              return const _EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Mahsulot topilmadi',
                hint: 'Boshqa nom yoki kod bilan urinib ko‘ring',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 214,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _ProductCard(
                key: ValueKey(items[i].id),
                product: items[i],
                index: i,
                onTap: () {
                  context.read<CartController>().add(items[i]);
                  if (!wide) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        content: Text('${items[i].name} savatga qo‘shildi'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    ]);

    final cart = _CartPanel(onSold: _reload);

    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 5, child: products),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: cart),
        ]),
      );
    }

    // Mobil qurilmalar (Smartfonlar) uchun toza tabli ko'rinish
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        children: [
          // Mobil tab tugmalari
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _mobileTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _mobileTab == 0 ? AppColors.darkCard : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Katalog',
                        style: TextStyle(
                          color: _mobileTab == 0 ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _mobileTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _mobileTab == 1 ? AppColors.darkCard : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Savat',
                            style: TextStyle(
                              color: _mobileTab == 1 ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (cartController.lines.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _mobileTab == 1 ? AppColors.neonLime : AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${cartController.lines.length}',
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _mobileTab == 0 ? products : cart,
          ),
          if (_mobileTab == 0 && cartController.lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cartController.lines.length} ta mahsulot',
                          style: const TextStyle(color: Color(0xFFA9BDB0), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          money(cartController.total),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => setState(() => _mobileTab = 1),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neonLime,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                    label: const Text('Savat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mahsulot kartasi
// ---------------------------------------------------------------------------

class _ProductCard extends StatefulWidget {
  const _ProductCard({super.key, required this.product, required this.index, required this.onTap});
  final Product product;
  final int index;
  final VoidCallback onTap;
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final out = p.stock <= 0;
    final lifted = _hover && !out;
    final intro = Duration(milliseconds: 320 + widget.index.clamp(0, 10) * 45);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: intro,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 22), child: child),
      ),
      child: MouseRegion(
        cursor: out ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: out ? null : widget.onTap,
          onTapDown: out ? null : (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lifted ? AppColors.green : context.borderColor, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Color(lifted ? 0x24000000 : 0x0A000000),
                    blurRadius: lifted ? 20 : 10,
                    offset: Offset(0, lifted ? 8 : 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Opacity(
                  opacity: out ? 0.55 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Katta rasm qismi (Image Banner)
                      SizedBox(
                        height: 114,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ProductThumbnail(
                              imageUrl: p.imageUrl,
                              name: p.name,
                              width: double.infinity,
                              height: 114,
                              borderRadiusGeometry: const BorderRadius.vertical(top: Radius.circular(19)),
                            ),
                            // Qoldiq belgisi (Stock badge)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: out
                                      ? const Color(0xFFE53935)
                                      : Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Text(
                                  out ? 'Tugagan' : 'Qoldiq: ${qty(p.stock)} ${_u(p.unit)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // Katta ko'rish (Zoom preview) tugmasi agar rasm bo'lsa
                            if (p.imageUrl != null && p.imageUrl!.trim().isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => showProductImagePreview(
                                      context,
                                      imageUrl: p.imageUrl,
                                      name: p.name,
                                      subtitle: '${money(p.price)} / ${_u(p.unit)} • Qoldiq: ${qty(p.stock)} ${_u(p.unit)}',
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Mahsulot matni va narxi
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.22,
                                  color: context.inkColor,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          money(p.price),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: context.isDark ? AppColors.neonLime : AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          '/ ${_u(p.unit)}',
                                          maxLines: 1,
                                          style: TextStyle(fontSize: 11, color: context.mutedColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: lifted ? AppColors.neonLime : (context.isDark ? const Color(0xFF21262D) : AppColors.darkCard),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.add_shopping_cart_rounded,
                                      color: lifted ? AppColors.ink : Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.hint});
  final IconData icon;
  final String title, hint;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: AppColors.green),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Savat
// ---------------------------------------------------------------------------

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.onSold});
  final VoidCallback onSold;

  Future<void> _editQty(BuildContext context, CartLine l) async {
    final cart = context.read<CartController>();
    final ctrl = TextEditingController(text: qty(l.quantity));
    var inDona = l.inDona;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: _dialogShape,
          title: Text(l.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Miqdor'),
              ),
              if (l.product.hasDona) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(_u(l.product.unit))),
                    const ButtonSegment(value: true, label: Text('dona')),
                  ],
                  selected: {inDona},
                  onSelectionChanged: (s) => setS(() => inDona = s.first),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
          ],
        ),
      ),
    );
    final v = parseInput(ctrl.text);
    ctrl.dispose();
    if (ok == true && v != null && v > 0) cart.update(l, quantity: v, inDona: inDona);
  }

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartController>();
    final result = await showDialog<_CheckoutInput>(context: context, builder: (_) => _CheckoutDialog(total: cart.total));
    if (result == null || !context.mounted) return;
    try {
      final res = await cart.checkout(
        paid: result.paid,
        customerId: result.customerId,
        customerName: result.name,
        customerPhone: result.phone,
        customerPassport: result.passport,
        customerPhotoUrl: result.photoUrl,
      );
      if (!context.mounted) return;
      showMessage(context, 'Savdo #${res.id} saqlandi. To‘landi: ${money(res.paid)}'
          '${res.debt > 0 ? ', nasiya: ${money(res.debt)}' : ''}');
      onSold();
      await ReceiptDialog.show(context, res);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final empty = cart.lines.isEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardBox(radius: 24),
      child: Column(children: [
        Row(children: [
          const Text('Savat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: empty
                ? const SizedBox.shrink(key: ValueKey('none'))
                : Container(
                    key: ValueKey(cart.lines.length),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text('${cart.lines.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkCard, fontSize: 12)),
                  ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: empty ? null : cart.clear,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Tozalash'),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: empty
              ? const _EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Savat bo‘sh',
                  hint: 'Mahsulotni bosing yoki QR kodni kiriting')
              : ListView(children: [
                  for (final l in cart.lines)
                    _CartLineTile(key: ObjectKey(l), line: l, onEdit: () => _editQty(context, l)),
                ]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Jami', style: TextStyle(color: Color(0xFFA9BDB0), fontSize: 13)),
              const Spacer(),
              Text('${cart.lines.length} ta mahsulot', style: const TextStyle(color: Color(0xFFA9BDB0), fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: cart.total),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(money(v), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (empty || cart.busy) ? null : () => _checkout(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.neonLime,
                  foregroundColor: AppColors.ink,
                  disabledBackgroundColor: const Color(0xFF22262B),
                  disabledForegroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                icon: cart.busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                    : const Icon(Icons.payments_rounded, color: AppColors.ink),
                label: const Text('To‘lovni qabul qilish', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({super.key, required this.line, required this.onEdit});
  final CartLine line;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final l = line;
    final p = l.product;
    final unit = l.inDona ? 'dona' : _u(p.unit);
    final short = l.baseQty > p.stock;
    final sub = '${money(p.price)} / ${_u(p.unit)}${l.inDona ? '  ·  ${qty(l.baseQty)} ${_u(p.unit)}' : ''}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset((1 - t) * 24, 0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: short ? AppColors.danger : Colors.transparent),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: () => showProductImagePreview(
                context,
                imageUrl: p.imageUrl,
                name: p.name,
                subtitle: '${money(p.price)} / ${_u(p.unit)} • Savatda: ${qty(line.quantity)} ${_u(p.unit)}',
              ),
              child: ProductThumbnail(
                imageUrl: p.imageUrl,
                name: p.name,
                size: 38,
                borderRadius: 10,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            IconButton(
              tooltip: 'Olib tashlash',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
              onPressed: () => cart.remove(l),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _StepBtn(icon: Icons.remove_rounded, onTap: () {
                  final q = l.quantity - 1;
                  if (q > 0) {
                    cart.update(l, quantity: q);
                  } else {
                    cart.remove(l);
                  }
                }),
                InkWell(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('${qty(l.quantity)} $unit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                _StepBtn(icon: Icons.add_rounded, onTap: () => cart.update(l, quantity: l.quantity + 1)),
              ]),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(money(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ]),
          if (short)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('⚠ Omborda yetarli emas', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 32, height: 32, child: Icon(icon, size: 18)),
      );
}

// ---------------------------------------------------------------------------
// To'lov oynasi
// ---------------------------------------------------------------------------

class _CheckoutInput {
  final double paid;
  final int? customerId;
  final String? name;
  final String? phone;
  final String? passport;
  final String? photoUrl;

  _CheckoutInput({
    required this.paid,
    this.customerId,
    this.name,
    this.phone,
    this.passport,
    this.photoUrl,
  });
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({required this.total});
  final double total;
  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late final _paid = TextEditingController(text: widget.total.round().toString());
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _passport = TextEditingController();
  String? _photoUrl;
  int? _selectedCustomerId;
  List<Customer> _existingCustomers = [];
  bool _uploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await context.read<AppRepositories>().customers.listCustomers();
      if (mounted) {
        setState(() {
          _existingCustomers = list;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _paid.dispose();
    _name.dispose();
    _phone.dispose();
    _passport.dispose();
    super.dispose();
  }

  void _setPaid(double v) {
    setState(() {
      _paid.text = v.round().toString();
      _error = null;
    });
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomerId = c.id;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _passport.text = c.passport ?? '';
      _photoUrl = c.photoUrl;
      _error = null;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomerId = null;
      _name.clear();
      _phone.clear();
      _passport.clear();
      _photoUrl = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final custRepo = context.read<AppRepositories>().customers;
    setState(() {
      _uploadingImage = true;
      _error = null;
    });
    try {
      final bytes = await pickOrCaptureCustomerImage(context, source);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }

      String finalUrl;
      try {
        final decoded = img.decodeImage(Uint8List.fromList(bytes));
        if (decoded != null) {
          final resized = (decoded.width > 480 || decoded.height > 480)
              ? img.copyResize(decoded, width: decoded.width >= decoded.height ? 480 : null, height: decoded.height > decoded.width ? 480 : null)
              : decoded;
          final jpg = img.encodeJpg(resized, quality: 78);
          finalUrl = 'data:image/jpeg;base64,${base64Encode(jpg)}';
        } else {
          finalUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      } catch (_) {
        finalUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      try {
        final filename = 'cust_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploaded = await custRepo.uploadCustomerImage(bytes, filename);
        if (uploaded.isNotEmpty) {
          finalUrl = uploaded;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _photoUrl = finalUrl;
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Rasm olishda xatolik: $e';
          _uploadingImage = false;
        });
      }
    }
  }

  void _ok() {
    final paid = parseInput(_paid.text);
    if (paid == null || paid < 0 || paid > widget.total + 0.5) {
      setState(() {
        _error = 'To‘lov 0 dan jami summagacha bo‘lishi kerak';
      });
      return;
    }
    final debt = widget.total - paid;
    if (debt > 0.5 && _name.text.trim().isEmpty) {
      setState(() {
        _error = 'Nasiya uchun mijoz ismini kiriting';
      });
      return;
    }
    Navigator.pop(
      context,
      _CheckoutInput(
        paid: paid > widget.total ? widget.total : paid,
        customerId: _selectedCustomerId,
        name: _name.text.trim().isNotEmpty ? _name.text.trim() : null,
        phone: _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
        passport: _passport.text.trim().isNotEmpty ? _passport.text.trim() : null,
        photoUrl: _photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paid = parseInput(_paid.text) ?? 0;
    final debt = (widget.total - paid).clamp(0, double.infinity).toDouble();
    final hasDebt = debt > 0.5;

    return AlertDialog(
      backgroundColor: context.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: _dialogShape,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('To‘lovni qabul qilish', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(money(widget.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.green)),
      ]),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // To'lov summasi
            TextField(
              controller: _paid,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hozir to‘langan summa'),
              onChanged: (_) {
                setState(() {
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ActionChip(label: const Text('To‘liq to‘lov'), onPressed: () => _setPaid(widget.total)),
              ActionChip(label: const Text('Hammasi nasiya'), onPressed: () => _setPaid(0)),
            ]),
            const SizedBox(height: 12),

            // Nasiya holati banneri
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasDebt ? const Color(0xFFFFF1DC) : AppColors.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(hasDebt ? Icons.schedule_rounded : Icons.check_circle_rounded,
                    size: 20, color: hasDebt ? const Color(0xFFC77700) : AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(hasDebt ? 'Nasiya (qarz): ${money(debt)}' : 'To‘liq to‘lanadi',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Mijoz ma'lumotlari sarlavhasi
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  'Xaridor ma‘lumotlari',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.inkColor),
                ),
                const Spacer(),
                if (_selectedCustomerId != null)
                  TextButton.icon(
                    onPressed: _clearCustomer,
                    icon: const Icon(Icons.person_add_rounded, size: 15),
                    label: const Text('Yangi mijoz', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Doimiy mijozlarni tezkor tanlash
            if (_existingCustomers.isNotEmpty && _selectedCustomerId == null) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingCustomers.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final c = _existingCustomers[i];
                    return ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 14),
                      label: Text(c.name, style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => _selectCustomer(c),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Ism
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: hasDebt ? 'Mijoz Ism-Familiyasi * (Nasiya uchun majburiy)' : 'Mijoz Ism-Familiyasi',
                hintText: 'Masalan: Rustam Karimov',
                prefixIcon: const Icon(Icons.person_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 10),

            // Telefon
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon raqami',
                hintText: '+998 90 123 45 67',
                prefixIcon: Icon(Icons.phone_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 10),

            // Pasport
            TextField(
              controller: _passport,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Pasport seriya va raqami',
                hintText: 'AA 1234567',
                prefixIcon: Icon(Icons.badge_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Pasport / Mijoz fotosurati qismi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF1E2822) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Text(
                        'Pasport / Mijoz surati',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.inkColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_photoUrl != null && _photoUrl!.isNotEmpty) ...[
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => showProductImagePreview(
                            context,
                            imageUrl: _photoUrl,
                            name: _name.text.isNotEmpty ? _name.text : 'Xaridor surati',
                            subtitle: 'Pasport: ${_passport.text.isNotEmpty ? _passport.text : 'Yo‘q'}',
                          ),
                          child: ProductThumbnail(
                            imageUrl: _photoUrl,
                            name: _name.text,
                            size: 64,
                            borderRadius: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Rasm saqlandi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.green)),
                              const SizedBox(height: 2),
                              const Text('To‘liq ko‘rish uchun rasmni bosing', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _pickImage(ImageSource.camera),
                                    child: const Text('Qayta olish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green)),
                                  ),
                                  const SizedBox(width: 14),
                                  InkWell(
                                    onTap: () => setState(() => _photoUrl = null),
                                    child: const Text('O‘chirish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (_uploadingImage)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Rasm yuklanmoqda...', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.photo_camera_rounded, size: 16),
                              label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              label: const Text('Galereya', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor'),
        ),
        FilledButton(
          onPressed: _ok,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Tasdiqlash', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Windows / Katta ekranlar uchun USB Skaner dialogi (F2)
// ---------------------------------------------------------------------------

class _DesktopQrScannerDialog extends StatefulWidget {
  const _DesktopQrScannerDialog({required this.onCartUpdated});
  final VoidCallback onCartUpdated;

  @override
  State<_DesktopQrScannerDialog> createState() => _DesktopQrScannerDialogState();
}

class _DesktopQrScannerDialogState extends State<_DesktopQrScannerDialog> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  String? _statusMessage;
  bool _isError = false;
  Product? _lastProduct;
  double _lastQty = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processCode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    try {
      final repo = context.read<AppRepositories>().products;
      final p = await repo.findByCode(code);
      if (!mounted) return;

      if (p != null) {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);

        context.read<CartController>().add(p, quantity: 1);
        widget.onCartUpdated();

        setState(() {
          _isError = false;
          _statusMessage = '“${p.name}” savatga qo‘shildi (+1 ${_u(p.unit)})';
          _lastProduct = p;
          _lastQty = 1.0;
          _inputCtrl.clear();
        });
        _focusNode.requestFocus();
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _isError = true;
          _statusMessage = 'Mahsulot topilmadi: "$code"';
        });
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _statusMessage = 'Xatolik: $e';
        });
      }
    }
  }

  void _updateLastQty(double delta) {
    if (_lastProduct == null) return;
    final cart = context.read<CartController>();
    final p = _lastProduct!;

    if (delta > 0) {
      cart.add(p, quantity: delta);
      setState(() {
        _lastQty += delta;
      });
    } else if (delta < 0) {
      final existing = cart.lines.where((l) => l.product.id == p.id);
      if (existing.isNotEmpty) {
        final l = existing.first;
        if (l.quantity + delta > 0.001) {
          cart.update(l, quantity: l.quantity + delta);
          setState(() {
            _lastQty += delta;
          });
        } else {
          cart.remove(l);
          setState(() {
            _lastProduct = null;
            _lastQty = 1.0;
          });
        }
      }
    }
    widget.onCartUpdated();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Dialog(
      backgroundColor: context.dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF132D21) : AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR / Barkod skaneri',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'USB skaner yoki kod kiritish (F2)',
                          style: TextStyle(fontSize: 12, color: context.mutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF0F1A24) : const Color(0xFFF1F6FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.usb_rounded, color: AppColors.info, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'USB 2D / Lazer skaner tayyor. Shtrix-kod yoki QR kodni skanerlang',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(fontSize: 13, color: context.inkColor, fontWeight: FontWeight.w600),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.cardColor,
                          hintText: 'Skanerlang yoki kod yozing (masalan: STX-ANGOLA)...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
                          prefixIcon: const Icon(Icons.qr_code_rounded, size: 20, color: AppColors.muted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.borderColor)),
                        ),
                        onSubmitted: _processCode,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () => _processCode(_inputCtrl.text),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
                      label: const Text('Qo‘shish', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                        foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
              if (_statusMessage != null && _isError) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF331616) : const Color(0xFFFCE4E3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_lastProduct != null) ...[
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: AppColors.green),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Oxirgi skanerlangan mahsulot',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF132D21) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (context.isDark ? AppColors.greenBright : AppColors.green).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0xFF0C2016) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _lastProduct!.name.isNotEmpty ? _lastProduct!.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _lastProduct!.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${money(_lastProduct!.price)} / ${_u(_lastProduct!.unit)} • Qoldiq: ${qty(_lastProduct!.stock)} ${_u(_lastProduct!.unit)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: context.isDark ? const Color(0xFF0E2218) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, size: 16),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  splashRadius: 14,
                                  onPressed: () => _updateLastQty(-1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    qty(_lastQty),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  splashRadius: 14,
                                  onPressed: () => _updateLastQty(1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cart.lines.isNotEmpty ? 'Savatda: ${cart.lines.length} ta tovar • ${money(cart.total)}' : 'Savat bo‘sh',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cart.lines.isNotEmpty ? AppColors.green : context.mutedColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                      foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Tayyor (Yopish)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}