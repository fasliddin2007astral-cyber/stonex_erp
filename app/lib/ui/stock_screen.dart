import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late Future<List<StockMovementRecord>> _movementsFuture;
  late Future<List<Product>> _productsFuture;
  String _selectedFilter = 'Barchasi';
  final _searchCtrl = TextEditingController();

  StockRepository get _stockRepo => context.read<AppRepositories>().stock;
  ProductRepository get _productRepo => context.read<AppRepositories>().products;

  @override
  void initState() {
    super.initState();
    _movementsFuture = _stockRepo.movements();
    _productsFuture = _productRepo.list();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _movementsFuture = _stockRepo.movements();
        _productsFuture = _productRepo.list();
      });
    }
  }

  Future<void> _purchaseDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StockPurchaseDialog(
        stockRepo: _stockRepo,
        productRepo: _productRepo,
      ),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Xarid muvaffaqiyatli kirim qilindi');
      _reload();
    }
  }

  Future<void> _adjustDialog() async {
    final products = await _productRepo.list();
    if (!mounted) return;
    if (products.isEmpty) {
      return showMessage(context, 'Mahsulotlar yo‘q', error: true);
    }
    Product selected = products.first;
    final deltaCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? error;
    bool busy = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Qoldiqni Tuzatish (Inventarizatsiya)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Product>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Mahsulot'),
                    items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setS(() {
                          selected = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hozirgi hisobdagi qoldiq: ${qty(selected.stock)} ${selected.unit}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deltaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    decoration: InputDecoration(
                      labelText: 'O‘zgarish miqdori (+ yoki -)',
                      hintText: '+10 yoki -5 (${selected.unit})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tuzatish sababi (majburiy)',
                      hintText: 'Brak, qayta sanash, yo‘qotish va h.k.',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Bekor'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final d = parseInput(deltaCtrl.text);
                      final note = noteCtrl.text.trim();
                      if (d == null || d == 0) {
                        setS(() {
                          error = 'O‘zgarish miqdorini 0 dan farqli kiriting';
                        });
                        return;
                      }
                      if (note.isEmpty) {
                        setS(() {
                          error = 'Tuzatish sababini kiritish majburiy';
                        });
                        return;
                      }
                      setS(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await _stockRepo.adjust(productId: selected.id, delta: d, note: note);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setS(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: AppColors.darkCard),
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Tuzatish'),
            ),
          ],
        ),
      ),
    );

    deltaCtrl.dispose();
    noteCtrl.dispose();

    if (ok == true && mounted) {
      showMessage(context, 'Ombor qoldig‘i muvaffaqiyatli tuzatildi');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['Barchasi', 'Xaridlar', 'Sotuvlar', 'Ishlab chiqarish', 'Tuzatishlar'];

    return Scaffold(
      backgroundColor: AppColors.panel,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'adjust_btn',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            onPressed: _adjustDialog,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Inventarizatsiya'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'purchase_btn',
            onPressed: _purchaseDialog,
            icon: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.neonLime),
            label: const Text('Xarid kirimi'),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_movementsFuture, _productsFuture]),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: _reload);
          }

          final allMovements = snap.data![0] as List<StockMovementRecord>;
          final products = snap.data![1] as List<Product>;
          final productMap = {for (final p in products) p.id: p};

          var displayList = List<StockMovementRecord>.from(allMovements);

          if (_selectedFilter == 'Xaridlar') {
            displayList = displayList.where((m) => m.kind == 'purchase' || m.kind == 'opening').toList();
          } else if (_selectedFilter == 'Sotuvlar') {
            displayList = displayList.where((m) => m.kind == 'sale').toList();
          } else if (_selectedFilter == 'Ishlab chiqarish') {
            displayList = displayList.where((m) => m.kind == 'production').toList();
          } else if (_selectedFilter == 'Tuzatishlar') {
            displayList = displayList.where((m) => m.kind == 'adjustment').toList();
          }

          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            displayList = displayList.where((m) {
              final pName = (productMap[m.productId]?.name ?? '').toLowerCase();
              final note = (m.note ?? '').toLowerCase();
              return pName.contains(q) || note.contains(q);
            }).toList();
          }

          // Statistika
          final purchaseTotal = allMovements.where((m) => m.kind == 'purchase').length;
          final saleTotal = allMovements.where((m) => m.kind == 'sale').length;
          final prodTotal = allMovements.where((m) => m.kind == 'production').length;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                  children: [
                    // Yuqori statistika paneli
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStat(
                              'Jami Harakatlar',
                              '${allMovements.length} ta',
                              Icons.history_rounded,
                              AppColors.neonLime,
                              true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Xarid Kirimlari',
                              '$purchaseTotal ta partiya',
                              Icons.input_rounded,
                              AppColors.green,
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Sotuv Chiqimlari',
                              '$saleTotal ta operatsiya',
                              Icons.output_rounded,
                              const Color(0xFFC77700),
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Ishlab Chiqarish',
                              '$prodTotal ta qabul',
                              Icons.precision_manufacturing_rounded,
                              const Color(0xFF245580),
                              false,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildStat('Jami Harakatlar', '${allMovements.length} ta', Icons.history_rounded, AppColors.neonLime, true),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildStat('Kirimlar', '$purchaseTotal ta', Icons.input_rounded, AppColors.green, false)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStat('Chiqimlar', '$saleTotal ta', Icons.output_rounded, const Color(0xFFC77700), false)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Qidiruv va Filtr
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
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Mahsulot nomi yoki izoh bo‘yicha qidirish...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                                suffixIcon: _searchCtrl.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() {});
                                        },
                                      ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _purchaseDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkCard,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.add, size: 18, color: AppColors.neonLime),
                          label: const Text('Xarid kirimi', style: TextStyle(fontWeight: FontWeight.w700)),
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
                                  border: Border.all(color: _selectedFilter == f ? AppColors.darkCard : AppColors.border),
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

                    // Harakatlar ro'yxati
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
                              Icon(Icons.warehouse_outlined, size: 48, color: AppColors.muted),
                              SizedBox(height: 12),
                              Text('Ombor harakatlari topilmadi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                          final m = displayList[i];
                          final p = productMap[m.productId];
                          final isPositive = m.qtyDelta > 0;
                          final unit = p?.unit ?? '';

                          String kindLabel;
                          Color kindColor;
                          IconData kindIcon;

                          switch (m.kind) {
                            case 'purchase':
                              kindLabel = 'Xarid kirimi';
                              kindColor = AppColors.green;
                              kindIcon = Icons.input_rounded;
                              break;
                            case 'sale':
                              kindLabel = 'Sotuv chiqimi';
                              kindColor = const Color(0xFFC77700);
                              kindIcon = Icons.output_rounded;
                              break;
                            case 'production':
                              kindLabel = 'Ishlab chiqarish';
                              kindColor = const Color(0xFF245580);
                              kindIcon = Icons.precision_manufacturing_rounded;
                              break;
                            case 'adjustment':
                              kindLabel = 'Inventarizatsiya';
                              kindColor = const Color(0xFF6B48A8);
                              kindIcon = Icons.tune_rounded;
                              break;
                            default:
                              kindLabel = 'Boshlang‘ich qoldiq';
                              kindColor = AppColors.muted;
                              kindIcon = Icons.flag_rounded;
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
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: kindColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(kindIcon, color: kindColor, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            p?.name ?? 'Mahsulot #${m.productId}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: kindColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              kindLabel,
                                              style: TextStyle(color: kindColor, fontWeight: FontWeight.w700, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${m.note ?? 'Izohsiz'}  ·  ${m.createdAt.day.toString().padLeft(2, '0')}.${m.createdAt.month.toString().padLeft(2, '0')}.${m.createdAt.year} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isPositive ? '+' : ''}${qty(m.qtyDelta)} $unit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isPositive ? AppColors.green : AppColors.danger,
                                  ),
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

  Widget _buildStat(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262B) : color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(color: isDark ? const Color(0xFF8E959E) : AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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
// Xarid kirimi dialogi (Vault uslubida)
// ---------------------------------------------------------------------------

class StockPurchaseDialog extends StatefulWidget {
  const StockPurchaseDialog({super.key, required this.stockRepo, required this.productRepo});
  final StockRepository stockRepo;
  final ProductRepository productRepo;

  @override
  State<StockPurchaseDialog> createState() => _StockPurchaseDialogState();
}

class _StockPurchaseDialogState extends State<StockPurchaseDialog> {
  late Future<List<Product>> _productsFuture;
  Product? _selected;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.productRepo.list().then((products) {
      if (products.isNotEmpty) {
        _selected = products.first;
        if (_selected!.costPrice > 0) {
          _costCtrl.text = _selected!.costPrice.round().toString();
        }
      }
      return products;
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    final q = parseInput(_qtyCtrl.text);
    final c = parseInput(_costCtrl.text);
    if (q == null || q <= 0 || c == null || c < 0) {
      setState(() {
        _error = 'Miqdor va narxni to‘g‘ri kiriting';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.stockRepo.purchase(
        productId: _selected!.id,
        quantity: q,
        unitCost: c,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
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
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final products = snap.data!;
        if (products.isEmpty) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Mahsulotlar mavjud emas'),
            content: const Text('Xarid kirimi qilishdan oldin mahsulot yarating.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
            ],
          );
        }

        _selected ??= products.first;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Yangi Xarid Kirimi (Partiya)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Product>(
                    value: _selected,
                    decoration: const InputDecoration(labelText: 'Mahsulot'),
                    items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selected = v;
                          if (_selected!.costPrice > 0) {
                            _costCtrl.text = _selected!.costPrice.round().toString();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Kirim miqdori (${_selected!.unit})'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Xarid narxi (so‘m / ${_selected!.unit})'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Izoh / Yetkazib beruvchi (ixtiyoriy)'),
                  ),
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
              onPressed: _busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Bekor'),
            ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim qilish', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}

