import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/cart_controller.dart';
import 'common.dart';

String _u(String unit) => unit == 'm2' ? 'm²' : unit;

BoxDecoration _cardBox({Color color = Colors.white, double radius = 22}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
    );

ShapeBorder get _dialogShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));

/// Kassa. QR skaner (kamera) keyin ulanadi; hozircha QR/SKU kodni qo'lda yoki
/// USB skaner (klaviatura sifatida ishlaydi) bilan kiritish + Enter.
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

  static const _categories = ['Barchasi', 'Marmar', 'Granit', 'Travertin', 'Onyx', 'Boshqa'];

  ProductRepository get _repo => context.read<AppRepositories>().products;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepositories>().products.list();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repo.list(query: _search.text);
    });
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
        // Vault qidiruv paneli
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _search,
            autofocus: wide,
            decoration: InputDecoration(
              hintText: 'QR / kod (Enter) yoki nom bo‘yicha qidirish...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
              prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.muted),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _reload();
                      },
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => _reload(),
            onSubmitted: _onSubmit,
          ),
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
                maxCrossAxisExtent: 240,
                mainAxisExtent: 150,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cartController.lines.length} ta mahsulot',
                        style: const TextStyle(color: Color(0xFFA9BDB0), fontSize: 11),
                      ),
                      Text(
                        money(cartController.total),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => setState(() => _mobileTab = 1),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.neonLime,
                      foregroundColor: AppColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                    label: const Text('Savatga o‘tish', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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
    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lifted ? AppColors.green : Colors.transparent, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Color(lifted ? 0x24000000 : 0x0F000000),
                    blurRadius: lifted ? 22 : 12,
                    offset: Offset(0, lifted ? 9 : 4),
                  ),
                ],
              ),
              child: Opacity(
                opacity: out ? 0.55 : 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(initial,
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 17)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: out ? const Color(0xFFFCE4E3) : AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            out ? 'Tugagan' : 'Qoldiq: ${qty(p.stock)} ${_u(p.unit)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600, color: out ? AppColors.danger : AppColors.darkCard),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const Spacer(),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(p.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${money(p.price)} / ${_u(p.unit)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: lifted ? AppColors.neonLime : AppColors.darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add_shopping_cart_rounded, color: lifted ? AppColors.ink : Colors.white, size: 18),
                    ),
                  ]),
                ]),
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
      final res = await cart.checkout(paid: result.paid, customerName: result.name, customerPhone: result.phone);
      if (!context.mounted) return;
      showMessage(context, 'Savdo #${res.id} saqlandi. To‘landi: ${money(res.paid)}'
          '${res.debt > 0 ? ', nasiya: ${money(res.debt)}' : ''}');
      onSold();
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
  final String? name;
  final String? phone;
  _CheckoutInput(this.paid, this.name, this.phone);
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
  String? _error;

  @override
  void dispose() {
    _paid.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _setPaid(double v) {
    setState(() {
      _paid.text = v.round().toString();
      _error = null;
    });
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
    Navigator.pop(context, _CheckoutInput(paid > widget.total ? widget.total : paid, _name.text.trim(), _phone.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final paid = parseInput(_paid.text) ?? 0;
    final debt = (widget.total - paid).clamp(0, double.infinity).toDouble();
    final hasDebt = debt > 0.5;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: _dialogShape,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('To‘lov', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(money(widget.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.green)),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Mijoz (nasiya uchun majburiy)')),
            const SizedBox(height: 10),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefon (ixtiyoriy)')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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