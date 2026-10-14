import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _search = TextEditingController();
  late Future<List<SaleResult>> _future;

  SalesRepository get _repo => context.read<AppRepositories>().sales;

  @override
  void initState() {
    super.initState();
    _future = _repo.listDebts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final f = _repo.listDebts();
    if (mounted) {
      setState(() {
        _future = f;
      });
    }
    await f;
  }

  Future<void> _pay(SaleResult sale) async {
    final ctrl = TextEditingController(text: sale.debt.round().toString());
    String method = 'cash';
    String? error;
    bool busy = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            'Qarz to‘lovi: ${sale.customerName ?? 'Savdo #${sale.id}'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                    color: const Color(0xFFFFF1DC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_rounded, color: Color(0xFFC77700)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Qoldiq qarz', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          Text(
                            money(sale.debt),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFC77700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'To‘lanayotgan summa'),
                  onChanged: (_) {
                    setS(() {
                      error = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('To‘liq yopish'),
                      onPressed: () {
                        setS(() {
                          ctrl.text = sale.debt.round().toString();
                          error = null;
                        });
                      },
                    ),
                    if (sale.debt > 100000)
                      ActionChip(
                        label: Text(money(sale.debt / 2)),
                        onPressed: () {
                          setS(() {
                            ctrl.text = (sale.debt / 2).round().toString();
                            error = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'To‘lov usuli'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Naqd pul')),
                    DropdownMenuItem(value: 'card', child: Text('Bank kartasi')),
                    DropdownMenuItem(value: 'transfer', child: Text('O‘tkazma')),
                  ],
                  onChanged: (v) {
                    setS(() {
                      method = v ?? 'cash';
                    });
                  },
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
                      final val = parseInput(ctrl.text);
                      if (val == null || val <= 0) {
                        setS(() {
                          error = 'To‘lov summasini to‘g‘ri kiriting';
                        });
                        return;
                      }
                      if (val > sale.debt + 0.01) {
                        setS(() {
                          error = 'To‘lov qarzdan ko‘p bo‘lishi mumkin emas';
                        });
                        return;
                      }
                      setS(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await _repo.payDebt(sale.id, val, method: method);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setS(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Qabul qilish'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (ok == true && mounted) {
      showMessage(context, 'Qarz to‘lovi muvaffaqiyatli saqlandi');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Mijoz ismi yoki telefoni bo‘yicha qidirish...',
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaleResult>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return ErrorView(message: snap.error.toString(), onRetry: _reload);
                }
                var list = snap.data ?? [];
                final q = _search.text.trim().toLowerCase();
                if (q.isNotEmpty) {
                  list = list.where((s) {
                    final name = (s.customerName ?? '').toLowerCase();
                    final phone = (s.customerPhone ?? '').toLowerCase();
                    return name.contains(q) || phone.contains(q);
                  }).toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.green, size: 36),
                        ),
                        const SizedBox(height: 14),
                        const Text('Qarzdorliklar yo‘q', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Barcha nasiyalar to‘liq to‘langan yoki topilmadi', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  );
                }

                final totalDebt = list.fold<double>(0, (a, b) => a + b.debt);

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D3A2B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.pending_actions_rounded, color: AppColors.greenBright, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Jami undirilishi kerak bo‘lgan nasiyalar',
                                    style: TextStyle(color: Color(0xFFA9BDB0), fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  money(totalDebt),
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D3A2B),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${list.length} ta nasiya',
                                style: const TextStyle(color: AppColors.greenBright, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final s in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFFFF1DC),
                                  child: Text(
                                    s.customerName != null && s.customerName!.isNotEmpty
                                        ? s.customerName![0].toUpperCase()
                                        : '#',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFC77700),
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            s.customerName?.isNotEmpty == true ? s.customerName! : 'Nomsiz mijoz',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('•  Savdo #${s.id}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${s.customerPhone ?? 'Telefon ko‘rsatilmagan'}  ·  Jami: ${money(s.total)} (To‘langan: ${money(s.paid)})',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      money(s.debt),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FilledButton.icon(
                                      onPressed: () => _pay(s),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.darkCard,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.payment_rounded, size: 16, color: AppColors.neonLime),
                                      label: const Text('To‘lash'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

