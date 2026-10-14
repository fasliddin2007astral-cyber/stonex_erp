import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigate});
  final void Function(int index)? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<
      ({
        FinanceSummary finance,
        List<Product> products,
        List<ProductionTask> tasks
      })> _future;
  String _selectedCategory = 'Barchasi';

  @override
  void initState() {
    super.initState();
    _future = _fetchData();
  }

  Future<
      ({
        FinanceSummary finance,
        List<Product> products,
        List<ProductionTask> tasks
      })> _fetchData() {
    final repos = context.read<AppRepositories>();
    return Future.wait([
      repos.finance.summary(),
      repos.products.list(),
      repos.production.list(),
    ]).then((results) => (
          finance: results[0] as FinanceSummary,
          products: results[1] as List<Product>,
          tasks: results[2] as List<ProductionTask>,
        ));
  }

  void _reload() {
    if (!mounted) return;
    final next = _fetchData();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({
          FinanceSummary finance,
          List<Product> products,
          List<ProductionTask> tasks
        })>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(message: snap.error.toString(), onRetry: _reload);
        }

        final data = snap.data!;
        final f = data.finance;
        final products = data.products;
        final tasks = data.tasks;

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              final isTablet =
                  constraints.maxWidth >= 720 && constraints.maxWidth < 1024;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 6, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Yuqori 4 ta Karta qatori (Mockupdagi Row 1)
                    _buildTopStatsRow(f, isDesktop, isTablet),

                    const SizedBox(height: 20),

                    // 2. O'rta bo'lim: Dinamika grafigi + Mahsulotlar jadvali (Mockupdagi Row 2)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildStockWaveChartCard(f),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: _buildTagsAndStockTableCard(products),
                          ),
                        ],
                      )
                    else ...[
                      _buildStockWaveChartCard(f),
                      const SizedBox(height: 20),
                      _buildTagsAndStockTableCard(products),
                    ],

                    const SizedBox(height: 20),

                    // 3. Pastki bo'lim: 3 ta karta (Savdolar, AI Zaxira tavsiyasi, Ishlab chiqarish topshiriqlari)
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildRecentOrdersCard(f),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: _buildRestockAiCard(products),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: _buildTasksQueueCard(tasks),
                          ),
                        ],
                      )
                    else ...[
                      _buildRecentOrdersCard(f),
                      const SizedBox(height: 20),
                      _buildRestockAiCard(products),
                      const SizedBox(height: 20),
                      _buildTasksQueueCard(tasks),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Yuqori 4 ta Karta qatori
  // ---------------------------------------------------------------------------

  Widget _buildTopStatsRow(FinanceSummary f, bool isDesktop, bool isTablet) {
    final card1 = _TopDarkStatCard(
      title: 'Jami Savdolar (Daromad)',
      value: money(f.revenue),
      badgeText: '+10% O‘tgan oyga nisbatan',
      icon: Icons.shopping_bag_outlined,
      onTap: () => widget.onNavigate?.call(1),
    );

    final card2 = _TopLightStatCard(
      title: 'Kassaga Tushgan Pul',
      value: money(f.cashCollected),
      badgeText: '+7% Tushum sur’ati',
      icon: Icons.payments_outlined,
      iconColor: AppColors.green,
      iconBg: AppColors.greenSoft,
      onTap: () => widget.onNavigate?.call(1),
    );

    final card3 = _TopGaugeStatCard(
      title: 'Qarzdorlik (Nasiya)',
      value: money(f.receivables),
      percentageText: '12%',
      subText: 'Undirish kutilmoqda',
      progress: (f.revenue > 0 ? (f.receivables / f.revenue) : 0.12)
          .clamp(0.05, 0.95),
      icon: Icons.pending_actions_rounded,
      ringColor: const Color(0xFFC77700),
      ringBg: const Color(0xFFFFF3D6),
      onTap: () => widget.onNavigate?.call(2),
    );

    final margin = f.revenue > 0 ? (f.netProfit / f.revenue * 100) : 24.5;
    final card4 = _TopSpeedGaugeCard(
      title: 'Sex Sof Foyda Marjasi',
      value: '${margin.toStringAsFixed(1)}%',
      badgeText: f.netProfit >= 0 ? '+18% O‘sish' : '-5% Xarajat',
      subText: money(f.netProfit),
      isPositive: f.netProfit >= 0,
      icon: Icons.show_chart_rounded,
      onTap: () => _reload(),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 16),
          Expanded(child: card2),
          const SizedBox(width: 16),
          Expanded(child: card3),
          const SizedBox(width: 16),
          Expanded(child: card4),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(children: [
            Expanded(child: card1),
            const SizedBox(width: 16),
            Expanded(child: card2)
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: card3),
            const SizedBox(width: 16),
            Expanded(child: card4)
          ]),
        ],
      );
    }

    // Mobil: bittalab vertikal
    return Column(
      children: [
        card1,
        const SizedBox(height: 12),
        card2,
        const SizedBox(height: 12),
        card3,
        const SizedBox(height: 12),
        card4,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. O'rta chap: To'lqinsimon Spline Grafiki (Stock Volume vs Consume)
  // ---------------------------------------------------------------------------

  Widget _buildStockWaveChartCard(FinanceSummary f) {
    final categories = [
      'Barchasi',
      'Toshlar',
      'Plitalar',
      'Materiallar',
      'Aksessuarlar'
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sarlavha va boshqaruv elementlari
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ombor Zaxirasi va Savdo Hajmi Dinamikasi',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Oy davomidagi kirim va chiqim oqimi taqqoslanishi',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              // Legendlar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendDot(color: AppColors.neonLime, label: 'Zaxira hajmi'),
                  const SizedBox(width: 14),
                  _LegendDot(color: AppColors.green, label: 'Sotuv chiqimi'),
                ],
              ),
              const SizedBox(width: 14),
              // Oylik dropdown pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Oylik',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Grafika maydoni (Custom wave spline painter with floating black pill tooltip)
          SizedBox(
            height: 210,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WaveSplineChartPainter(),
                  ),
                ),
                // Mockupdagi qora tooltip: "Stock in $31,000"
                Positioned(
                  top: 24,
                  left: 170,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Zaxirada',
                            style: TextStyle(
                                color: Color(0xFF8E959E), fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          f.revenue > 0
                              ? money(f.revenue * 0.45)
                              : '31 000 000 so‘m',
                          style: const TextStyle(
                            color: AppColors.neonLime,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Kategoriyalar filtri pill-tugmalari (Mockupdagi Electronic, Drinks, Fashion kabi)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categories) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCategory == cat
                            ? AppColors.darkCard
                            : AppColors.panel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: _selectedCategory == cat
                              ? Colors.white
                              : AppColors.muted,
                          fontSize: 12,
                          fontWeight: _selectedCategory == cat
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. O'rta o'ng: Mahsulotlar Qoldiq Jadvali (Custom Tags & Labels)
  // ---------------------------------------------------------------------------

  Widget _buildTagsAndStockTableCard(List<Product> products) {
    final tags = ['Ko‘p sotiladigan', 'Chegirma', 'Kam qolgan'];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ombor Holati va Teglar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              Text(
                'AI nazorati',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Teglar qatori
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < tags.length; i++) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.darkCard : AppColors.panel,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tags[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: i == 0 ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Mahsulotlar mini-jadvali
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Mahsulotlar mavjud emas')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(products.length, 5),
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (_, i) {
                final p = products[i];
                final initial =
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?';

                return InkWell(
                  onTap: () => widget.onNavigate?.call(3),
                  borderRadius: BorderRadius.circular(10),
                  mouseCursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.neonLimeSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              Text(
                                p.sku.isNotEmpty
                                    ? p.sku
                                    : '${qty(p.stock)} ${p.unit}',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money(p.price),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Pastki chap: So'nggi Savdolar (Sales & Order)
  // ---------------------------------------------------------------------------

  Widget _buildRecentOrdersCard(FinanceSummary f) {
    final demoOrders = [
      ('Mirmuhsin aka', '2 450 000 so‘m', 'Yuqori', AppColors.green),
      ('G‘ofur qurilish', '5 800 000 so‘m', 'O‘rta', AppColors.warning),
      ('Bobur usta', '850 000 so‘m', 'Past', AppColors.muted),
      ('Azizbek savdo', '3 200 000 so‘m', 'Yuqori', AppColors.green),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Savdolar & Buyurtmalar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          for (final ord in demoOrders) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.panel,
                    child: Text(
                      ord.$1[0],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ord.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    ord.$2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ord.$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ord.$3,
                      style: TextStyle(
                          color: ord.$4,
                          fontWeight: FontWeight.w700,
                          fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Pastki o'rta: AI Zaxira Tavsiyasi (AI Restock Recommendation)
  // ---------------------------------------------------------------------------

  Widget _buildRestockAiCard(List<Product> products) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Zaxira Tavsiyasi',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          // Mini grafik chiziq
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(
              painter: _MiniSparklinePainter(),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Qoldig‘i 20% dan kam qolgan tovarlar aniqlandi.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onNavigate?.call(4),
                  child: const Text('Barchasi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onNavigate?.call(4),
                  child: const Text('Zaxira'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Pastki o'ng: Ishlab Chiqarish Topshiriqlari (Still Not Arrived / Production)
  // ---------------------------------------------------------------------------

  Widget _buildTasksQueueCard(List<ProductionTask> tasks) {
    final openTasks = tasks.where((t) => t.status != 'done').toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Topshiriqlar Nazorati',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.neonLimeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${openTasks.length} ta faol',
                  style: const TextStyle(
                      color: AppColors.neonLimeDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (openTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('Kechikkan topshiriqlar yo‘q',
                      style: TextStyle(color: AppColors.muted))),
            )
          else
            for (final t in openTasks.take(3)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFE0E7FF),
                      child: Text(
                        t.workerName.isNotEmpty ? t.workerName[0] : 'W',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Color(0xFF3730A3)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('Ishchi: ${t.workerName}',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${qty(t.produced)}/${qty(t.planned)}',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onNavigate?.call(5),
              child: const Text('Barcha topshiriqlar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat Kartalari (Vault qora va oq kartalari)
// ---------------------------------------------------------------------------

class _TopDarkStatCard extends StatelessWidget {
  const _TopDarkStatCard({
    required this.title,
    required this.value,
    required this.badgeText,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String badgeText;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.neonLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.ink, size: 20),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22262B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_outward_rounded,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF8E959E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A2B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                      color: AppColors.greenBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopLightStatCard extends StatelessWidget {
  const _TopLightStatCard({
    required this.title,
    required this.value,
    required this.badgeText,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });

  final String title;
  final String value;
  final String badgeText;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.panel,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_outward_rounded,
                        color: AppColors.ink, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopGaugeStatCard extends StatelessWidget {
  const _TopGaugeStatCard({
    required this.title,
    required this.value,
    required this.percentageText,
    required this.subText,
    required this.progress,
    required this.icon,
    required this.ringColor,
    required this.ringBg,
    this.onTap,
  });

  final String title;
  final String value;
  final String percentageText;
  final String subText;
  final double progress;
  final IconData icon;
  final Color ringColor;
  final Color ringBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.neonLimeSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.ink, size: 20),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.panel,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_outward_rounded,
                        color: AppColors.ink, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(subText,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomPaint(
                      painter: _VaultCircleRingPainter(
                          progress: progress, color: ringColor, track: ringBg),
                      child: Center(
                        child: Text(
                          percentageText,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: ringColor),
                        ),
                      ),
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

class _TopSpeedGaugeCard extends StatelessWidget {
  const _TopSpeedGaugeCard({
    required this.title,
    required this.value,
    required this.badgeText,
    required this.subText,
    required this.isPositive,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String badgeText;
  final String subText;
  final bool isPositive;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            mouseCursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isPositive
                              ? AppColors.greenSoft
                              : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon,
                            color:
                                isPositive ? AppColors.green : AppColors.danger,
                            size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? AppColors.greenSoft
                              : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: isPositive
                                ? const Color(0xFF065F46)
                                : AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Sof foyda: $subText',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// Custom Painterni chizuvchilar
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _WaveSplineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Y o'qi nozik gorizontal chiziqlari
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F2F5)
      ..strokeWidth = 1;

    for (int i = 1; i <= 4; i++) {
      final y = h * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 1-to'lqin (Neon-laym)
    final path1 = Path();
    path1.moveTo(0, h * 0.70);
    path1.cubicTo(w * 0.20, h * 0.65, w * 0.35, h * 0.15, w * 0.50, h * 0.25);
    path1.cubicTo(w * 0.65, h * 0.35, w * 0.80, h * 0.85, w, h * 0.45);

    final fillPath1 = Path.from(path1)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fill1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.neonLime.withValues(alpha: 0.35),
          AppColors.neonLime.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath1, fill1);

    final stroke1 = Paint()
      ..color = AppColors.neonLime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path1, stroke1);

    // 2-to'lqin (Yashil)
    final path2 = Path();
    path2.moveTo(0, h * 0.82);
    path2.cubicTo(w * 0.25, h * 0.75, w * 0.40, h * 0.45, w * 0.60, h * 0.55);
    path2.cubicTo(w * 0.75, h * 0.62, w * 0.88, h * 0.35, w, h * 0.50);

    final stroke2 = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path2, stroke2);

    // Cho'qqidagi nuqta
    canvas.drawCircle(
        Offset(w * 0.50, h * 0.25), 5, Paint()..color = AppColors.darkCard);
    canvas.drawCircle(
        Offset(w * 0.50, h * 0.25), 2.5, Paint()..color = AppColors.neonLime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VaultCircleRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _VaultCircleRingPainter(
      {required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _VaultCircleRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _MiniSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.8)
      ..lineTo(w * 0.3, h * 0.6)
      ..lineTo(w * 0.6, h * 0.7)
      ..lineTo(w * 0.85, h * 0.2)
      ..lineTo(w, h * 0.35);

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
