import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => DeliveriesScreenState();
}

class DeliveriesScreenState extends State<DeliveriesScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all', 'on_the_way', 'loading', 'delivered', 'cancelled'
  List<Delivery> _deliveries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = context.read<AppRepositories>();
      final list = await repos.deliveries.list();
      if (!mounted) return;
      setState(() {
        _deliveries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Delivery> get _filteredDeliveries {
    var list = _deliveries;
    if (_statusFilter != 'all') {
      list = list.where((d) => d.status == _statusFilter).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) {
        return d.vehicleNumber.toLowerCase().contains(q) ||
            d.driverName.toLowerCase().contains(q) ||
            (d.driverPhone ?? '').toLowerCase().contains(q) ||
            d.recipientName.toLowerCase().contains(q) ||
            (d.recipientPhone ?? '').toLowerCase().contains(q) ||
            (d.destinationAddress ?? '').toLowerCase().contains(q) ||
            d.items.any((i) => i.productName.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  Future<void> openNewDeliveryDialog({
    int? saleId,
    String? recipientName,
    String? recipientPhone,
    String? address,
    List<DeliveryItem>? initialItems,
  }) async {
    final repos = context.read<AppRepositories>();
    final created = await showDialog<Delivery>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryEditDialog(
        saleId: saleId,
        initialRecipientName: recipientName,
        initialRecipientPhone: recipientPhone,
        initialAddress: address,
        initialItems: initialItems,
      ),
    );
    if (created != null && mounted) {
      try {
        final saved = await repos.deliveries.create(created);
        showMessage(context, '✓ Yetkazib berish ro‘yxatga qo‘shildi: ${saved.vehicleNumber}');
        _loadDeliveries();
      } catch (e) {
        showMessage(context, 'Xatolik: $e', error: true);
      }
    }
  }

  Future<void> _editDelivery(Delivery delivery) async {
    final repos = context.read<AppRepositories>();
    final updated = await showDialog<Delivery>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryEditDialog(delivery: delivery),
    );
    if (updated != null && mounted) {
      try {
        await repos.deliveries.update(updated);
        showMessage(context, '✓ Yetkazib berish ma’lumotlari yangilandi');
        _loadDeliveries();
      } catch (e) {
        showMessage(context, 'Xatolik: $e', error: true);
      }
    }
  }

  Future<void> _changeStatus(Delivery delivery, String newStatus) async {
    final repos = context.read<AppRepositories>();
    try {
      await repos.deliveries.updateStatus(delivery.id, newStatus);
      String statusTitle = 'holati yangilandi';
      if (newStatus == 'on_the_way') statusTitle = 'yo‘lga chiqdi';
      if (newStatus == 'delivered') statusTitle = 'yetkazildi deb belgilandi';
      if (newStatus == 'cancelled') statusTitle = 'bekor qilindi';
      showMessage(context, '✓ ${delivery.vehicleNumber} $statusTitle');
      _loadDeliveries();
    } catch (e) {
      showMessage(context, 'Xatolik: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDeliveries;
    final totalCount = _deliveries.length;
    final onTheWayCount = _deliveries.where((d) => d.status == 'on_the_way').length;
    final loadingCount = _deliveries.where((d) => d.status == 'loading').length;
    final deliveredCount = _deliveries.where((d) => d.status == 'delivered').length;
    final cancelledCount = _deliveries.where((d) => d.status == 'cancelled').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadDeliveries,
        color: AppColors.neonLime,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. KPI kartochkalari
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DeliveryKpiCard(
                      title: 'Jami Qatnovlar',
                      value: '$totalCount ta',
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF3B82F6),
                      width: cardWidth,
                    ),
                    _DeliveryKpiCard(
                      title: 'Yo‘lda',
                      value: '$onTheWayCount ta',
                      icon: Icons.near_me_rounded,
                      color: const Color(0xFF0284C7),
                      width: cardWidth,
                    ),
                    _DeliveryKpiCard(
                      title: 'Yuklanmoqda',
                      value: '$loadingCount ta',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFF59E0B),
                      width: cardWidth,
                    ),
                    _DeliveryKpiCard(
                      title: 'Yetkazilgan',
                      value: '$deliveredCount ta',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      width: cardWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Qidiruv, Filterlar va Yangi yetkazish tugmasi
            LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth > 880;

                final searchField = SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Mashina raqami, haydovchi, mijoz, manzil yoki tovar...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: context.subtextColor.withOpacity(0.8),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide(
                          color: context.isDark ? AppColors.neonLime : const Color(0xFF3B82F6),
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                );

                final filterCapsule = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: context.isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: context.borderColor.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in [
                          ('Barchasi', 'all', totalCount, null),
                          ('Yo‘lda', 'on_the_way', onTheWayCount, const Color(0xFF0284C7)),
                          ('Yuklanmoqda', 'loading', loadingCount, const Color(0xFFF59E0B)),
                          ('Yetkazildi', 'delivered', deliveredCount, const Color(0xFF10B981)),
                          ('Bekor qilingan', 'cancelled', cancelledCount, const Color(0xFFEF4444)),
                        ])
                          _buildFilterSegment(
                            label: item.$1,
                            code: item.$2,
                            count: item.$3,
                            dotColor: item.$4,
                            isSelected: _statusFilter == item.$2,
                            onTap: () => setState(() => _statusFilter = item.$2),
                          ),
                      ],
                    ),
                  ),
                );

                final newButton = FilledButton.icon(
                  onPressed: () => openNewDeliveryDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yangi Yetkazish', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                    foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 10),
                      filterCapsule,
                      const SizedBox(width: 10),
                      newButton,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        newButton,
                      ],
                    ),
                    const SizedBox(height: 10),
                    filterCapsule,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. Yetkazib berish kartochkalari ro'yxati
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
                      FilledButton(onPressed: _loadDeliveries, child: const Text('Qayta urinish')),
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
                    Icon(Icons.local_shipping_outlined, size: 54, color: context.subtextColor.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'Yetkazib berish yozuvlari topilmadi',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.inkColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Yangi yetkazib berish reysini qo‘shish yoki buyurtmalarni mashinaga yuklash orqali qatnovlarni boshqaring.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: context.subtextColor),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => openNewDeliveryDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('+ Yangi Yetkazish'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final delivery in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeliveryCard(
                    delivery: delivery,
                    onStatusChange: (status) => _changeStatus(delivery, status),
                    onEdit: () => _editDelivery(delivery),
                    onWaybill: () => DeliveryWaybillDialog.show(context, delivery),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSegment({
    required String label,
    required String code,
    required int count,
    required Color? dotColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(context.isDark ? 0.25 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSelected && dotColor != null && count > 0) ...[
              Container(
                width: 6.5,
                height: 6.5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (context.isDark ? AppColors.ink : Colors.white)
                    : (context.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (context.isDark
                        ? AppColors.ink.withOpacity(0.15)
                        : Colors.white.withOpacity(0.2))
                    : (context.isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (context.isDark ? AppColors.ink : Colors.white)
                      : context.inkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryKpiCard extends StatelessWidget {
  const _DeliveryKpiCard({
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

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onStatusChange,
    required this.onEdit,
    required this.onWaybill,
  });

  final Delivery delivery;
  final void Function(String status) onStatusChange;
  final VoidCallback onEdit;
  final VoidCallback onWaybill;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (delivery.status) {
      case 'on_the_way':
        statusColor = const Color(0xFF0284C7);
        statusText = 'Yo‘lda';
        statusIcon = Icons.near_me_rounded;
        break;
      case 'delivered':
        statusColor = const Color(0xFF10B981);
        statusText = 'Yetkazildi';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Bekor qilingan';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Yuklanmoqda';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.borderColor.withOpacity(0.75),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Mashina raqami, Haydovchi, Holat)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Avtomobil Davlat Raqami (Uzbekistan Car Plate Badge)
                _buildCarPlate(context, delivery.vehicleNumber),
                const SizedBox(width: 10),

                // Mashina modeli kapsulasi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: context.borderColor.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_rounded, size: 12, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(
                        delivery.vehicleModel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.inkColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Holat kapsulasi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Sana va vaqt
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: context.subtextColor),
                    const SizedBox(width: 4),
                    Text(
                      formatDateTime(delivery.createdAt),
                      style: TextStyle(fontSize: 11.5, color: context.subtextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Haydovchi va Mijoz ma'lumotlari (Tartibli karta)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Haydovchi
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded, size: 15, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Haydovchi: ${delivery.driverName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: context.inkColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (delivery.driverPhone != null && delivery.driverPhone!.isNotEmpty)
                                    Text(
                                      delivery.driverPhone!,
                                      style: TextStyle(fontSize: 11.5, color: context.subtextColor),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: context.borderColor.withOpacity(0.6)),
                      const SizedBox(width: 12),
                      // Qabul qiluvchi mijoz
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mijoz: ${delivery.recipientName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: context.inkColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    delivery.destinationAddress ?? (delivery.recipientPhone ?? 'Manzil ko‘rsatilmagan'),
                                    style: TextStyle(fontSize: 11.5, color: context.subtextColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (delivery.note != null && delivery.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Divider(height: 10, thickness: 0.5, color: context.borderColor.withOpacity(0.4)),
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Izoh: ${delivery.note}',
                            style: TextStyle(fontSize: 11.5, color: context.inkColor, fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Olib ketilayotgan mahsulotlar (Tartibli jadval)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF181D24) : const Color(0xFFF1F5F9).withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Yuklangan mahsulotlar (${delivery.items.length} xil):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.subtextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (delivery.items.isEmpty)
                  Text(
                    'Mahsulotlar biriktirilmagan',
                    style: TextStyle(fontSize: 12, color: context.subtextColor, fontStyle: FontStyle.italic),
                  )
                else
                  for (int i = 0; i < delivery.items.length; i++) ...[
                    if (i > 0)
                      Divider(height: 10, thickness: 0.5, color: context.borderColor.withOpacity(0.4)),
                    Row(
                      children: [
                        Text(
                          '${i + 1}.',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.subtextColor),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            delivery.items[i].productName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: context.inkColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: context.borderColor.withOpacity(0.6)),
                          ),
                          child: Text(
                            '${delivery.items[i].quantity} ${delivery.items[i].unit}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: context.isDark ? AppColors.neonLime : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Yo'l haqi va Yetkazish vaqtlari
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Yo'l haqi kapsulasi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_outlined, size: 13, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 5),
                      Text(
                        'Yo‘l haqi: ${money(delivery.deliveryFee)} (${delivery.feePayerLabel})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (delivery.dispatchTime != null) ...[
                  Text(
                    'Jo‘nadi: ${formatDateTime(delivery.dispatchTime!)}',
                    style: TextStyle(fontSize: 11, color: context.subtextColor),
                  ),
                ],
                if (delivery.deliveredTime != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Yetdi: ${formatDateTime(delivery.deliveredTime!)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.borderColor.withOpacity(0.6)),

          // 5. Harakat tugmalari (Burchaksiz kapsulalar)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Yo'l varaqasi (Nakladnoy / Waybill)
                OutlinedButton.icon(
                  onPressed: onWaybill,
                  icon: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: const Text('Yo‘l varaqasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.inkColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Tahrirlash
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Tahrirlash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.inkColor,
                    side: BorderSide(color: context.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Holat bo'yicha tezkor amallar:
                if (delivery.isLoading) ...[
                  // Bekor qilish
                  OutlinedButton.icon(
                    onPressed: () => onStatusChange('cancelled'),
                    icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFEF4444)),
                    label: const Text('Bekor qilish', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  // Yo'lga chiqdi
                  FilledButton.icon(
                    onPressed: () => onStatusChange('on_the_way'),
                    icon: const Icon(Icons.local_shipping_rounded, size: 15),
                    label: const Text('Yo‘lga chiqdi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ] else if (delivery.isOnTheWay) ...[
                  // Yetkazildi
                  FilledButton.icon(
                    onPressed: () => onStatusChange('delivered'),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('Yetkazildi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
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

  Widget _buildCarPlate(BuildContext context, String plate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.isDark ? const Color(0xFF64748B) : const Color(0xFF0F172A),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'UZ',
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            plate,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: context.inkColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yangi yetkazish yaratish yoki tahrirlash dialogi
class DeliveryEditDialog extends StatefulWidget {
  const DeliveryEditDialog({
    super.key,
    this.delivery,
    this.saleId,
    this.initialRecipientName,
    this.initialRecipientPhone,
    this.initialAddress,
    this.initialItems,
  });

  final Delivery? delivery;
  final int? saleId;
  final String? initialRecipientName;
  final String? initialRecipientPhone;
  final String? initialAddress;
  final List<DeliveryItem>? initialItems;

  @override
  State<DeliveryEditDialog> createState() => _DeliveryEditDialogState();
}

class _DeliveryEditDialogState extends State<DeliveryEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _vehicleNumberCtrl;
  late TextEditingController _driverNameCtrl;
  late TextEditingController _driverPhoneCtrl;
  late TextEditingController _recipientNameCtrl;
  late TextEditingController _recipientPhoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _deliveryFeeCtrl;
  late TextEditingController _noteCtrl;

  String _vehicleModel = 'Labo';
  String _feePayer = 'customer';
  String _status = 'loading';

  List<({String name, double quantity, String unit})> _items = [];

  final _prodNameCtrl = TextEditingController();
  final _prodQtyCtrl = TextEditingController(text: '1.0');
  String _prodUnit = 'dona';

  @override
  void initState() {
    super.initState();
    final d = widget.delivery;
    _vehicleNumberCtrl = TextEditingController(text: d?.vehicleNumber ?? '');
    _vehicleModel = d?.vehicleModel ?? 'Labo';
    _driverNameCtrl = TextEditingController(text: d?.driverName ?? '');
    _driverPhoneCtrl = TextEditingController(text: d?.driverPhone ?? '');
    _recipientNameCtrl = TextEditingController(text: d?.recipientName ?? widget.initialRecipientName ?? '');
    _recipientPhoneCtrl = TextEditingController(text: d?.recipientPhone ?? widget.initialRecipientPhone ?? '');
    _addressCtrl = TextEditingController(text: d?.destinationAddress ?? widget.initialAddress ?? '');
    _deliveryFeeCtrl = TextEditingController(text: d != null ? d.deliveryFee.toInt().toString() : '0');
    _feePayer = d?.feePayer ?? 'customer';
    _status = d?.status ?? 'loading';
    _noteCtrl = TextEditingController(text: d?.note ?? '');

    if (d != null) {
      _items = d.items.map((i) => (name: i.productName, quantity: i.quantity, unit: i.unit)).toList();
    } else if (widget.initialItems != null) {
      _items = widget.initialItems!.map((i) => (name: i.productName, quantity: i.quantity, unit: i.unit)).toList();
    }
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _noteCtrl.dispose();
    _prodNameCtrl.dispose();
    _prodQtyCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _prodNameCtrl.text.trim();
    final qty = double.tryParse(_prodQtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty <= 0) {
      showMessage(context, 'Tovar nomi va miqdorini to‘g‘ri kiriting', error: true);
      return;
    }
    setState(() {
      _items.add((name: name, quantity: qty, unit: _prodUnit));
      _prodNameCtrl.clear();
      _prodQtyCtrl.text = '1.0';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.delivery != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.cardBg,
      child: Container(
        width: 620,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog sarlavhasi
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Yetkazib berishni tahrirlash' : 'Yangi Yetkazib berish (Mashinaga yuklash)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.inkColor),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Form maydonlari (Scrollable)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Mashina ma'lumotlari
                    Text('Avtotransport ma’lumotlari', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.subtextColor)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Mashina raqami
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _vehicleNumberCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Mashina raqami *',
                              hintText: '01 A 777 AA',
                              prefixIcon: Icon(Icons.pin_rounded, size: 18),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Mashina raqami shart' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Mashina turi
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _vehicleModel,
                            decoration: const InputDecoration(labelText: 'Turi', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'Labo', child: Text('Labo')),
                              DropdownMenuItem(value: 'Gazel', child: Text('Gazel')),
                              DropdownMenuItem(value: 'Isuzu', child: Text('Isuzu')),
                              DropdownMenuItem(value: 'Kamaz', child: Text('Kamaz')),
                              DropdownMenuItem(value: 'Damas', child: Text('Damas')),
                              DropdownMenuItem(value: 'Boshqa', child: Text('Boshqa')),
                            ],
                            onChanged: (v) => setState(() => _vehicleModel = v ?? 'Labo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Haydovchi
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _driverNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Haydovchi ismi *',
                              hintText: 'Farhod Haydovchi',
                              prefixIcon: Icon(Icons.badge_rounded, size: 18),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Haydovchi ismi shart' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _driverPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Haydovchi telefoni',
                              hintText: '+998 90 ...',
                              prefixIcon: Icon(Icons.phone_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Qabul qiluvchi mijoz va manzil
                    Text('Qabul qiluvchi mijoz va Manzil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.subtextColor)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _recipientNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mijoz ismi *',
                              hintText: 'Akmal aka',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                              isDense: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Mijoz ismi shart' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _recipientPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mijoz telefoni',
                              hintText: '+998 93 ...',
                              prefixIcon: Icon(Icons.phone_iphone_rounded, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Yetkazib berish manzili / Lokatsiya',
                        hintText: 'Toshkent sh., Chilonzor 9-mavze, 14-uy',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Yuklanayotgan mahsulotlar ro'yxati
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Yuklangan mahsulotlar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.subtextColor)),
                        Text('${_items.length} ta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.inkColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Yangi tovar qo'shish qatori
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _prodNameCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Mahsulot nomi...',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _prodQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'Miqdori',
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _prodUnit,
                            underline: const SizedBox(),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'dona', child: Text('dona')),
                              DropdownMenuItem(value: 'm2', child: Text('m²')),
                              DropdownMenuItem(value: 'metr', child: Text('metr')),
                              DropdownMenuItem(value: 'qop', child: Text('qop')),
                              DropdownMenuItem(value: 'kg', child: Text('kg')),
                            ],
                            onChanged: (v) => setState(() => _prodUnit = v ?? 'dona'),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.add_circle_rounded, color: AppColors.green),
                            onPressed: _addItem,
                            tooltip: 'Qo‘shish',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Qo'shilgan tovarlar
                    if (_items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.borderColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _items.length; i++)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${i + 1}. ${_items[i].name}',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.inkColor),
                                    ),
                                  ),
                                  Text(
                                    '${_items[i].quantity} ${_items[i].unit}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.inkColor),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                    onPressed: () => setState(() => _items.removeAt(i)),
                                    splashRadius: 16,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Yo'l haqi va Holat
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _deliveryFeeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Yo‘l haqi summasi',
                              suffixText: 'so‘m',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _feePayer,
                            decoration: const InputDecoration(labelText: 'To‘lovchi', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'customer', child: Text('Mijoz to‘laydi')),
                              DropdownMenuItem(value: 'store', child: Text('Do‘kon hisobidan')),
                              DropdownMenuItem(value: 'included', child: Text('Narx ichida')),
                            ],
                            onChanged: (v) => setState(() => _feePayer = v ?? 'customer'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Holat va Izoh
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: const InputDecoration(labelText: 'Holat', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'loading', child: Text('Yuklanmoqda')),
                              DropdownMenuItem(value: 'on_the_way', child: Text('Yo‘lda')),
                              DropdownMenuItem(value: 'delivered', child: Text('Yetkazildi')),
                              DropdownMenuItem(value: 'cancelled', child: Text('Bekor qilingan')),
                            ],
                            onChanged: (v) => setState(() => _status = v ?? 'loading'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Izoh / Qo‘shimcha',
                              hintText: 'Qurilish joyi, topshirish...',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Harakat tugmalari
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Bekor qilish'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                      foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      final fee = double.tryParse(_deliveryFeeCtrl.text.replaceAll(' ', '')) ?? 0;
                      final deliveryItems = _items
                          .map((i) => DeliveryItem(productName: i.name, quantity: i.quantity, unit: i.unit))
                          .toList();

                      final d = Delivery(
                        id: widget.delivery?.id ?? 0,
                        saleId: widget.delivery?.saleId ?? widget.saleId,
                        vehicleNumber: _vehicleNumberCtrl.text.trim().toUpperCase(),
                        vehicleModel: _vehicleModel,
                        driverName: _driverNameCtrl.text.trim(),
                        driverPhone: _driverPhoneCtrl.text.trim().isEmpty ? null : _driverPhoneCtrl.text.trim(),
                        recipientName: _recipientNameCtrl.text.trim(),
                        recipientPhone: _recipientPhoneCtrl.text.trim().isEmpty ? null : _recipientPhoneCtrl.text.trim(),
                        destinationAddress: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                        deliveryFee: fee,
                        feePayer: _feePayer,
                        status: _status,
                        dispatchTime: widget.delivery?.dispatchTime ?? (_status == 'on_the_way' ? DateTime.now() : null),
                        deliveredTime: widget.delivery?.deliveredTime ?? (_status == 'delivered' ? DateTime.now() : null),
                        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                        createdAt: widget.delivery?.createdAt ?? DateTime.now(),
                        items: deliveryItems,
                      );
                      Navigator.pop(context, d);
                    },
                    child: Text(isEdit ? 'Saqlash' : 'Ro‘yxatga olish', style: const TextStyle(fontWeight: FontWeight.w800)),
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

/// Yo'l varaqasi (Delivery Waybill / Nakladnoy) chop etish va ko'rish dialogi
class DeliveryWaybillDialog extends StatelessWidget {
  const DeliveryWaybillDialog({super.key, required this.delivery});

  final Delivery delivery;

  static Future<void> show(BuildContext context, Delivery delivery) {
    return showDialog(
      context: context,
      builder: (_) => DeliveryWaybillDialog(delivery: delivery),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sarlavha va Yopish
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'YUK XATI / YO‘L VARAQASI',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A), letterSpacing: 0.8),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF0F172A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF0F172A), thickness: 1.5),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Kompaniya rekviziti
                  const Center(
                    child: Column(
                      children: [
                        Text('STONEX ERP · MARMAR VA GRANIT MARKAZI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Tovarlarni avtotransport orqali yetkazib berish hujjati', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hujjat raqami va sana
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reys raqami: #${delivery.id}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('Sana: ${formatDateTime(delivery.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mashina va Haydovchi bloki
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Mashina:', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(width: 6),
                            Text('${delivery.vehicleModel} (${delivery.vehicleNumber})', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            const Spacer(),
                            const Text('Haydovchi:', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(width: 6),
                            Text(delivery.driverName, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          ],
                        ),
                        if (delivery.driverPhone != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('Tel: ${delivery.driverPhone}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Qabul qiluvchi mijoz va manzil
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Qabul qiluvchi: ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            Text(delivery.recipientName, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            if (delivery.recipientPhone != null)
                              Text(' (${delivery.recipientPhone})', style: const TextStyle(color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Yetkazish manzili: ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            Expanded(
                              child: Text(
                                delivery.destinationAddress ?? 'Ko‘rsatilmagan',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tovarlar jadvali
                  const Text('Yuklangan tovarlar ro‘yxati:', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Table(
                    border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 1),
                    columnWidths: const {
                      0: FixedColumnWidth(36),
                      1: FlexColumnWidth(4),
                      2: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: const [
                          Padding(padding: EdgeInsets.all(6), child: Text('№', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Mahsulot nomi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Miqdori', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                        ],
                      ),
                      for (int i = 0; i < delivery.items.length; i++)
                        TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(delivery.items[i].productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text('${delivery.items[i].quantity} ${delivery.items[i].unit}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Yo'l haqi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Yo‘l haqi / Yetkazish narxi:', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                      Text('${money(delivery.deliveryFee)} (${delivery.feePayerLabel})', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Imzolar bloki
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Yukni topshirdi (Haydovchi):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            SizedBox(height: 24),
                            Divider(color: Color(0xFF94A3B8)),
                            Text('Imzo: _______________', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Yukni qabul qildi (Mijoz):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            SizedBox(height: 24),
                            Divider(color: Color(0xFF94A3B8)),
                            Text('Imzo: _______________', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 20),

            // Tugmalar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'YUK XATI #${delivery.id}\n'
                          'Mashina: ${delivery.vehicleModel} ${delivery.vehicleNumber}\n'
                          'Haydovchi: ${delivery.driverName} (${delivery.driverPhone ?? ""})\n'
                          'Mijoz: ${delivery.recipientName} (${delivery.recipientPhone ?? ""})\n'
                          'Manzil: ${delivery.destinationAddress ?? ""}\n'
                          'Tovarlar: ${delivery.items.map((i) => "${i.productName} - ${i.quantity} ${i.unit}").join(", ")}\n'
                          'Yo‘l haqi: ${money(delivery.deliveryFee)}',
                    ));
                    showMessage(context, '✓ Hujjat ma’lumotlari nusxalandi');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Nusxa olish'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    showMessage(context, '✓ Yo‘l varaqasi printerga yuborildi');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text('Chop etish'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
