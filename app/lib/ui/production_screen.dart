import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/auth_controller.dart';
import 'common.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  late Future<List<ProductionTask>> _future;
  String _selectedFilter = 'Barchasi';

  ProductionRepository get _repo => context.read<AppRepositories>().production;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  void _reload() {
    if (!mounted) return;
    final nextFuture = _repo.list();
    setState(() {
      _future = nextFuture;
    });
  }

  Future<void> _report(ProductionTask t) async {
    final remaining = (t.planned - t.produced).clamp(0, double.infinity).toDouble();
    final ctrl = TextEditingController(text: qty(remaining > 0 ? remaining : 1));
    String? error;
    bool busy = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            '${t.productName}: Ish hisoboti',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.muted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reja: ${qty(t.planned)} ${t.unit}  ·  Bajarilgan: ${qty(t.produced)} ${t.unit}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Yangi ishlab chiqarilgan miqdor (${t.unit})',
                  ),
                  onChanged: (_) => setS(() {
                    error = null;
                  }),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (remaining > 0)
                      ActionChip(
                        label: Text('Qoldiqni yakunlash (${qty(remaining)})'),
                        onPressed: () => setS(() {
                          ctrl.text = qty(remaining);
                        }),
                      ),
                    ActionChip(
                      label: const Text('+1 dona/m²'),
                      onPressed: () => setS(() {
                        final cur = parseInput(ctrl.text) ?? 0;
                        ctrl.text = qty(cur + 1);
                      }),
                    ),
                    ActionChip(
                      label: const Text('+5'),
                      onPressed: () => setS(() {
                        final cur = parseInput(ctrl.text) ?? 0;
                        ctrl.text = qty(cur + 5);
                      }),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
              ],
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
                      final v = parseInput(ctrl.text);
                      if (v == null || v <= 0) {
                        setS(() {
                          error = 'Miqdorni to‘g‘ri kiriting';
                        });
                        return;
                      }
                      setS(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await _repo.report(t.id, v);
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
                  : const Text('Yuborish'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (ok == true && mounted) {
      showMessage(context, 'Bajarilgan ish omborga kirim qilindi');
      _reload();
    }
  }

  Future<void> _create() async {
    final repos = context.read<AppRepositories>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TaskCreateDialog(
        productionRepo: repos.production,
        productRepo: repos.products,
      ),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Topshiriq muvaffaqiyatli biriktirildi');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthController>().user?.role == Role.admin;
    final filters = ['Barchasi', 'Jarayonda', 'Yakunlangan'];

    return Scaffold(
      backgroundColor: AppColors.panel,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.neonLime),
              label: const Text('Yangi topshiriq'),
            )
          : null,
      body: FutureBuilder<List<ProductionTask>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: _reload);
          }

          final allTasks = snap.data ?? [];
          var displayTasks = List<ProductionTask>.from(allTasks);

          if (_selectedFilter == 'Jarayonda') {
            displayTasks = displayTasks.where((t) => t.status != 'done').toList();
          } else if (_selectedFilter == 'Yakunlangan') {
            displayTasks = displayTasks.where((t) => t.status == 'done').toList();
          }

          final total = allTasks.length;
          final inProgress = allTasks.where((t) => t.status != 'done').length;
          final done = allTasks.where((t) => t.status == 'done').length;
          final totalPlanned = allTasks.fold<double>(0, (a, b) => a + b.planned);
          final totalProduced = allTasks.fold<double>(0, (a, b) => a + b.produced);
          final completionRate = totalPlanned > 0 ? (totalProduced / totalPlanned * 100).clamp(0, 100) : 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 720;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                  children: [
                    // Yuqori statistika paneli
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStat(
                              'Jami Topshiriqlar',
                              '$total ta',
                              Icons.precision_manufacturing_rounded,
                              AppColors.neonLime,
                              true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Jarayondagi Ishlar',
                              '$inProgress ta',
                              Icons.pending_actions_rounded,
                              const Color(0xFFC77700),
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Bajarilgan Ishlar',
                              '$done ta',
                              Icons.check_circle_rounded,
                              AppColors.green,
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Umumiy Ish Quvvati',
                              '${completionRate.toStringAsFixed(1)}%',
                              Icons.speed_rounded,
                              const Color(0xFF3B82F6),
                              false,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildStat('Jami Topshiriqlar', '$total ta', Icons.precision_manufacturing_rounded, AppColors.neonLime, true),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildStat('Jarayonda', '$inProgress ta', Icons.pending_actions_rounded, const Color(0xFFC77700), false)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStat('Yakunlandi', '$done ta', Icons.check_circle_rounded, AppColors.green, false)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Filtrlar va Boshqaruv
                    Row(
                      children: [
                        for (final f in filters) ...[
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedFilter = f;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const Spacer(),
                        if (isAdmin)
                          FilledButton.icon(
                            onPressed: _create,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.darkCard,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.add, size: 18, color: AppColors.neonLime),
                            label: const Text('Topshiriq', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Topshiriqlar ro'yxati
                    if (displayTasks.isEmpty)
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
                              Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.muted),
                              SizedBox(height: 12),
                              Text('Topshiriqlar mavjud emas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = displayTasks[i];
                          final isDone = t.status == 'done';
                          final progress = (t.planned > 0 ? (t.produced / t.planned) : 0.0).clamp(0.0, 1.0);
                          final percent = (progress * 100).toStringAsFixed(0);

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: isDesktop
                                ? Row(
                                    children: [
                                      // Icon badge
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDone ? AppColors.greenSoft : AppColors.neonLimeSoft,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isDone ? Icons.check_circle_rounded : Icons.precision_manufacturing_rounded,
                                          color: isDone ? AppColors.green : AppColors.ink,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Mahsulot va Ishchi
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.productName,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.muted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Ishchi: ${t.workerName}',
                                                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Progress bari va miqdor
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${qty(t.produced)} / ${qty(t.planned)} ${t.unit}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                ),
                                                Text(
                                                  '$percent%',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12,
                                                    color: isDone ? AppColors.green : AppColors.ink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 7,
                                                backgroundColor: AppColors.panel,
                                                color: isDone ? AppColors.green : AppColors.neonLime,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Status va Hisobot tugmasi
                                      if (isDone)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.greenSoft,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text('Yakunlandi',
                                              style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 11)),
                                        )
                                      else
                                        FilledButton.icon(
                                          onPressed: () => _report(t),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.darkCard,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.add_task_rounded, size: 16, color: AppColors.neonLime),
                                          label: const Text('Hisobot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                        ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isDone ? AppColors.greenSoft : AppColors.neonLimeSoft,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isDone ? Icons.check_circle_rounded : Icons.precision_manufacturing_rounded,
                                              color: isDone ? AppColors.green : AppColors.ink,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  t.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Ishchi: ${t.workerName}',
                                                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isDone)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: AppColors.greenSoft,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text('Yakunlandi',
                                                  style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 11)),
                                            )
                                          else
                                            FilledButton.icon(
                                              onPressed: () => _report(t),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: AppColors.darkCard,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.add_task_rounded, size: 15, color: AppColors.neonLime),
                                              label: const Text('Hisobot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${qty(t.produced)} / ${qty(t.planned)} ${t.unit}',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                          Text(
                                            '$percent%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: isDone ? AppColors.green : AppColors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 7,
                                          backgroundColor: AppColors.panel,
                                          color: isDone ? AppColors.green : AppColors.neonLime,
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
// Ishlab chiqarish topshirig'ini yaratish dialogi (Vault uslubida)
// ---------------------------------------------------------------------------

class TaskCreateDialog extends StatefulWidget {
  const TaskCreateDialog({super.key, required this.productionRepo, required this.productRepo});
  final ProductionRepository productionRepo;
  final ProductRepository productRepo;

  @override
  State<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<TaskCreateDialog> {
  late Future<({List<Product> products, List<AppUser> workers})> _loadFuture;
  int? _selectedProductId;
  int? _selectedWorkerId;
  final _planCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<({List<Product> products, List<AppUser> workers})> _loadData() async {
    final p = await widget.productRepo.list();
    var w = await widget.productionRepo.workers();
    if (w.isEmpty && mounted) {
      // Fallback: Agar maxsus ishchi topilmasa, tizimdagi faol xodimlarni olamiz
      final all = await context.read<AppRepositories>().users.list();
      w = all.where((u) => u.isActive).toList();
    }
    if (p.isNotEmpty) _selectedProductId = p.first.id;
    if (w.isNotEmpty) _selectedWorkerId = w.first.id;
    return (products: p, workers: w);
  }

  @override
  void dispose() {
    _planCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedProductId == null || _selectedWorkerId == null) {
      setState(() {
        _error = 'Mahsulot va ishchini tanlang';
      });
      return;
    }
    final planned = parseInput(_planCtrl.text);
    if (planned == null || planned <= 0) {
      setState(() {
        _error = 'Reja miqdorini to‘g‘ri kiriting';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.productionRepo.create(
        productId: _selectedProductId!,
        workerId: _selectedWorkerId!,
        plannedQty: planned,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<Product> products, List<AppUser> workers})>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final products = snap.data!.products;
        final workers = snap.data!.workers;

        if (products.isEmpty) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Mahsulotlar mavjud emas'),
            content: const Text('Topshiriq berish uchun avval "Mahsulotlar" bo‘limidan mahsulot qo‘shing.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
            ],
          );
        }

        if (workers.isEmpty) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Xodimlar mavjud emas'),
            content: const Text('Topshiriq biriktirish uchun "Xodimlar" bo‘limidan ishchi qo‘shing.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
            ],
          );
        }

        _selectedProductId ??= products.first.id;
        _selectedWorkerId ??= workers.first.id;

        final selProd = products.where((p) => p.id == _selectedProductId).firstOrNull ?? products.first;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Yangi Ishlab Chiqarish Topshirig‘i', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Ishlab chiqariladigan mahsulot'),
                    items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name))],
                    onChanged: (v) {
                      setState(() {
                        _selectedProductId = v;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedWorkerId,
                    decoration: const InputDecoration(labelText: 'Biriktirilgan ishchi'),
                    items: [for (final w in workers) DropdownMenuItem(value: w.id, child: Text(w.fullName))],
                    onChanged: (v) {
                      setState(() {
                        _selectedWorkerId = v;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _planCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Rejadagi miqdor (${selProd.unit})',
                      hintText: 'masalan: 120',
                    ),
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
                  : const Text('Topshiriq berish', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}

