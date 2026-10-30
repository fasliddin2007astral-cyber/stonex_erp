import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/local_image_store.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'receipt_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.onNewOrder});
  final VoidCallback? onNewOrder;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'Faol (Kutilmoqda)'; // 'Barchasi', 'Faol (Kutilmoqda)', 'Topshirilgan', 'Bekor qilingan'
  bool _loading = true;
  String? _error;
  List<SaleResult> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = context.read<AppRepositories>();
      final allSales = await repos.sales.listSales(limit: 200);
      // Buyurtmalar: status == 'order' yoki 'cancelled' yoki (status == 'completed' va izohi mavjud/avval buyurtma bo'lgan)
      final orders = allSales.where((s) => s.isOrder || s.status == 'cancelled' || s.note != null).toList();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<SaleResult> get _filteredOrders {
    var list = _orders;

    // Status filter
    if (_statusFilter == 'Faol (Kutilmoqda)') {
      list = list.where((o) => o.status == 'order').toList();
    } else if (_statusFilter == 'Topshirilgan') {
      list = list.where((o) => o.status == 'completed').toList();
    } else if (_statusFilter == 'Bekor qilingan') {
      list = list.where((o) => o.status == 'cancelled').toList();
    }

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final idStr = '#${o.id}';
        final name = o.customerName?.toLowerCase() ?? '';
        final phone = o.customerPhone?.toLowerCase() ?? '';
        final note = o.note?.toLowerCase() ?? '';
        final items = o.items.map((i) => i.productName.toLowerCase()).join(' ');
        return idStr.contains(q) ||
            o.id.toString().contains(q) ||
            name.contains(q) ||
            phone.contains(q) ||
            note.contains(q) ||
            items.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _fulfillOrder(SaleResult order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Buyurtmani topshirish',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buyurtma #${order.id} mijozga topshirilsinmi?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.borderColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mijoz: ${order.customerName ?? 'Noma‘lum'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Jami summa: ${money(order.total)}', style: const TextStyle(fontSize: 12.5)),
                  Text(
                    'Qoldiq to‘lov: ${money(order.debt)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: order.debt > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tasdiqlangach, mahsulotlar ombordagi zaxiradan yechiladi va buyurtma yakunlangan deb belgilanadi.',
              style: TextStyle(fontSize: 12, color: context.subtextColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Topshirish', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repos = context.read<AppRepositories>();
      final updated = await repos.sales.fulfillOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          content: Text('Buyurtma #${order.id} muvaffaqiyatli topshirildi va ombordan yechildi!'),
        ),
      );
      _loadOrders();
      await ReceiptDialog.show(context, updated);
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text('Topshirib bo‘lmadi'),
              ],
            ),
            content: Text(e.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tushundim'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder(SaleResult order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Buyurtmani bekor qilish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text('Haqiqatan ham #${order.id} sonli buyurtmani bekor qilmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yo‘q')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Bekor qilish'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repos = context.read<AppRepositories>();
      await repos.sales.cancelOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Buyurtma #${order.id} bekor qilindi'),
        ),
      );
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _payDebtDialog(SaleResult order) async {
    final ctrl = TextEditingController(text: order.debt.round().toString());
    var method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'To‘lov qabul qilish — Buyurtma #${order.id}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Qolgan summa: ${money(order.debt)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'To‘lov summasi'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('Naqd')),
                    ButtonSegment(value: 'card', label: Text('Karta')),
                    ButtonSegment(value: 'bank', label: Text('Hisob')),
                  ],
                  selected: {method},
                  onSelectionChanged: (s) => setS(() => method = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.neonLime, foregroundColor: AppColors.ink),
              child: const Text('To‘lovni tasdiqlash', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    final val = parseInput(ctrl.text);
    ctrl.dispose();
    if (ok == true && val != null && val > 0 && mounted) {
      try {
        final repos = context.read<AppRepositories>();
        final updated = await repos.sales.payDebt(order.id, val, method: method);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            content: Text('Buyurtma #${order.id} uchun ${money(val)} qabul qilindi'),
          ),
        );
        _loadOrders();
        await ReceiptDialog.show(context, updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final totalOrders = _orders.length;
    final activeOrders = _orders.where((o) => o.status == 'order').length;
    final completedOrders = _orders.where((o) => o.status == 'completed').length;
    final totalAdvances = _orders.fold<double>(0, (a, o) => a + o.paid);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppColors.neonLime,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI kartochkalari
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiCard(
                      title: 'Jami Buyurtmalar',
                      value: '$totalOrders ta',
                      icon: Icons.assignment_rounded,
                      color: const Color(0xFF3B82F6),
                      width: cardWidth,
                    ),
                    _KpiCard(
                      title: 'Kutilmoqda (Faol)',
                      value: '$activeOrders ta',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFF59E0B),
                      width: cardWidth,
                    ),
                    _KpiCard(
                      title: 'Topshirilgan',
                      value: '$completedOrders ta',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      width: cardWidth,
                    ),
                    _KpiCard(
                      title: 'Avanslar Summasi',
                      value: money(totalAdvances),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.neonLimeDark,
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Qidiruv va Filterlar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Mijoz ismi, telefon, buyurtma # yoki mahsulot nomi...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in ['Faol (Kutilmoqda)', 'Barchasi', 'Topshirilgan', 'Bekor qilingan'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              selected: _statusFilter == s,
                              onSelected: (sel) {
                                if (sel) setState(() => _statusFilter = s);
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

            // Buyurtmalar ro'yxati
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.neonLime),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                      const SizedBox(height: 12),
                      Text('Xatolik yuz berdi: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _loadOrders, child: const Text('Qayta urinish')),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_late_outlined, size: 54, color: context.subtextColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'Buyurtmalar topilmadi',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.inkColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kassada tovarlarni savatga qo‘shib, to‘lov oynasida "Buyurtma (Pre-order)" sifatida saqlashingiz mumkin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: context.subtextColor),
                    ),
                  ],
                ),
              )
            else
              for (final order in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OrderCard(
                    order: order,
                    onFulfill: () => _fulfillOrder(order),
                    onCancel: () => _cancelOrder(order),
                    onPay: () => _payDebtDialog(order),
                    onReceipt: () => ReceiptDialog.show(context, order),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: context.subtextColor, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.inkColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onFulfill,
    required this.onCancel,
    required this.onPay,
    required this.onReceipt,
  });

  final SaleResult order;
  final VoidCallback onFulfill;
  final VoidCallback onCancel;
  final VoidCallback onPay;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final isOrder = order.status == 'order';
    final isCancelled = order.status == 'cancelled';
    final isCompleted = order.status == 'completed';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isOrder) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Kutilmoqda';
      statusIcon = Icons.hourglass_top_rounded;
    } else if (isCancelled) {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Bekor qilingan';
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = const Color(0xFF10B981);
      statusText = 'Topshirilgan';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOrder ? statusColor.withOpacity(0.4) : context.borderColor,
          width: isOrder ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Buyurtma #${order.id}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDateTime(order.createdAt ?? DateTime.now()),
                        style: TextStyle(fontSize: 11.5, color: context.subtextColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(order.total),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Mijoz va Izoh
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 16, color: context.subtextColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.customerName?.isNotEmpty == true
                            ? '${order.customerName} ${order.customerPhone ?? ''}'
                            : 'Noma‘lum mijoz',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: context.inkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (order.note != null && order.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF21262D) : const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 14, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Izoh: ${order.note}',
                            style: TextStyle(fontSize: 12, color: context.inkColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Mahsulotlar ro'yxati
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1B2129) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.inkColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.quantity.toStringAsFixed(1)} × ${money(item.unitPrice)}',
                          style: TextStyle(fontSize: 11.5, color: context.subtextColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money(item.lineTotal),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.inkColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // To'lovlar qatori
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: context.subtextColor),
                      children: [
                        const TextSpan(text: 'Avans: '),
                        TextSpan(
                          text: money(order.paid),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12, color: context.subtextColor),
                    children: [
                      const TextSpan(text: 'Qoldiq: '),
                      TextSpan(
                        text: money(order.debt),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: order.debt > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Harakat tugmalari
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onReceipt,
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Chek', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (order.debt > 0.005 && !isCancelled)
                  OutlinedButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('To‘lov qo‘shish', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (isOrder) ...[
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Bekor qilish', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onFulfill,
                    icon: const Icon(Icons.task_alt_rounded, size: 16),
                    label: const Text('Topshirish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
