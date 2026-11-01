import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/units.dart';
import '../data/api_client.dart';
import '../data/local_image_store.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/cart_controller.dart';
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
    _future = _repo.list();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _repo.list();
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

  Future<void> _showQrLabel(Product p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductQrLabelDialog(
        productName: p.name,
        qrCode: p.qrCode.isNotEmpty ? p.qrCode : (p.sku.isNotEmpty ? p.sku : 'STX-${p.id}'),
        sku: p.sku,
        price: p.price,
        unit: p.unit,
        product: p,
      ),
    );
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dialogBg,
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
    final filters = ['Barchasi', 'Toshlar (m²)', 'Sortli', 'Dona', 'Kam qolgan'];

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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

          // Qidiruv va Filtr qo'llash
          final q = _search.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            displayList = displayList.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q) ||
                  p.qrCode.toLowerCase().contains(q);
            }).toList();
          }

          if (_selectedFilter == 'Toshlar (m²)') {
            displayList = displayList.where((p) => p.unit == 'm2').toList();
          } else if (_selectedFilter == 'Sortli') {
            displayList = displayList.where((p) => p.hasSorts || (p.sort != null && p.sort!.isNotEmpty)).toList();
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
                final isNarrow = constraints.maxWidth < 720;
                final isExtraSmall = constraints.maxWidth < 420;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 28, 8, isNarrow ? 14 : 28, 80),
                  children: [
                    // Yuqori 3 ta mini-statistika kartasi
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat(
                              context: context,
                              title: 'Jami Mahsulotlar',
                              value: '$totalCount ta',
                              icon: Icons.inventory_2_outlined,
                              accentColor: AppColors.neonLime,
                              isHeroCard: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildMiniStat(
                              context: context,
                              title: 'Ombordagi Tovarlar Qiymati',
                              value: money(totalStockValue),
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: AppColors.green,
                              isHeroCard: false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildMiniStat(
                              context: context,
                              title: 'Zaxirasi Kam Qolgan',
                              value: '$lowStockCount ta tovar',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFEAB308),
                              isHeroCard: false,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildMiniStat(
                        context: context,
                        title: 'Jami Mahsulotlar',
                        value: '$totalCount ta',
                        icon: Icons.inventory_2_outlined,
                        accentColor: AppColors.neonLime,
                        isHeroCard: true,
                        isCompact: isNarrow,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat(
                              context: context,
                              title: 'Umumiy Qiymat',
                              value: money(totalStockValue),
                              icon: Icons.account_balance_wallet_outlined,
                              accentColor: AppColors.green,
                              isHeroCard: false,
                              isCompact: isNarrow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMiniStat(
                              context: context,
                              title: 'Kam Qolgan',
                              value: '$lowStockCount ta',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFEAB308),
                              isHeroCard: false,
                              isCompact: isNarrow,
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
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _search,
                              style: TextStyle(fontSize: 13, color: context.inkColor, fontWeight: FontWeight.w500),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: context.cardColor,
                                isDense: true,
                                hintText: isNarrow ? 'Qidirish...' : 'Qidirish (Nomi, SKU yoki QR kod)...',
                                hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.normal),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                                        onPressed: () {
                                          _search.clear();
                                          setState(() {});
                                        },
                                        splashRadius: 18,
                                        padding: EdgeInsets.zero,
                                      ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: context.borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: context.isDark ? AppColors.neonLime : AppColors.ink, width: 1.5),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isExtraSmall)
                          Tooltip(
                            message: 'Mahsulot qo‘shish',
                            child: FilledButton(
                              onPressed: () => _edit(),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                                foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                                padding: const EdgeInsets.all(12),
                                shape: const CircleBorder(),
                                minimumSize: const Size(44, 44),
                              ),
                              child: Icon(Icons.add, size: 20, color: context.isDark ? AppColors.ink : AppColors.neonLime),
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _edit(),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                              foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            icon: Icon(Icons.add, size: 18, color: context.isDark ? AppColors.ink : AppColors.neonLime),
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
                                  color: _selectedFilter == f
                                      ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                                      : context.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _selectedFilter == f
                                        ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                                        : context.borderColor,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    color: _selectedFilter == f
                                        ? (context.isDark ? AppColors.ink : Colors.white)
                                        : context.inkColor,
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
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: context.borderColor),
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

                          if (isNarrow) {
                            // Mobil / tor ekranlar uchun 2 qavatli toza moslashuvchan karta
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1-qator: Logo, Nomi, SKU va Amallar
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () => showProductImagePreview(
                                          context,
                                          imageUrl: p.imageUrl,
                                          name: p.name,
                                          subtitle: '${money(p.price)} / ${p.unit} • Qoldiq: ${qty(p.stock)} ${p.unit}',
                                        ),
                                        child: ProductThumbnail(
                                          imageUrl: p.imageUrl,
                                          name: p.name,
                                          size: 58,
                                          borderRadius: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                color: context.inkColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  'SKU: ${p.sku.isNotEmpty ? p.sku : 'Yo‘q'}',
                                                  style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
                                                ),
                                                if (p.hasDona)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: context.pillColor,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('1 dona = 0.25 m²',
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                                                  ),
                                                if (p.sort != null && p.sort!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: context.isDark ? const Color(0xFF332512) : const Color(0xFFFEF3C7),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      p.sort == 'oliy' ? 'Oliy sort' : '${p.sort}-sort',
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                                    ),
                                                  )
                                                else if (p.hasSorts)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: context.isDark ? const Color(0xFF1B2E1D) : const Color(0xFFECFDF5),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text('1 • 1.5 • 2 sort',
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.green)),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                                            tooltip: 'QR Yorliq',
                                            onPressed: () => _showQrLabel(p),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            tooltip: 'Tahrirlash',
                                            onPressed: () => _edit(p),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                            tooltip: 'O‘chirish',
                                            onPressed: () => _delete(p),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  Divider(height: 1, color: context.borderColor),
                                  const SizedBox(height: 10),

                                  // 2-qator: Narx va Qoldiq
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                '${money(p.price)} / ${p.unit}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13.5,
                                                  color: context.inkColor,
                                                ),
                                              ),
                                            ),
                                            if (p.costPrice > 0)
                                              Text(
                                                'Tannarx: ${money(p.costPrice)}',
                                                style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: stockColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          stockLabel,
                                          style: TextStyle(color: stockColor, fontWeight: FontWeight.w700, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          // Katta ekranlar (Desktop/Planshet) uchun gorizontal to'liq qator
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              children: [
                                // Mahsulot logosi
                                GestureDetector(
                                  onTap: () => showProductImagePreview(
                                    context,
                                    imageUrl: p.imageUrl,
                                    name: p.name,
                                    subtitle: '${money(p.price)} / ${p.unit} • Qoldiq: ${qty(p.stock)} ${p.unit}',
                                  ),
                                  child: ProductThumbnail(
                                    imageUrl: p.imageUrl,
                                    name: p.name,
                                    size: 58,
                                    borderRadius: 14,
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
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ),
                                          if (p.category != null && p.category!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (context.isDark ? AppColors.neonLime : const Color(0xFF0D9488)).withOpacity(0.14),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                p.category!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.isDark ? AppColors.neonLime : const Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (p.hasDona) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.pillColor,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text('1 dona = 0.25 m²',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                          if (p.sort != null && p.sort!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.isDark ? const Color(0xFF332512) : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                p.sort == 'oliy' ? 'Oliy sort' : '${p.sort}-sort',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                              ),
                                            ),
                                          ] else if (p.hasSorts) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.isDark ? const Color(0xFF1B2E1D) : const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text('1 • 1.5 • 2 sort',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                                            ),
                                          ],
                                          if (p.thickness != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: context.borderColor),
                                              ),
                                              child: Text(
                                                '${p.thickness} sm',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.subtextColor),
                                              ),
                                            ),
                                          ],
                                          if (p.color != null && p.color!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            StoneColorBadge(colorName: p.color!),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          Text(
                                            'SKU: ${p.sku.isNotEmpty ? p.sku : 'Yo‘q'}',
                                            style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                          ),
                                          InkWell(
                                            onTap: () => _showQrLabel(p),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.isDark ? const Color(0xFF1E2822) : const Color(0xFFE8F5E9),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: (context.isDark ? AppColors.greenBright : AppColors.green).withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.qr_code_rounded, size: 12, color: context.isDark ? AppColors.greenBright : AppColors.green),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    p.qrCode.isNotEmpty ? p.qrCode : 'QR Yorliq',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: context.isDark ? AppColors.greenBright : const Color(0xFF2E7D32),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
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
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${money(p.price)} / ${p.unit}',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
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

                                // Amallar: QR Yorliq, Tahrirlash va O'chirish
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                      tooltip: 'QR Yorliq (Chop etish)',
                                      onPressed: () => _showQrLabel(p),
                                    ),
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
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isHeroCard,
    bool isCompact = false,
  }) {
    final isDarkTheme = context.isDark;
    final isHero = isHeroCard && !isDarkTheme;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 18),
      decoration: BoxDecoration(
        color: isHero ? AppColors.darkCard : context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isHero ? AppColors.darkCard : context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 34 : 40,
            height: isCompact ? 34 : 40,
            decoration: BoxDecoration(
              color: isHero ? const Color(0xFF22262B) : accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: isCompact ? 18 : 20),
          ),
          SizedBox(width: isCompact ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isHero ? const Color(0xFF8E959E) : context.mutedColor,
                    fontSize: isCompact ? 10.5 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isHero ? Colors.white : context.inkColor,
                      fontSize: isCompact ? 15 : 18,
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
  late final _thickness = TextEditingController(text: widget.product?.thickness != null ? qty(widget.product!.thickness!) : '');
  late final _color = TextEditingController(text: widget.product?.color ?? '');
  late final _priceSort1 = TextEditingController(text: widget.product?.priceSort1 != null ? qty(widget.product!.priceSort1!) : '');
  late final _priceSort1_5 = TextEditingController(text: widget.product?.priceSort1_5 != null ? qty(widget.product!.priceSort1_5!) : '');
  late final _priceSort2 = TextEditingController(text: widget.product?.priceSort2 != null ? qty(widget.product!.priceSort2!) : '');
  late final _imageUrl = TextEditingController(text: widget.product?.imageUrl);
  final _stock = TextEditingController();
  late String? _category = widget.product?.category;
  late String _unit = widget.product?.unit ?? 'm2';
  late bool _stone = widget.product?.hasDona ?? false;
  late bool _hasSorts = widget.product?.hasSorts ?? false;
  late String? _sort = widget.product?.sort;
  String? _error;
  bool _busy = false;
  bool _uploadingImage = false;

  static const _units = ['m2', 'dona', 'kg', 'm', 'litr'];

  void _autoAppendSortToName(String sortText) {
    String current = _name.text.trim();
    if (current.isEmpty) return;
    final sortRegex = RegExp(r'\s*\((1|1\.5|2|3|Oliy|oliy)[ -]sort\)', caseSensitive: false);
    if (sortRegex.hasMatch(current)) {
      current = current.replaceAll(sortRegex, '').trim();
    }
    if (sortText.isNotEmpty) {
      _name.text = '$current ($sortText)';
    } else {
      _name.text = current;
    }
  }

  Widget _buildSortChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? badgeIcon,
  }) {
    final isDark = context.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.neonLime : AppColors.darkCard)
              : (isDark ? const Color(0xFF1B232A) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.neonLime : AppColors.darkCard)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeIcon != null) ...[
              Icon(
                badgeIcon,
                size: 13,
                color: selected
                    ? (isDark ? AppColors.ink : AppColors.neonLime)
                    : context.mutedColor,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? (isDark ? AppColors.ink : Colors.white)
                    : context.inkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _qr.dispose();
    _price.dispose();
    _cost.dispose();
    _thickness.dispose();
    _color.dispose();
    _priceSort1.dispose();
    _priceSort1_5.dispose();
    _priceSort2.dispose();
    _imageUrl.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _uploadingImage = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }

      final fileBytes = await picked.readAsBytes();
      if (fileBytes.isEmpty) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }

      final pickedFilename = picked.name.isNotEmpty
          ? picked.name
          : 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Rasmni avval ixcham qilib siqish (Base64)
      String finalImageValue;
      try {
        final decoded = img.decodeImage(Uint8List.fromList(fileBytes));
        if (decoded != null) {
          final resized = (decoded.width > 360 || decoded.height > 360)
              ? img.copyResize(
                  decoded,
                  width: decoded.width >= decoded.height ? 360 : null,
                  height: decoded.height > decoded.width ? 360 : null,
                )
              : decoded;
          final jpgBytes = img.encodeJpg(resized, quality: 78);
          finalImageValue = 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';
        } else {
          finalImageValue = 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
        }
      } catch (_) {
        finalImageValue = 'data:image/jpeg;base64,${base64Encode(fileBytes)}';
      }

      // Agar serverda upload yo'li mavjud bo'lsa, yuklashga urinib ko'ramiz
      try {
        final uploadedUrl = await widget.repo.uploadImage(
          fileBytes,
          pickedFilename,
        );
        if (uploadedUrl.isNotEmpty) {
          finalImageValue = uploadedUrl;
        }
      } catch (_) {
        // Serverda upload yo'li bo'lmasa yoki xato bersa, siqilgan Base64 rasm bevosita ishlatiladi
      }

      if (mounted) {
        setState(() {
          _imageUrl.text = finalImageValue;
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _error = 'Rasm tanlashda xatolik: $e';
        });
      }
    }
  }

  void _autoGenerateQr() {
    final cleanName = _name.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final suffix = (DateTime.now().millisecondsSinceEpoch % 900) + 100;
    final code = cleanName.isNotEmpty ? 'STX-$cleanName' : 'STX-PROD-$suffix';
    setState(() {
      _qr.text = code;
      if (_sku.text.trim().isEmpty) {
        _sku.text = cleanName.isNotEmpty ? cleanName : 'SKU-$suffix';
      }
    });
  }

  void _previewQrLabel(BuildContext context) {
    final qrData = _qr.text.trim();
    if (qrData.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => ProductQrLabelDialog(
        productName: _name.text.trim().isNotEmpty ? _name.text.trim() : 'Nomsiz Mahsulot',
        qrCode: qrData,
        sku: _sku.text.trim(),
        price: parseInput(_price.text) ?? (widget.product?.price ?? 0),
        unit: _unit,
        product: widget.product,
      ),
    );
  }

  Future<void> _save() async {
    final p1 = parseInput(_priceSort1.text);
    final p1_5 = parseInput(_priceSort1_5.text);
    final p2 = parseInput(_priceSort2.text);
    final thick = parseInput(_thickness.text);

    final effectivePriceText = _price.text.trim().isNotEmpty
        ? _price.text
        : (_hasSorts ? (_priceSort1_5.text.isNotEmpty ? _priceSort1_5.text : _priceSort1.text) : '');
    final price = parseInput(effectivePriceText);
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
      category: _category,
      sku: _sku.text.trim(),
      qrCode: _qr.text.trim(),
      unit: _unit,
      donaM2: (_stone && _unit == 'm2') ? Units.stoneDonaM2 : null,
      thickness: (_unit == 'm2' && thick != null && thick > 0) ? thick : null,
      sort: _sort,
      hasSorts: _hasSorts,
      color: _color.text.trim().isNotEmpty ? _color.text.trim() : null,
      priceSort1: _hasSorts ? p1 : null,
      priceSort1_5: _hasSorts ? p1_5 : null,
      priceSort2: _hasSorts ? p2 : null,
      price: price,
      costPrice: cost,
      imageUrl: _imageUrl.text.trim().isNotEmpty ? _imageUrl.text.trim() : null,
    );

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (widget.product == null) {
        final created = await widget.repo.create(p, initialStock: stock);
        LocalImageStore.saveImage(created.id, p.imageUrl, created.name);
      } else {
        LocalImageStore.saveImage(p.id, p.imageUrl, p.name);
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

  Widget _buildImagePicker(BuildContext context) {
    final currentUrl = _imageUrl.text.trim();
    final hasImage = currentUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF192028) : const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: context.isDark ? AppColors.neonLime : AppColors.ink),
              const SizedBox(width: 8),
              const Text(
                'Mahsulot rasmi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              if (_uploadingImage)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: context.isDark ? const Color(0xFF10151B) : const Color(0xFFE2E8F0),
                    child: Builder(
                      builder: (_) {
                        try {
                          if (currentUrl.startsWith('data:image/') || currentUrl.contains(';base64,')) {
                            final comma = currentUrl.indexOf(',');
                            final b64 = comma != -1 ? currentUrl.substring(comma + 1).trim() : currentUrl;
                            return Image.memory(
                              Uint8List.fromList(base64Decode(b64)),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined, size: 36, color: AppColors.muted),
                              ),
                            );
                          }
                          if (!currentUrl.startsWith('http') &&
                              !currentUrl.startsWith('/') &&
                              File(currentUrl).existsSync()) {
                            return Image.file(
                              File(currentUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined, size: 36, color: AppColors.muted),
                              ),
                            );
                          }
                          return Image.network(
                            ApiClient.resolveUrl(currentUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined, size: 36, color: AppColors.muted),
                            ),
                          );
                        } catch (_) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined, size: 36, color: AppColors.muted),
                          );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        tooltip: 'Rasmni olib tashlash',
                        onPressed: () => setState(() => _imageUrl.clear()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadingImage ? null : _pickAndUploadImage,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Rasmni almashtirish', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _uploadingImage ? null : _pickAndUploadImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (context.isDark ? AppColors.neonLime : AppColors.green).withValues(alpha: 0.35),
                    style: BorderStyle.solid,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: context.isDark ? AppColors.neonLime : AppColors.green,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _uploadingImage ? 'Rasm serverga yuklanmoqda...' : 'Galereyadan rasm yuklash',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: context.isDark ? AppColors.neonLime : AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'JPG, PNG yoki WebP formatida',
                      style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _imageUrl,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'Rasm havolasi (URL yoki yo‘l)',
              hintText: 'https://... yoki galereyadan yuklang',
              prefixIcon: const Icon(Icons.link_rounded, size: 18),
              isDense: true,
              suffixIcon: _imageUrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () => setState(() => _imageUrl.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveQrPreview(BuildContext context) {
    final qrData = _qr.text.trim();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF192028) : const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qrData.isNotEmpty
              ? (context.isDark ? AppColors.neonLime.withValues(alpha: 0.4) : AppColors.green.withValues(alpha: 0.4))
              : context.borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 18,
                color: context.isDark ? AppColors.neonLime : AppColors.green,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Haqiqiy QR Yorliq (Stiker ko‘rinishi)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              if (qrData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF132D21) : AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Skanerlanadi',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.isDark ? AppColors.greenBright : AppColors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (qrData.isNotEmpty) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Color(0xFF0F9D58), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'NTM ERP',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 120.0,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      qrData,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    if (_name.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _name.text.trim(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _previewQrLabel(context),
                  icon: const Icon(Icons.print_rounded, size: 15),
                  label: const Text('Chop etish / Katta ko‘rish', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  tooltip: 'Kodni nusxalash',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrData));
                    showMessage(context, 'QR kod nusxalandi: $qrData');
                  },
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 36, color: AppColors.muted),
                  const SizedBox(height: 6),
                  const Text(
                    'QR kod hali kiritilmagan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _autoGenerateQr,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: const Text('Avtomatik QR yaratish', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return AlertDialog(
      backgroundColor: context.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(isNew ? 'Yangi Mahsulot Qo‘shish' : 'Mahsulotni Tahrirlash',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePicker(context),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Mahsulot nomi'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: standardProductCategories.contains(_category) ? _category : null,
                decoration: InputDecoration(
                  labelText: 'Mahsulot kategoriyasi',
                  prefixIcon: const Icon(Icons.category_rounded, size: 20),
                  suffixIcon: _category != null
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          tooltip: 'Tozalash',
                          onPressed: () => setState(() => _category = null),
                        )
                      : null,
                ),
                hint: const Text('Kategoriyani tanlang'),
                items: [
                  for (final cat in standardProductCategories)
                    DropdownMenuItem(value: cat, child: Text(cat)),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final cat in standardProductCategories)
                    ChoiceChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      selected: _category == cat,
                      onSelected: (sel) => setState(() => _category = sel ? cat : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final isCompact = box.maxWidth < 420;
                  final skuField = TextField(
                    controller: _sku,
                    decoration: const InputDecoration(labelText: 'SKU kodi (ixtiyoriy)'),
                  );
                  final qrField = TextField(
                    controller: _qr,
                    decoration: InputDecoration(
                      labelText: 'QR / Shtrix kod',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        tooltip: 'Avto-kod generatsiya qilish',
                        onPressed: _autoGenerateQr,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  );

                  if (isCompact) {
                    return Column(
                      children: [
                        skuField,
                        const SizedBox(height: 12),
                        qrField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: skuField),
                      const SizedBox(width: 10),
                      Expanded(child: qrField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _unit,
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.layers_outlined, size: 18, color: context.isDark ? AppColors.neonLime : AppColors.ink),
                        const SizedBox(width: 8),
                        Text(
                          'Mahsulot sorti (qalinligi / navi)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.inkColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ushbu mahsulot qaysi sortga tegishli yoki kassada tanlanadimi?',
                      style: TextStyle(fontSize: 11, color: context.mutedColor),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip(
                          label: 'Sortsiz (Oddiy)',
                          selected: !_hasSorts && (_sort == null || _sort!.isEmpty),
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = null;
                              _autoAppendSortToName('');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: '1-sort',
                          selected: !_hasSorts && _sort == '1',
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = '1';
                              _autoAppendSortToName('1-sort');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: '1.5-sort',
                          selected: !_hasSorts && _sort == '1.5',
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = '1.5';
                              _autoAppendSortToName('1.5-sort');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: '2-sort',
                          selected: !_hasSorts && _sort == '2',
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = '2';
                              _autoAppendSortToName('2-sort');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: '3-sort',
                          selected: !_hasSorts && _sort == '3',
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = '3';
                              _autoAppendSortToName('3-sort');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: 'Oliy sort',
                          selected: !_hasSorts && _sort == 'oliy',
                          onTap: () {
                            setState(() {
                              _hasSorts = false;
                              _sort = 'oliy';
                              _autoAppendSortToName('Oliy sort');
                            });
                          },
                        ),
                        _buildSortChip(
                          label: '3 xil sorti bor (1 / 1.5 / 2)',
                          selected: _hasSorts,
                          badgeIcon: Icons.auto_awesome,
                          onTap: () {
                            setState(() {
                              _hasSorts = true;
                              _sort = null;
                              _autoAppendSortToName('');
                            });
                          },
                        ),
                      ],
                    ),
                    if (_hasSorts) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF1B2E1D) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: context.isDark ? const Color(0xFF22542B) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.green),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kassada (POS) sotuvchi har bir sotuvda 1, 1.5 yoki 2-sortni tanlay oladi.',
                                style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1B2028) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 16, color: AppColors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Rangi (masalan: Ko‘k, Oq, Qora)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.inkColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in ['Qora', 'Oq', 'Ko‘k', 'Kulrang', 'Bej', 'Yashil', 'Qizil', 'Jigarrang', 'Sariq'])
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                final cur = _color.text.trim();
                                if (cur.isEmpty) {
                                  _color.text = c;
                                } else if (cur.contains(c)) {
                                  final parts = cur.split(RegExp(r'[,/•|]')).map((s) => s.trim()).where((s) => s.isNotEmpty && s != c).toList();
                                  _color.text = parts.join(', ');
                                } else {
                                  _color.text = '$cur, $c';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _color.text.contains(c)
                                    ? (context.isDark ? AppColors.neonLime.withValues(alpha: 0.25) : AppColors.greenSoft)
                                    : (context.isDark ? const Color(0xFF242C38) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _color.text.contains(c) ? AppColors.green : context.borderColor,
                                  width: _color.text.contains(c) ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: getStoneColor(c),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black26),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    c,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _color.text.contains(c) ? FontWeight.w800 : FontWeight.w600,
                                      color: context.inkColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _color,
                      decoration: InputDecoration(
                        labelText: 'Rang (yoki bir nechta: Ko‘k, Oq, Qora)',
                        hintText: 'Masalan: Ko‘k yoki Qora, Oq',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: _color.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => setState(() => _color.clear()),
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              if (_unit == 'm2') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _thickness,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Kafel / tosh qalinligi (sm)',
                    hintText: 'Masalan: 2.0 yoki 1.8',
                    prefixIcon: Icon(Icons.layers_outlined, size: 20),
                  ),
                ),
              ],
              if (_hasSorts) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceSort1,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '1-sort (so‘m)',
                          hintText: '180 000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _priceSort1_5,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '1.5-sort (so‘m)',
                          hintText: '165 000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _priceSort2,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '2-sort (so‘m)',
                          hintText: '150 000',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _hasSorts ? 'Bazaviy narx (so‘m / $_unit)' : 'Sotuv narxi (so‘m / $_unit)',
                ),
                onChanged: (_) => setState(() {}),
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

              // Haqiqiy jonli QR-kod stiker ko'rinishi
              _buildLiveQrPreview(context),

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
            backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
            foregroundColor: context.isDark ? AppColors.ink : Colors.white,
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

// ---------------------------------------------------------------------------
// Mahsulot QR Yorlig'i (Chop etish va Katta ko'rish dialogi)
// ---------------------------------------------------------------------------

class ProductQrLabelDialog extends StatelessWidget {
  const ProductQrLabelDialog({
    super.key,
    required this.productName,
    required this.qrCode,
    this.sku = '',
    required this.price,
    this.unit = 'm2',
    this.product,
  });

  final String productName;
  final String qrCode;
  final String sku;
  final double price;
  final String unit;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final cleanCode = qrCode.trim().isNotEmpty ? qrCode.trim() : 'NO-CODE';

    return Dialog(
      backgroundColor: context.dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sarlavha
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF132D21) : AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: AppColors.green, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mahsulot QR Yorlig‘i',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('Chop etish va kassa skaneri uchun stiker',
                            style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Oq chop etiladigan stiker kartasi
              Center(
                child: Container(
                  width: 280,
                  constraints: BoxConstraints(maxWidth: math.max(200.0, MediaQuery.sizeOf(context).width - 80.0)),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0D7DE), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kompaniya logotipi / stiker sarlavhasi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F9D58),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'NTM MARBLE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Tosh ishlab chiqarish majmuasi',
                        style: TextStyle(fontSize: 8.5, color: Color(0xFF57606A), fontWeight: FontWeight.w500),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Color(0xFFE1E4E8), height: 1, thickness: 1),
                      ),

                      // Haqiqiy skanerlanadigan QR Kod
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEAECEF), width: 1),
                        ),
                        child: QrImageView(
                          data: cleanCode,
                          version: QrVersions.auto,
                          size: math.min(180.0, math.max(120.0, MediaQuery.sizeOf(context).width - 130.0)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // QR Kod matni
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE1E4E8)),
                        ),
                        child: Text(
                          cleanCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            letterSpacing: 1.2,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Mahsulot nomi
                      Text(
                        productName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Narx va o'lchov birligi
                      Text(
                        '${money(price)} / $unit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Pastki izoh
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              sku.isNotEmpty ? 'SKU: $sku' : 'NTM ERP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF6E7781), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sana: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF6E7781), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Harakat tugmalari
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cleanCode));
                        showMessage(context, 'QR kod nusxalandi: $cleanCode');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Nusxalash', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        showMessage(context, '🖨️ Yorliq chop etishga yuborildi: [$productName]');
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Chop etish', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                        foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              if (product != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      context.read<CartController>().add(product!);
                      showMessage(context, '✅ “$productName” kassa savatiga qo‘shildi!');
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Kassa savatiga qo‘shish (Sinash)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
