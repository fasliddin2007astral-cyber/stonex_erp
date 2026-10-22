import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  late Future<List<Customer>> _future;
  String _selectedFilter = 'Barchasi'; // 'Barchasi', 'Qarzdorlar', 'Faol xaridorlar'

  CustomerRepository get _repo => context.read<AppRepositories>().customers;

  @override
  void initState() {
    super.initState();
    _future = _repo.listCustomers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _repo.listCustomers();
    });
  }

  Future<void> _openCustomerDialog([Customer? customer]) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerDialog(customer: customer),
    );
    if (updated == true) {
      _reload();
    }
  }

  Future<void> _openCustomerDetails(Customer customer) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CustomerDetailsDialog(
        customer: customer,
        onEdit: () {
          Navigator.pop(context);
          _openCustomerDialog(customer);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 14, 4, wide ? 28 : 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Yuqori qidiruv va yangi mijoz qo'shish paneli
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(fontSize: 13, color: context.inkColor, fontWeight: FontWeight.w500),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.cardColor,
                      isDense: true,
                      hintText: 'Mijoz ismi, telefoni yoki pasporti bo‘yicha qidirish...',
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: context.isDark ? AppColors.neonLime : AppColors.ink, width: 1.5)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: () => _openCustomerDialog(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(wide ? 'Yangi Mijoz' : '+', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
                    foregroundColor: context.isDark ? AppColors.ink : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filter chiplari
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Barchasi', 'Qarzdorlar', 'Faol xaridorlar'].map((cat) {
                final sel = _selectedFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat,
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
                    onSelected: (_) => setState(() => _selectedFilter = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Asosiy ro'yxat
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString(), onRetry: _reload);
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var list = snap.data!;

                // Qidiruv filtri
                final q = _searchCtrl.text.trim().toLowerCase();
                if (q.isNotEmpty) {
                  list = list.where((c) {
                    final n = c.name.toLowerCase();
                    final p = (c.phone ?? '').toLowerCase();
                    final pass = (c.passport ?? '').toLowerCase();
                    return n.contains(q) || p.contains(q) || pass.contains(q);
                  }).toList();
                }

                // Kategoriya filtri
                if (_selectedFilter == 'Qarzdorlar') {
                  list = list.where((c) => c.totalDebt > 0.5).toList();
                } else if (_selectedFilter == 'Faol xaridorlar') {
                  list = list.where((c) => c.salesCount > 0).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 54, color: context.mutedColor),
                          const SizedBox(height: 12),
                          Text(
                            q.isNotEmpty ? 'Mijoz topilmadi' : 'Hozircha mijozlar ro‘yxati bo‘sh',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.inkColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            q.isNotEmpty ? 'Boshqa ism, telefon yoki pasport bilan qidiring' : 'Yangi savdo paytida yoki "+ Yangi Mijoz" tugmasi orqali qo‘shing',
                            style: TextStyle(color: context.mutedColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Statistika hisoblash
                final totalDebtSum = list.fold<double>(0, (sum, c) => sum + c.totalDebt);
                final totalSpentSum = list.fold<double>(0, (sum, c) => sum + c.totalSpent);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Statistika paneli
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatMini(
                              label: 'Jami mijozlar',
                              value: '${list.length} nafar',
                              color: context.inkColor,
                            ),
                          ),
                          Container(width: 1, height: 28, color: context.borderColor),
                          Expanded(
                            child: _StatMini(
                              label: 'Umumiy xarid',
                              value: money(totalSpentSum),
                              color: AppColors.green,
                            ),
                          ),
                          Container(width: 1, height: 28, color: context.borderColor),
                          Expanded(
                            child: _StatMini(
                              label: 'Umumiy nasiya',
                              value: money(totalDebtSum),
                              color: totalDebtSum > 0 ? AppColors.danger : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mijozlar kartalari
                    Expanded(
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final hasDebt = c.totalDebt > 0.5;

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openCustomerDetails(c),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: hasDebt ? AppColors.danger.withValues(alpha: 0.3) : context.borderColor),
                              ),
                              child: Row(
                                children: [
                                  // Mijoz / Pasport rasmi
                                  GestureDetector(
                                    onTap: (c.photoUrl != null && c.photoUrl!.isNotEmpty)
                                        ? () => showProductImagePreview(
                                              context,
                                              imageUrl: c.photoUrl,
                                              name: c.name,
                                              subtitle: 'Pasport: ${c.passport ?? 'Kiritilmagan'} • Telefon: ${c.phone ?? 'Yo‘q'}',
                                            )
                                        : null,
                                    child: ProductThumbnail(
                                      imageUrl: c.photoUrl,
                                      name: c.name,
                                      size: 54,
                                      borderRadius: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Ismi, telefoni, pasporti
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.name,
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.inkColor),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (c.passport != null && c.passport!.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: context.isDark ? const Color(0xFF21262D) : const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: context.isDark ? AppColors.border : const Color(0xFFBFDBFE)),
                                                ),
                                                child: Text(
                                                  c.passport!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: context.isDark ? Colors.white : const Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 13, color: context.mutedColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.phone?.isNotEmpty == true ? c.phone! : 'Telefon kiritilmagan',
                                              style: TextStyle(fontSize: 12, color: context.mutedColor),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.receipt_long_outlined, size: 13, color: context.mutedColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${c.salesCount} ta savdo',
                                              style: TextStyle(fontSize: 12, color: context.mutedColor),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              'Xarid: ${money(c.totalSpent)}',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.inkColor),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: hasDebt ? const Color(0xFFFCE4E3) : AppColors.greenSoft,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                hasDebt ? 'Nasiya: ${money(c.totalDebt)}' : 'Qarzi yo‘q',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: hasDebt ? AppColors.danger : AppColors.darkCard,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tahrirlash tugmasi
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    color: context.mutedColor,
                                    tooltip: 'Tahrirlash',
                                    onPressed: () => _openCustomerDialog(c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mijoz ma'lumotlarini to'liq ko'rish dialogi
// ---------------------------------------------------------------------------

class _CustomerDetailsDialog extends StatelessWidget {
  const _CustomerDetailsDialog({required this.customer, required this.onEdit});
  final Customer customer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final hasDebt = c.totalDebt > 0.5;

    return Dialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yuqori sarlavha va yopish
              Row(
                children: [
                  const Text('Mijoz profili', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Rasm va Ism
              Row(
                children: [
                  GestureDetector(
                    onTap: (c.photoUrl != null && c.photoUrl!.isNotEmpty)
                        ? () => showProductImagePreview(
                              context,
                              imageUrl: c.photoUrl,
                              name: c.name,
                              subtitle: 'Pasport: ${c.passport ?? 'Yo‘q'}',
                            )
                        : null,
                    child: ProductThumbnail(
                      imageUrl: c.photoUrl,
                      name: c.name,
                      size: 74,
                      borderRadius: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.inkColor),
                        ),
                        const SizedBox(height: 4),
                        if (c.phone != null && c.phone!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(c.phone!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        if (c.passport != null && c.passport!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text('Pasport: ${c.passport!}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Moliyaviy xulosa
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.isDark ? const Color(0xFF1E2822) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Jami xarid', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(height: 3),
                        Text(money(c.totalSpent), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.inkColor)),
                      ],
                    ),
                    Container(width: 1, height: 28, color: context.borderColor),
                    Column(
                      children: [
                        const Text('Nasiya / Qarz', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(height: 3),
                        Text(
                          money(c.totalDebt),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: hasDebt ? AppColors.danger : AppColors.green),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 28, color: context.borderColor),
                    Column(
                      children: [
                        const Text('Savdolar soni', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(height: 3),
                        Text('${c.salesCount} ta', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.inkColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Harakat tugmalari
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Tahrirlash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Yopish'),
                    ),
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

// ---------------------------------------------------------------------------
// Mijoz yaratish / tahrirlash dialogi
// ---------------------------------------------------------------------------

class CustomerDialog extends StatefulWidget {
  const CustomerDialog({super.key, this.customer});
  final Customer? customer;

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
  late final _passportCtrl = TextEditingController(text: widget.customer?.passport ?? '');
  String? _photoUrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.customer?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passportCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final custRepo = context.read<AppRepositories>().customers;
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 82);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

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

      // Agar serverda upload mavjud bo'lsa
      try {
        final filename = picked.name.isNotEmpty ? picked.name : 'customer_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final uploaded = await custRepo.uploadCustomerImage(bytes, filename);
        if (uploaded.isNotEmpty) {
          finalUrl = uploaded;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _photoUrl = finalUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Rasm tanlashda xatolik: $e');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = context.read<AppRepositories>().customers;
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final passport = _passportCtrl.text.trim();

      if (widget.customer == null) {
        // Yangi mijoz
        await repo.createCustomer(
          Customer(
            id: 0,
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            passport: passport.isNotEmpty ? passport : null,
            photoUrl: _photoUrl,
          ),
        );
      } else {
        // Tahrirlash
        await repo.updateCustomer(
          widget.customer!.copyWith(
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            passport: passport.isNotEmpty ? passport : null,
            photoUrl: _photoUrl,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;

    return Dialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      isEdit ? 'Mijozni tahrirlash' : 'Yangi mijoz qo‘shish',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fotosurat qismi
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Stack(
                          children: [
                            ProductThumbnail(
                              imageUrl: _photoUrl,
                              name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Mijoz',
                              size: 88,
                              borderRadius: 22,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.darkCard,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_rounded, size: 16),
                            label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Galereya', style: TextStyle(fontSize: 12)),
                          ),
                          if (_photoUrl != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => setState(() => _photoUrl = null),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                              tooltip: 'Rasmni o‘chirish',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Ismi
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ism va Familiya *',
                    hintText: 'Masalan: Rustam Karimov',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ism kiritilishi shart' : null,
                ),
                const SizedBox(height: 12),

                // Telefon
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon raqami',
                    hintText: '+998 90 123 45 67',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Pasport
                TextFormField(
                  controller: _passportCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Pasport seriya va raqami',
                    hintText: 'AA 1234567',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('Bekor'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isEdit ? 'Saqlash' : 'Qo‘shish', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
