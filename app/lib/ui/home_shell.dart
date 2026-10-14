import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import '../state/auth_controller.dart';
import 'common.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'pos_screen.dart';
import 'production_screen.dart';
import 'products_screen.dart';
import 'stock_screen.dart';
import 'users_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final Widget Function() build;
  final bool isGeneral;
  final String actionLabel;
  const _Dest(this.label, this.icon, this.build, {this.isGeneral = false, this.actionLabel = 'Qo‘shish'});
}

List<_Dest> _destinationsFor(Role role, {void Function(int index)? onNavigate}) {
  final dash = _Dest('Dashboard', Icons.grid_view_rounded, () => DashboardScreen(onNavigate: onNavigate), actionLabel: '+ Yangi Savdo');
  const pos = _Dest('Savdo (POS)', Icons.point_of_sale_rounded, PosScreen.new, actionLabel: 'Savdoga o‘tish');
  const debts = _Dest('Nasiyalar', Icons.pending_actions_rounded, DebtsScreen.new, actionLabel: 'Qarz undirish');
  const products = _Dest('Mahsulotlar', Icons.inventory_2_rounded, ProductsScreen.new, actionLabel: '+ Mahsulot');
  const stock = _Dest('Ombor', Icons.warehouse_rounded, StockScreen.new, actionLabel: '+ Xarid kirimi');
  final prod = _Dest(
    'Ishlab chiqarish',
    Icons.precision_manufacturing_rounded,
    ProductionScreen.new,
    actionLabel: role == Role.admin ? '+ Topshiriq' : '',
  );
  const staff = _Dest('Xodimlar', Icons.badge_rounded, UsersScreen.new, isGeneral: true, actionLabel: '+ Xodim');
  final cams = _Dest('Kameralar', Icons.videocam_rounded,
      () => const NotImplementedView(title: 'Kameralar', note: 'IP-kamera / DVR oqimlari keyingi bosqichda ulanadi.'),
      isGeneral: true, actionLabel: 'Sozlash');

  switch (role) {
    case Role.admin:
      return [dash, pos, debts, products, stock, prod, staff, cams];
    case Role.kassir:
      return [pos, debts, products];
    case Role.ishchi:
      return [prod];
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});
  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _refreshKey = 0;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onAction(String label) async {
    final dests = _destinationsFor(widget.user.role, onNavigate: (i) {
      setState(() {
        _index = i;
      });
    });
    final cur = dests[_index];
    final repos = context.read<AppRepositories>();

    if (cur.label == 'Dashboard') {
      // Savdo (POS) ga o'tish
      final posIndex = dests.indexWhere((d) => d.label.startsWith('Savdo'));
      if (posIndex >= 0) {
        setState(() {
          _index = posIndex;
        });
      }
    } else if (cur.label.startsWith('Savdo')) {
      showMessage(context, 'Kassa faol. Mahsulotni tanlang yoki kodini skaner qiling.');
    } else if (cur.label == 'Nasiyalar') {
      final debts = await repos.sales.listDebts();
      if (!mounted) return;
      if (debts.isEmpty) {
        showMessage(context, 'Hozircha undirilishi kerak bo‘lgan qarzdorliklar yo‘q');
        return;
      }

      final selected = debts.length == 1
          ? debts.first
          : await showDialog<SaleResult>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                title: const Text('Qarz undirish: Mijozni tanlang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final d in debts)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF1DC),
                              child: Text(
                                d.customerName?.isNotEmpty == true ? d.customerName![0].toUpperCase() : '#',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFC77700)),
                              ),
                            ),
                            title: Text(d.customerName ?? 'Mijoz #${d.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('Qarz: ${money(d.debt)}'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: () => Navigator.pop(ctx, d),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor')),
                ],
              ),
            );

      if (selected != null && mounted) {
        final ctrl = TextEditingController(text: selected.debt.round().toString());
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
                'Qarz to‘lovi: ${selected.customerName ?? 'Savdo #${selected.id}'}',
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
                      decoration: BoxDecoration(color: const Color(0xFFFFF1DC), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.pending_actions_rounded, color: Color(0xFFC77700)),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Qoldiq qarz', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          Text(money(selected.debt), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFC77700))),
                        ]),
                      ]),
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
                TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Bekor')),
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
                          if (val > selected.debt + 0.01) {
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
                            await repos.sales.payDebt(selected.id, val, method: method);
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
          setState(() {
            _refreshKey++;
          });
        }
      }
    } else if (cur.label == 'Mahsulotlar') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => ProductDialog(repo: repos.products),
      );
      if (saved == true && mounted) {
        showMessage(context, 'Yangi mahsulot saqlandi');
        setState(() {
          _refreshKey++;
        });
      }
    } else if (cur.label == 'Ombor') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => StockPurchaseDialog(
          stockRepo: repos.stock,
          productRepo: repos.products,
        ),
      );
      if (saved == true && mounted) {
        showMessage(context, 'Yangi xarid kirimi saqlandi');
        setState(() {
          _refreshKey++;
        });
      }
    } else if (cur.label == 'Ishlab chiqarish') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => TaskCreateDialog(
          productionRepo: repos.production,
          productRepo: repos.products,
        ),
      );
      if (saved == true && mounted) {
        showMessage(context, 'Yangi topshiriq biriktirildi');
        setState(() {
          _refreshKey++;
        });
      }
    } else if (cur.label == 'Xodimlar') {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => UserDialog(repo: repos.users),
      );
      if (saved == true && mounted) {
        showMessage(context, 'Yangi xodim qo‘shildi');
        setState(() {
          _refreshKey++;
        });
      }
    } else if (cur.label == 'Kameralar') {
      showMessage(context, 'IP-kamera / DVR oqimlari keyingi bosqichda ulanadi.');
    }
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: AppColors.ink),
            SizedBox(width: 10),
            Text('Bildirishnomalar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNotifItem(
                title: 'Ombor ogohlantirishi',
                desc: 'Metalogranit zaxirasi 80 m² qoldi.',
                time: '12 daqiqa oldin',
                color: const Color(0xFFC77700),
                icon: Icons.inventory_2_outlined,
              ),
              const Divider(height: 16),
              _buildNotifItem(
                title: 'Qarz to‘lovi',
                desc: 'Akmal aka 300 000 so‘m to‘lov qildi.',
                time: '1 soat oldin',
                color: AppColors.green,
                icon: Icons.payments_outlined,
              ),
              const Divider(height: 16),
              _buildNotifItem(
                title: 'Ishlab chiqarish',
                desc: 'Ishchi Bobur Angola kesish topshirig‘ini boshladi.',
                time: 'Bugun, 09:30',
                color: const Color(0xFF245580),
                icon: Icons.precision_manufacturing_rounded,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.darkCard),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifItem({
    required String title,
    required String desc,
    required String time,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(time, style: const TextStyle(color: Color(0xFF9EA3A8), fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dests = _destinationsFor(widget.user.role, onNavigate: (i) {
      setState(() {
        _index = i;
      });
    });
    if (_index >= dests.length) _index = 0;

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 940;
    final body = KeyedSubtree(
      key: ValueKey('${dests[_index].label}_$_refreshKey'),
      child: dests[_index].build(),
    );

    void logout() => context.read<AuthController>().logout();

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.sidebar,
        body: Row(
          children: [
            // Chap Tomondagi "Vault" uslubidagi qora panel
            SizedBox(
              width: 250,
              child: _VaultSidebar(
                dests: dests,
                index: _index,
                user: widget.user,
                onSelect: (i) {
                  setState(() {
                    _index = i;
                  });
                },
                onLogout: logout,
              ),
            ),

            // Asosiy och rangli boshqaruv paneli
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: ColoredBox(
                    color: AppColors.panel,
                    child: Column(
                      children: [
                        _VaultHeader(
                          title: dests[_index].label,
                          user: widget.user,
                          searchCtrl: _searchCtrl,
                          actionLabel: dests[_index].actionLabel,
                          onActionPressed: () => _onAction(dests[_index].actionLabel),
                          onNotificationPressed: () => _showNotifications(context),
                        ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobil va planshet ekrani
    return Scaffold(
      backgroundColor: AppColors.panel,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.neonLime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.token_rounded, color: AppColors.ink, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              dests[_index].label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bildirishnomalar',
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
            onPressed: () => _showNotifications(context),
          ),
          IconButton(
            tooltip: 'Chiqish',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.sidebar,
        child: SafeArea(
          child: _VaultSidebar(
            dests: dests,
            index: _index,
            user: widget.user,
            onSelect: (i) {
              setState(() {
                _index = i;
              });
              Navigator.pop(context);
            },
            onLogout: logout,
          ),
        ),
      ),
      bottomNavigationBar: dests.length > 1 && dests.length <= 5
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                setState(() {
                  _index = i;
                });
              },
              backgroundColor: Colors.white,
              indicatorColor: AppColors.neonLimeSoft,
              destinations: [
                for (final d in dests)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    label: d.label,
                  ),
              ],
            )
          : null,
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Vault Yuqori Header Bar
// ---------------------------------------------------------------------------

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({
    required this.title,
    required this.user,
    required this.searchCtrl,
    required this.actionLabel,
    required this.onActionPressed,
    required this.onNotificationPressed,
  });

  final String title;
  final AppUser user;
  final TextEditingController searchCtrl;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final VoidCallback onNotificationPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 14),
      color: AppColors.panel,
      child: Row(
        children: [
          // Sahifa nomi
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.6,
            ),
          ),

          const Spacer(),

          // Qidiruv paneli (Vault oval shape)
          Container(
            width: 260,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Tizim bo‘yicha qidirish...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Filtr tugmasi
          _HeaderIconBtn(
            icon: Icons.tune_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filtrlar avtomatik tarzda qo‘llanadi')),
              );
            },
          ),

          const SizedBox(width: 8),

          // Bildirishnoma (qo'ng'iroqcha)
          Stack(
            children: [
              _HeaderIconBtn(
                icon: Icons.notifications_none_rounded,
                onTap: onNotificationPressed,
              ),
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.neonLime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          if (actionLabel.isNotEmpty) ...[
            const SizedBox(width: 16),
            // Qora oval tugma
            FilledButton.icon(
              onPressed: onActionPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkCard,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 17, color: AppColors.neonLime),
              label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: IconButton(
        icon: Icon(icon, size: 19, color: AppColors.ink),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vault Yon Sidebar Paneli
// ---------------------------------------------------------------------------

class _VaultSidebar extends StatelessWidget {
  const _VaultSidebar({
    required this.dests,
    required this.index,
    required this.user,
    required this.onSelect,
    required this.onLogout,
  });

  final List<_Dest> dests;
  final int index;
  final AppUser user;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final menuItems = <int>[];
    final generalItems = <int>[];

    for (int i = 0; i < dests.length; i++) {
      if (dests[i].isGeneral) {
        generalItems.add(i);
      } else {
        menuItems.add(i);
      }
    }

    final initial = user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brend
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.token_rounded, color: AppColors.ink, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'STONEX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Scrollable nav items so it NEVER overflows on any desktop screen height
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 10, bottom: 8),
                    child: Text(
                      'MENU',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  for (final i in menuItems)
                    _VaultNavItem(
                      dest: dests[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),

                  if (generalItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.only(left: 10, bottom: 8),
                      child: Text(
                        'GENERAL',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    for (final i in generalItems)
                      _VaultNavItem(
                        dest: dests[i],
                        selected: i == index,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Status / Pro Karta
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2125),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B3037)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.neonLime,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.ink, size: 17),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STONEX PRO',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Tizim barqaror faol',
                        style: TextStyle(color: Color(0xFF8E959E), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Foydalanuvchi profili qatori
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF191C1F),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.neonLime,
                  child: Text(
                    initial,
                    style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        user.role.label,
                        style: const TextStyle(color: Color(0xFF8E959E), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Chiqish',
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFF8E959E), size: 18),
                  onPressed: onLogout,
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
// Vault Nav Item (Left neon-lime vertical indicator pill)
// ---------------------------------------------------------------------------

class _VaultNavItem extends StatelessWidget {
  const _VaultNavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? const Color(0xFF1E2125) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.neonLime : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  dest.icon,
                  size: 19,
                  color: selected ? AppColors.neonLime : const Color(0xFF8E959E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dest.label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF8E959E),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}