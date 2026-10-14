import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  late Future<List<Product>> _future;
  String _selectedFilter = 'Barchasi';

  ProductRepository get _repo => context.read<AppRepositories>().products;

  @override
  void initState() {
    super.initState();
    _future = _repo.list(query: _search.text);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _repo.list(query: _search.text);
      });
    }
  }

  Future<void> _edit([Product? p]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductDialog(repo: _repo, product: p),
    );
    if (saved == true && mounted) {
      showMessage(context, p == null ? 'Yangi mahsulot saqlandi' : 'Mahsulot yangilandi');
      _reload();
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Mahsulotni faolsizlantirish', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          '"${p.name}" ro‘yxatdan olib tashlansinmi?\n(Oldingi savdo va ombor tarixi saqlanadi)',
          style: const TextStyle(height: 1.4, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deactivate(p.id);
      if (mounted) {
        showMessage(context, '${p.name} ro‘yxatdan olindi');
        _reload();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['Barchasi', 'Toshlar (m²)', 'Dona', 'Kam qolgan'];

    return Scaffold(
      backgroundColor: AppColors.panel,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.neonLime),
        label: const Text('Mahsulot qo‘shish'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: _reload);
          }

          var allProducts = snap.data ?? [];
          var displayList = List<Product>.from(allProducts);

          // Filtr qo'llash
          if (_selectedFilter == 'Toshlar (m²)') {
            displayList = displayList.where((p) => p.unit == 'm2').toList();
          } else if (_selectedFilter == 'Dona') {
            displayList = displayList.where((p) => p.hasDona || p.unit == 'dona').toList();
          } else if (_selectedFilter == 'Kam qolgan') {
            displayList = displayList.where((p) => p.stock < 15).toList();
          }

          // Umumiy statistika
          final totalCount = allProducts.length;
          final totalStockValue = allProducts.fold<double>(0, (sum, p) => sum + (p.stock * p.price));
          final lowStockCount = allProducts.where((p) => p.stock < 15).length;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                  children: [
                    // Yuqori 3 ta mini-statistika kartasi
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat(
                              title: 'Jami Mahsulotlar',
                              value: '$totalCount ta',
                              icon: Icons.inventory_2_outlined,
                              accentColor: AppColors.neonLime,
                              isDark: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildMiniStat(
                              title: 'Ombordagi Tovarlar Qiymati',
                              value: money(totalStockValue),
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: AppColors.green,
                              isDark: false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildMiniStat(
                              title: 'Zaxirasi Kam Qolgan',
                              value: '$lowStockCount ta tovar',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFEAB308),
                              isDark: false,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildMiniStat(
                        title: 'Jami Mahsulotlar',
                        value: '$totalCount ta',
                        icon: Icons.inventory_2_outlined,
                        accentColor: AppColors.neonLime,
                        isDark: true,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat(
                              title: 'Umumiy Qiymat',
                              value: money(totalStockValue),
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: AppColors.green,
                              isDark: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniStat(
                              title: 'Kam Qolgan',
                              value: '$lowStockCount ta',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFEAB308),
                              isDark: false,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Qidiruv va Filtr teglari
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: 'Qidirish (Nomi, SKU yoki QR kod)...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
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
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _edit(),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkCard,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.add, size: 18, color: AppColors.neonLime),
                          label: const Text('Qo‘shish', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Filtr chiplari
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in filters) ...[
                            GestureDetector(
                              onTap: () => setState(() => _selectedFilter = f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == f ? AppColors.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _selectedFilter == f ? AppColors.darkCard : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    color: _selectedFilter == f ? Colors.white : AppColors.ink,
                                    fontSize: 12,
                                    fontWeight: _selectedFilter == f ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Mahsulotlar ro'yxati (Vault kartalari)
                    if (displayList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.muted),
                              SizedBox(height: 12),
                              Text('Mahsulotlar topilmadi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              SizedBox(height: 4),
                              Text('Qidiruv mezonlarini o‘zgartiring yoki yangi mahsulot qo‘shing',
                                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = displayList[i];
                          final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';
                          final isOutOfStock = p.stock <= 0;
                          final isLowStock = p.stock > 0 && p.stock < 15;

                          Color stockColor = AppColors.green;
                          String stockLabel = '${qty(p.stock)} ${p.unit}';
                          if (isOutOfStock) {
                            stockColor = AppColors.danger;
                            stockLabel = 'Tugagan (0 ${p.unit})';
                          } else if (isLowStock) {
                            stockColor = const Color(0xFFD97706);
                            stockLabel = 'Kam qolgan (${qty(p.stock)} ${p.unit})';
                          }

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Mahsulot logosi
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.neonLimeSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink, fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nomi va SKU
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          if (p.hasDona) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.panel,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text('1 dona = 0.25 m²',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SKU: ${p.sku.isNotEmpty ? p.sku : 'Yo‘q'}  ·  QR: ${p.qrCode.isNotEmpty ? p.qrCode : 'Yo‘q'}',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),

                                // Narx va Tannarx
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${money(p.price)} / ${p.unit}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      if (p.costPrice > 0)
                                        Text(
                                          'Tannarx: ${money(p.costPrice)}',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),

                                // Qoldiq holati nishoni
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: stockColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    stockLabel,
                                    style: TextStyle(color: stockColor, fontWeight: FontWeight.w700, fontSize: 11),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Amallar: Tahrirlash va O'chirish
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                      tooltip: 'Tahrirlash',
                                      onPressed: () => _edit(p),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                                      tooltip: 'O‘chirish',
                                      onPressed: () => _delete(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStat({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262B) : accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? accentColor : accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF8E959E) : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mahsulot qo'shish va tahrirlash dialogi
// ---------------------------------------------------------------------------

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key, required this.repo, this.product});
  final ProductRepository repo;
  final Product? product;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _qr = TextEditingController(text: widget.product?.qrCode);
  late final _price = TextEditingController(text: widget.product == null ? '' : qty(widget.product!.price));
  late final _cost = TextEditingController(text: widget.product == null ? '' : qty(widget.product!.costPrice));
  final _stock = TextEditingController();
  late String _unit = widget.product?.unit ?? 'm2';
  late bool _stone = widget.product?.hasDona ?? false;
  String? _error;
  bool _busy = false;

  static const _units = ['m2', 'dona', 'kg', 'm', 'litr'];

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _qr.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseInput(_price.text);
    final cost = _cost.text.trim().isEmpty ? 0.0 : parseInput(_cost.text);
    final stock = _stock.text.trim().isEmpty ? 0.0 : parseInput(_stock.text);

    if (_name.text.trim().isEmpty) {
      setState(() {
        _error = 'Nomini kiriting';
      });
      return;
    }
    if (price == null || price < 0) {
      setState(() {
        _error = 'Sotuv narxini to‘g‘ri kiriting';
      });
      return;
    }
    if (cost == null || cost < 0 || stock == null || stock < 0) {
      setState(() {
        _error = 'Raqamlarni to‘g‘ri kiriting';
      });
      return;
    }

    final p = Product(
      id: widget.product?.id ?? 0,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      qrCode: _qr.text.trim(),
      unit: _unit,
      donaM2: (_stone && _unit == 'm2') ? Units.stoneDonaM2 : null,
      price: price,
      costPrice: cost,
    );

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.product == null) {
        await widget.repo.create(p, initialStock: stock);
      } else {
        await widget.repo.update(p);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(isNew ? 'Yangi Mahsulot Qo‘shish' : 'Mahsulotni Tahrirlash',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Mahsulot nomi'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sku,
                      decoration: const InputDecoration(labelText: 'SKU kodi (ixtiyoriy)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _qr,
                      decoration: const InputDecoration(labelText: 'QR / Shtrix kod'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Bazaviy o‘lchov birligi'),
                items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u))],
                onChanged: (v) {
                  setState(() {
                    _unit = v ?? _unit;
                  });
                },
              ),
              if (_unit == 'm2') ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dona bilan sotiladi (1 dona = 0.25 m²)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: _stone,
                  onChanged: (v) {
                    setState(() {
                      _stone = v;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Sotuv narxi (so‘m / $_unit)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tannarx (so‘m)'),
              ),
              if (isNew) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Boshlang‘ich ombor qoldig‘i ($_unit)'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Bekor'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.darkCard,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}
