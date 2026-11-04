import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repositories.dart';
import '../domain/models.dart';
import 'common.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int _currentTab = 0; // 0: Xodimlar, 1: Davomat (Keldi-Ketdi), 2: Oylik hisobi

  // Tab 0: Xodimlar
  late Future<List<AppUser>> _usersFuture;
  String _selectedFilter = 'Barchasi';
  final _searchCtrl = TextEditingController();

  // Tab 1: Davomat
  DateTime _selectedDate = DateTime.now();
  late Future<List<AttendanceRecord>> _attendanceFuture;
  final _attSearchCtrl = TextEditingController();
  String _attFilter = 'Barchasi'; // 'Barchasi', 'Kelganlar', 'Hali kelmaganlar', 'Kechikkanlar'

  // Tab 2: Oylik hisobi
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final int _totalWorkingDays = 26;
  late Future<List<SalaryReportItem>> _salaryFuture;

  UserRepository get _usersRepo => context.read<AppRepositories>().users;
  AttendanceRepository get _attRepo => context.read<AppRepositories>().attendance;

  String get _dateStr =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  String get _monthStr =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _reloadUsers();
    _reloadAttendance();
    _reloadSalary();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _attSearchCtrl.dispose();
    super.dispose();
  }

  void _reloadUsers() {
    setState(() {
      _usersFuture = _usersRepo.list();
    });
  }

  void _reloadAttendance() {
    setState(() {
      _attendanceFuture = _attRepo.list(date: _dateStr);
    });
  }

  void _reloadSalary() {
    setState(() {
      _salaryFuture = _attRepo.getSalaryReport(
        month: _monthStr,
        totalWorkingDays: _totalWorkingDays,
      );
    });
  }

  void _reloadAll() {
    _reloadUsers();
    _reloadAttendance();
    _reloadSalary();
  }

  // --- Xodim qo'shish va tahrirlash ---
  Future<void> _addUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => UserDialog(repo: _usersRepo),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Yangi xodim muvaffaqiyatli qo‘shildi');
      _reloadAll();
    }
  }

  Future<void> _editUser(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => UserDialog(repo: _usersRepo, user: user),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Xodim ma’lumotlari yangilandi');
      _reloadAll();
    }
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final action = user.isActive ? 'bloklash' : 'faollashtirish';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          user.isActive ? 'Xodimni bloklash' : 'Xodimni faollashtirish',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          user.isActive
              ? '"${user.fullName}" hisobini bloklamoqchimisiz? U tizimga kira olmaydi.'
              : '"${user.fullName}" hisobini qayta faollashtirmoqchimisiz?',
          style: const TextStyle(height: 1.4, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive ? AppColors.danger : AppColors.darkCard,
            ),
            child: Text(user.isActive ? 'Bloklash' : 'Faollashtirish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _usersRepo.update(
        user.id,
        fullName: user.fullName,
        role: user.role,
        isActive: !user.isActive,
      );
      if (mounted) {
        showMessage(context, 'Xodim muvaffaqiyatli $action qilindi');
        _reloadAll();
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Xatolik: $e', error: true);
      }
    }
  }

  // --- Davomat amallari ---
  Future<void> _checkIn(AppUser user, {String status = 'present'}) async {
    try {
      final now = DateTime.now();
      if (status == 'late' || status == 'absent') {
        final rec = AttendanceRecord(
          id: 0,
          userId: user.id,
          userName: user.fullName,
          date: _dateStr,
          status: status,
          checkIn: status == 'absent' ? null : now,
          workedHours: 0,
        );
        await _attRepo.saveRecord(rec);
      } else {
        await _attRepo.checkIn(user.id, time: now);
      }
      if (mounted) {
        final statusLabel = status == 'late'
            ? 'kechikkan'
            : (status == 'absent' ? 'kelmagan' : 'keldi');
        showMessage(
          context,
          '✓ ${user.fullName} $statusLabel deb qayd etildi (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})',
        );
        _reloadAttendance();
        _reloadSalary();
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Xatolik: $e', error: true);
    }
  }

  Future<void> _checkInAllAbsent(List<AppUser> absentUsers) async {
    if (absentUsers.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.green),
            SizedBox(width: 8),
            Text('Tezkor umumiy davomat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Hali kelmagan ${absentUsers.length} nafar xodim uchun hozirgi vaqt bilan kirish (keldi) qayd etilsinmi?',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Ha, barchasini belgilash'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final now = DateTime.now();
    int count = 0;
    try {
      await _attRepo.bulkCheckIn(absentUsers.map((u) => u.id).toList(), time: now, date: _dateStr);
      count = absentUsers.length;
    } catch (_) {
      // Fallback
      for (final u in absentUsers) {
        try {
          await _attRepo.checkIn(u.id, time: now);
          count++;
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        if (count > 0) {
          showMessage(context, '✓ $count nafar xodim keldi deb belgilandi');
        }
        _reloadAttendance();
        _reloadSalary();
      }
    }
  }

  Future<void> _checkOut(AppUser user) async {
    try {
      final now = DateTime.now();
      await _attRepo.checkOut(user.id, time: now);
      if (mounted) {
        showMessage(
          context,
          '✓ ${user.fullName} ketdi deb qayd etildi (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})',
        );
        _reloadAttendance();
        _reloadSalary();
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Xatolik: $e', error: true);
    }
  }

  Future<void> _editAttendance(AppUser user, AttendanceRecord? rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AttendanceDialog(
        repo: _attRepo,
        user: user,
        date: _dateStr,
        record: rec,
      ),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Davomat ma’lumotlari saqlandi');
      _reloadAttendance();
      _reloadSalary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: _buildFab(),
      body: Column(
        children: [
          // 1. Yuqori zamonaviy Tab Switcher
          _buildTopTabs(),

          // 2. Tab mazmuni
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildUsersTab(),
                _buildAttendanceTab(),
                _buildSalaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (_currentTab == 0) {
      return FloatingActionButton.extended(
        backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
        foregroundColor: context.isDark ? AppColors.ink : Colors.white,
        onPressed: _addUser,
        icon: Icon(Icons.person_add_rounded, color: context.isDark ? AppColors.ink : AppColors.neonLime),
        label: const Text('Xodim qo‘shish', style: TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Top Tabs (Burchaksiz zamonaviy kapsula / Segmented UI)
  // ---------------------------------------------------------------------------
  Widget _buildTopTabs() {
    final tabs = [
      ('Xodimlar', Icons.people_alt_rounded),
      ('Davomat (Keldi / Ketdi)', Icons.access_time_rounded),
      ('Oylik hisobi', Icons.account_balance_wallet_rounded),
    ];

    final isDark = context.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.borderColor.withValues(alpha: 0.6))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E28) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: context.borderColor.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                InkWell(
                  onTap: () => setState(() => _currentTab = i),
                  borderRadius: BorderRadius.circular(100),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: _currentTab == i
                          ? (isDark ? AppColors.neonLime : AppColors.darkCard)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: _currentTab == i
                          ? [
                              BoxShadow(
                                color: (isDark ? AppColors.neonLime : Colors.black).withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tabs[i].$2,
                          size: 16,
                          color: _currentTab == i
                              ? (isDark ? AppColors.ink : Colors.white)
                              : context.mutedColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _currentTab == i ? FontWeight.w800 : FontWeight.w600,
                            color: _currentTab == i
                                ? (isDark ? AppColors.ink : Colors.white)
                                : context.mutedColor,
                          ),
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // TAB 0: Xodimlar Ro'yxati
  // ---------------------------------------------------------------------------
  Widget _buildUsersTab() {
    final filterOptions = ['Barchasi', 'Adminlar', 'Kassirlar', 'Ishchilar', 'Dasturga kiradiganlar', 'Faqat ro‘yxatdagilar', 'Bloklanganlar'];

    return FutureBuilder<List<AppUser>>(
      future: _usersFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(message: snap.error.toString(), onRetry: _reloadUsers);
        }

        final allUsers = snap.data ?? [];
        final totalCount = allUsers.length;
        final adminCount = allUsers.where((u) => u.role == Role.admin).length;
        final cashierCount = allUsers.where((u) => u.role == Role.kassir).length;
        final workerCount = allUsers.where((u) => u.role == Role.ishchi).length;
        final blockedCount = allUsers.where((u) => !u.isActive).length;

        var users = allUsers.where((u) {
          final query = _searchCtrl.text.toLowerCase().trim();
          final matchesSearch = query.isEmpty ||
              u.fullName.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query);

          if (!matchesSearch) return false;

          switch (_selectedFilter) {
            case 'Adminlar':
              return u.role == Role.admin && u.isActive;
            case 'Kassirlar':
              return u.role == Role.kassir && u.isActive;
            case 'Ishchilar':
              return u.role == Role.ishchi && u.isActive;
            case 'Dasturga kiradiganlar':
              return u.canLogin && u.isActive;
            case 'Faqat ro‘yxatdagilar':
              return !u.canLogin && u.isActive;
            case 'Bloklanganlar':
              return !u.isActive;
            default:
              return true;
          }
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _reloadUsers(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI Kartalari
              Row(
                children: [
                  _buildKpiCard('Jami Xodimlar', '$totalCount ta', Icons.badge_rounded, AppColors.ink),
                  const SizedBox(width: 10),
                  _buildKpiCard('Adminlar', '$adminCount ta', Icons.admin_panel_settings_rounded, AppColors.neonLime),
                  const SizedBox(width: 10),
                  _buildKpiCard('Kassirlar', '$cashierCount ta', Icons.point_of_sale_rounded, AppColors.green),
                  const SizedBox(width: 10),
                  _buildKpiCard('Ishchilar', '$workerCount ta', Icons.precision_manufacturing_rounded, const Color(0xFFD97706)),
                ],
              ),
              const SizedBox(height: 14),

              // Qidiruv va Filter
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Xodim nomi yoki logini bo‘yicha qidirish...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter teglari
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filterOptions.map((f) {
                    final isSel = _selectedFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedFilter = f),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Xodimlar ro'yxati
              if (users.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.person_off_rounded, size: 48, color: context.mutedColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        Text('Xodimlar topilmadi', style: TextStyle(color: context.mutedColor, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                for (final u in users) _buildUserCard(u),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserCard(AppUser u) {
    Color roleColor;
    switch (u.role) {
      case Role.admin:
        roleColor = const Color(0xFF8B5CF6);
        break;
      case Role.kassir:
        roleColor = AppColors.green;
        break;
      case Role.ishchi:
        roleColor = const Color(0xFFD97706);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: u.isActive ? context.borderColor : AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w800, color: roleColor, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.fullName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.inkColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        u.role.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: roleColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!u.canLogin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF21262D) : const Color(0xFFEFF2F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.borderColor, width: 0.7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, size: 11, color: context.mutedColor),
                            const SizedBox(width: 3),
                            Text(
                              'Faqat ro‘yxatda',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.mutedColor),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.key_rounded, size: 10, color: AppColors.green),
                            SizedBox(width: 3),
                            Text(
                              'Kirish ruxsati bor',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (u.canLogin) ...[
                      Text(
                        '@${u.username}',
                        style: TextStyle(fontSize: 11.5, color: context.mutedColor),
                      ),
                      const SizedBox(width: 8),
                      const Text('· ', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                    Text(
                      'Maosh: ${money(u.salary)} (${u.salaryType == "daily" ? "kunbay" : (u.salaryType == "hourly" ? "soatbay" : "oylik")})',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.inkColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: () => _editUser(u),
            tooltip: 'Tahrirlash',
          ),
          IconButton(
            icon: Icon(
              u.isActive ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18,
              color: u.isActive ? AppColors.green : AppColors.danger,
            ),
            onPressed: () => _toggleUserStatus(u),
            tooltip: u.isActive ? 'Bloklash' : 'Faollashtirish',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Davomat (Keldi / Ketdi) - Zamonaviy, qulay va tezkor UI
  // ---------------------------------------------------------------------------
  Widget _buildAttendanceTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_usersFuture, _attendanceFuture]),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(message: snap.error.toString(), onRetry: _reloadAttendance);
        }

        final users = (snap.data?[0] as List<AppUser>?)?.where((u) => u.isActive).toList() ?? [];
        final attendances = (snap.data?[1] as List<AttendanceRecord>?) ?? [];

        final attMap = <int, AttendanceRecord>{};
        for (final a in attendances) {
          attMap[a.userId] = a;
        }

        final presentCount = attendances.where((a) => a.status == 'present').length;
        final lateCount = attendances.where((a) => a.status == 'late').length;
        final totalActive = users.length;
        final absentUsers = users.where((u) => attMap[u.id]?.checkIn == null).toList();
        final absentCount = absentUsers.length;

        // Qidiruv va filtr bo'yicha saralash
        final query = _attSearchCtrl.text.toLowerCase().trim();
        final filteredUsers = users.where((u) {
          final matchesSearch = query.isEmpty ||
              u.fullName.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query);
          if (!matchesSearch) return false;

          final att = attMap[u.id];
          final hasCheckedIn = att?.checkIn != null;
          final isLate = att?.status == 'late';

          switch (_attFilter) {
            case 'Kelganlar':
              return hasCheckedIn && !isLate;
            case 'Hali kelmaganlar':
              return !hasCheckedIn;
            case 'Kechikkanlar':
              return isLate;
            default:
              return true;
          }
        }).toList();

        final isToday = _isToday(_selectedDate);

        return RefreshIndicator(
          onRefresh: () async => _reloadAttendance(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Sana boshqaruvi (O‘ng tomonga yopishtirilgan, yaxlit va qulay zamonaviy kapsula)
              Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: context.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tezkor 'Kecha' va 'Bugun'
                        _buildQuickDateChip('Kecha', DateTime.now().subtract(const Duration(days: 1))),
                        const SizedBox(width: 3),
                        _buildQuickDateChip('Bugun', DateTime.now()),
                        const SizedBox(width: 6),

                        // Ajratuvchi nozik chiziq
                        Container(
                          width: 1,
                          height: 22,
                          color: context.borderColor.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),

                        // Oldingi kun <
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                              _reloadAttendance();
                            });
                          },
                          tooltip: 'Oldingi kun',
                          splashRadius: 18,
                          visualDensity: VisualDensity.compact,
                        ),

                        // Markaziy interaktiv sana (Kalendar)
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                _reloadAttendance();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? (context.isDark ? AppColors.neonLime.withValues(alpha: 0.15) : const Color(0xFFF0FDF4))
                                  : context.pillColor,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isToday
                                    ? (context.isDark ? AppColors.neonLime : const Color(0xFF22C55E))
                                    : context.borderColor.withValues(alpha: 0.6),
                                width: isToday ? 1.2 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 16,
                                  color: isToday
                                      ? (context.isDark ? AppColors.neonLime : const Color(0xFF16A34A))
                                      : context.inkColor,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _formatDateUz(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: isToday
                                        ? (context.isDark ? AppColors.neonLime : const Color(0xFF15803D))
                                        : context.inkColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Keyingi kun >
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 22),
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.add(const Duration(days: 1));
                              _reloadAttendance();
                            });
                          },
                          tooltip: 'Keyingi kun',
                          splashRadius: 18,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. KPI statistika kartalari
              Row(
                children: [
                  _buildKpiCard('Jami xodimlar', '$totalActive ta', Icons.people_outline_rounded, AppColors.ink),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kelganlar', '$presentCount ta', Icons.check_circle_outline_rounded, AppColors.green),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kechikkanlar', '$lateCount ta', Icons.warning_amber_rounded, const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kelmaganlar', '$absentCount ta', Icons.cancel_outlined, AppColors.danger),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Qidiruv va Tezkor "Barchasini keldi qilish" tugmasi
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _attSearchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Xodim nomi bo‘yicha qidirish...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _attSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _attSearchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(color: context.borderColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (absentUsers.isNotEmpty && isToday) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _checkInAllAbsent(absentUsers),
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: Text(
                        'Hammasini keldi qilish (${absentUsers.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // 4. Filtr chiplari (Burchaksiz kapsulalar)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final item in [
                      ('Barchasi', totalActive),
                      ('Kelganlar', presentCount),
                      ('Hali kelmaganlar', absentCount),
                      ('Kechikkanlar', lateCount),
                    ]) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _attFilter = item.$1),
                          borderRadius: BorderRadius.circular(100),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                            decoration: BoxDecoration(
                              color: _attFilter == item.$1
                                  ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                                  : context.cardColor,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: _attFilter == item.$1
                                    ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                                    : context.borderColor,
                              ),
                            ),
                            child: Text(
                              '${item.$1} (${item.$2})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _attFilter == item.$1 ? FontWeight.w800 : FontWeight.w600,
                                color: _attFilter == item.$1
                                    ? (context.isDark ? AppColors.ink : Colors.white)
                                    : context.mutedColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Xodimlar davomat kartalari ro'yxati
              if (filteredUsers.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.person_off_rounded, size: 44, color: context.mutedColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('Xodimlar topilmadi', style: TextStyle(color: context.mutedColor, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                for (final u in filteredUsers)
                  _buildAttendanceRow(u, attMap[u.id]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickDateChip(String label, DateTime targetDate) {
    final isSelected = _selectedDate.year == targetDate.year &&
        _selectedDate.month == targetDate.month &&
        _selectedDate.day == targetDate.day;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = targetDate;
          _reloadAttendance();
        });
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (context.isDark ? AppColors.ink : Colors.white)
                : context.mutedColor,
          ),
        ),
      ),
    );
  }

  String _formatDateUz(DateTime dt) {
    const months = [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'
    ];
    const weekdays = [
      'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'
    ];
    final dayName = weekdays[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '${dt.day}-$monthName, ${dt.year} ($dayName)';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _buildAttendanceRow(AppUser u, AttendanceRecord? att) {
    final hasCheckedIn = att?.checkIn != null;
    final hasCheckedOut = att?.checkOut != null;
    final isLate = att?.status == 'late';

    String statusText = 'Kelmagan';
    Color statusColor = AppColors.danger;
    IconData statusIcon = Icons.close_rounded;

    if (isLate) {
      statusText = 'Kechikkan';
      statusColor = const Color(0xFFD97706);
      statusIcon = Icons.access_time_rounded;
    } else if (hasCheckedIn) {
      statusText = 'Kelgan';
      statusColor = AppColors.green;
      statusIcon = Icons.check_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasCheckedIn
              ? statusColor.withValues(alpha: 0.35)
              : context.borderColor,
          width: hasCheckedIn ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Status belgisi (Avatar)
          CircleAvatar(
            radius: 20,
            backgroundColor: statusColor.withValues(alpha: 0.14),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),

          // 2. Xodim ma'lumotlari
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        u.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: context.inkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Roli
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.pillColor,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        u.role.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.mutedColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Holat badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Vaqt va hisob satri
                Row(
                  children: [
                    if (hasCheckedIn) ...[
                      Icon(Icons.login_rounded, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        'Keldi: ${_formatTime(att!.checkIn!)}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                      ),
                      if (hasCheckedOut) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.logout_rounded, size: 13, color: context.inkColor),
                        const SizedBox(width: 4),
                        Text(
                          'Ketdi: ${_formatTime(att.checkOut!)} (${att.workedHours.toStringAsFixed(1)} soat)',
                          style: TextStyle(fontSize: 11.5, color: context.inkColor, fontWeight: FontWeight.w700),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            '⏳ Ishlamoqda',
                            style: TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ] else ...[
                      Icon(Icons.access_time_rounded, size: 13, color: context.mutedColor),
                      const SizedBox(width: 4),
                      Text(
                        'Kirish qayd etilmagan',
                        style: TextStyle(fontSize: 11.5, color: context.mutedColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (att?.note != null && att!.note!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· 📝 ${att.note}',
                        style: TextStyle(fontSize: 11, color: context.mutedColor, fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 3. Harakat tugmalari (Capsule Buttons)
          if (!hasCheckedIn) ...[
            FilledButton.icon(
              onPressed: () => _checkIn(u, status: 'present'),
              icon: const Icon(Icons.login_rounded, size: 14),
              label: const Text('Keldi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: context.mutedColor),
              splashRadius: 18,
              tooltip: 'Boshqa amallar',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'late') {
                  _checkIn(u, status: 'late');
                } else if (val == 'absent') {
                  _checkIn(u, status: 'absent');
                } else if (val == 'edit') {
                  _editAttendance(u, att);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'late',
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text('Kechikkan deb belgilash', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'absent',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Kelmagan deb belgilash', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Vaqtni qo‘lda kiritish', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (!hasCheckedOut) ...[
            FilledButton.icon(
              onPressed: () => _checkOut(u),
              icon: const Icon(Icons.logout_rounded, size: 14),
              label: const Text('Ketdi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                visualDensity: VisualDensity.compact,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              onPressed: () => _editAttendance(u, att),
              tooltip: 'Tahrirlash',
              splashRadius: 18,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: AppColors.green),
                  SizedBox(width: 4),
                  Text(
                    'Yakunlangan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              onPressed: () => _editAttendance(u, att),
              tooltip: 'Tahrirlash',
              splashRadius: 18,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Oylik va Ish haqi hisoboti (Payroll)
  // ---------------------------------------------------------------------------
  Widget _buildSalaryTab() {
    return FutureBuilder<List<SalaryReportItem>>(
      future: _salaryFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(message: snap.error.toString(), onRetry: _reloadSalary);
        }

        final reports = snap.data ?? [];
        final totalNet = reports.fold(0.0, (sum, r) => sum + r.netSalary);
        final totalBase = reports.fold(0.0, (sum, r) => sum + r.baseSalary);
        final totalDeductions = reports.fold(0.0, (sum, r) => sum + r.deduction);

        return RefreshIndicator(
          onRefresh: () async => _reloadSalary(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Oy tanlash paneli
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                          _reloadSalary();
                        });
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.neonLime),
                            const SizedBox(width: 8),
                            Text(
                              '$_monthStr Oylik Ish Haqi Hisoboti',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.inkColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                          _reloadSalary();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // KPI kartalari
              Row(
                children: [
                  _buildKpiCard('Jami Hisoblangan', money(totalNet), Icons.payments_rounded, AppColors.neonLime),
                  const SizedBox(width: 8),
                  _buildKpiCard('Rejadagi Fond', money(totalBase), Icons.account_balance_wallet_rounded, AppColors.ink),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kechikish jarimalari', '-${money(totalDeductions)}', Icons.gavel_rounded, AppColors.danger),
                ],
              ),
              const SizedBox(height: 14),

              // Xodimlarning oylik hisobot kartalari
              for (final rep in reports) _buildSalaryItemCard(rep),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalaryItemCard(SalaryReportItem r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.fullName,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.inkColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stavka: ${money(r.baseSalary)} / ${r.salaryType == "daily" ? "kun" : (r.salaryType == "hourly" ? "soat" : "oy")}',
                      style: TextStyle(fontSize: 11.5, color: context.mutedColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(r.netSalary),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.green),
                  ),
                  Text(
                    'To‘lanadigan sof maosh',
                    style: TextStyle(fontSize: 10, color: context.mutedColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.pillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📅 Davomat: ${r.daysWorked}/$_totalWorkingDays kun (${r.hoursWorked.toStringAsFixed(1)} soat)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.inkColor),
                ),
                if (r.daysLate > 0)
                  Text(
                    '⚠ ${r.daysLate} kun kechikdi (-${money(r.deduction)})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger),
                  )
                else
                  const Text(
                    '✓ Intizomli',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10.5, color: context.mutedColor, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: context.inkColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Xodim qo'shish va tahrirlash dialogi
// ---------------------------------------------------------------------------

class UserDialog extends StatefulWidget {
  const UserDialog({super.key, required this.repo, this.user});
  final UserRepository repo;
  final AppUser? user;

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  late final _userCtrl = TextEditingController(text: widget.user?.username ?? '');
  late final _nameCtrl = TextEditingController(text: widget.user?.fullName ?? '');
  final _passCtrl = TextEditingController();
  late final _salaryCtrl = TextEditingController(
    text: widget.user != null ? widget.user!.salary.toInt().toString() : '5000000',
  );
  late Role _role = widget.user?.role ?? Role.ishchi;
  late String _salaryType = widget.user?.salaryType ?? 'monthly';
  late bool _isActive = widget.user?.isActive ?? true;
  late bool _canLogin = widget.user?.canLogin ?? (_role != Role.ishchi);

  String? _error;
  bool _busy = false;

  bool get _isEditing => widget.user != null;

  @override
  void dispose() {
    _userCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final n = _nameCtrl.text.trim();
    final sal = double.tryParse(_salaryCtrl.text.replaceAll(' ', '')) ?? 0;

    if (n.isEmpty) {
      setState(() {
        _error = 'Xodimning to‘liq ismini kiriting';
      });
      return;
    }

    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;

    if (_canLogin) {
      if (u.isEmpty) {
        setState(() {
          _error = 'Dasturga kirish uchun loginni kiriting';
        });
        return;
      }
      if (!_isEditing && p.isEmpty) {
        setState(() {
          _error = 'Dasturga kirish uchun parol kiritish shart';
        });
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.repo.update(
          widget.user!.id,
          username: _canLogin ? u : null,
          fullName: n,
          password: (_canLogin && p.isNotEmpty) ? p : null,
          role: _role,
          canLogin: _canLogin,
          salary: sal,
          salaryType: _salaryType,
          isActive: _isActive,
        );
      } else {
        await widget.repo.create(
          username: _canLogin ? u : null,
          fullName: n,
          password: _canLogin ? p : null,
          role: _role,
          canLogin: _canLogin,
          salary: sal,
          salaryType: _salaryType,
        );
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
    return AlertDialog(
      backgroundColor: context.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.pillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditing ? Icons.manage_accounts_rounded : Icons.person_add_rounded,
              color: context.inkColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Xodimni tahrirlash' : 'Yangi xodim qo‘shish',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. To'liq ismi (F.I.O)
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'To‘liq ismi (F.I.O)',
                  hintText: 'masalan: Bobur Rahimov',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Tizimdagi roli
              DropdownButtonFormField<Role>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Tizimdagi roli',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                items: Role.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _role = v ?? _role;
                    if (_role == Role.admin || _role == Role.kassir) {
                      _canLogin = true;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // 3. Dasturga kirish huquqi (Login & Parol) switch card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.pillColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      _canLogin ? Icons.lock_open_rounded : Icons.lock_clock_rounded,
                      size: 20,
                      color: _canLogin
                          ? (context.isDark ? AppColors.neonLime : AppColors.ink)
                          : context.mutedColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dasturga kirish huquqi',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _canLogin
                                ? 'Login va parol orqali tizimga kira oladi'
                                : 'Faqat ro‘yxatda (dasturga kirmaydi, login/parol shart emas)',
                            style: TextStyle(
                              fontSize: 11,
                              color: _canLogin ? AppColors.green : context.mutedColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _canLogin,
                      activeColor: AppColors.green,
                      onChanged: (_role == Role.admin || _role == Role.kassir)
                          ? null
                          : (v) => setState(() => _canLogin = v),
                    ),
                  ],
                ),
              ),

              // 4. Login & Parol maydonlari (agar dasturga kirishi kerak bo'lsa)
              if (_canLogin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _userCtrl,
                  enabled: !_isEditing,
                  decoration: InputDecoration(
                    labelText: 'Login (foydalanuvchi nomi)',
                    hintText: 'masalan: bobur_uz',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    helperText: _isEditing ? 'Loginni o‘zgartirib bo‘lmaydi' : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _isEditing ? 'Yangi parol (ixtiyoriy)' : 'Parol',
                    hintText: _isEditing ? 'O‘zgartirmaslik uchun bo‘sh qoldiring' : 'Kamida 6 ta belgi',
                    prefixIcon: const Icon(Icons.password_rounded),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (context.isDark ? AppColors.neonLime : const Color(0xFF16A34A)).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (context.isDark ? AppColors.neonLime : const Color(0xFF16A34A)).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: context.isDark ? AppColors.neonLime : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Xodim faqat ro‘yxatda saqlanadi. U ishlab chiqarish vazifalarida (kesish, faska, silliqlash), davomatda va oylik hisobida to‘liq qatnashadi, ammo dasturga kirish uchun login va parol talab etilmaydi.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: context.inkColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 5. Maosh stavkasi
              TextField(
                controller: _salaryCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maosh stavkasi (so‘m)',
                  hintText: '5000000',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // 6. Maosh hisoblash turi
              DropdownButtonFormField<String>(
                value: _salaryType,
                decoration: const InputDecoration(
                  labelText: 'Maosh hisoblash turi',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Oylik (oybay fixed)')),
                  DropdownMenuItem(value: 'daily', child: Text('Kunlik (kunbay stavka)')),
                  DropdownMenuItem(value: 'hourly', child: Text('Soatlik (soatbay stavka)')),
                ],
                onChanged: (v) => setState(() => _salaryType = v ?? 'monthly'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.pillColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Xodim holati', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              _isActive ? 'Faol xodim' : 'Hisob bloklangan',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isActive ? AppColors.green : AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isActive,
                        activeColor: AppColors.green,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF331616) : const Color(0xFFFFECEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
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
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: context.isDark ? AppColors.neonLime : AppColors.darkCard,
            foregroundColor: context.isDark ? AppColors.ink : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Saqlash' : 'Qo‘shish', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Davomatni tahrirlash dialogi
// ---------------------------------------------------------------------------

class AttendanceDialog extends StatefulWidget {
  const AttendanceDialog({
    super.key,
    required this.repo,
    required this.user,
    required this.date,
    this.record,
  });

  final AttendanceRepository repo;
  final AppUser user;
  final String date;
  final AttendanceRecord? record;

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late TimeOfDay _checkInTime;
  late TimeOfDay _checkOutTime;
  late String _status = widget.record?.status ?? 'present';
  late final _noteCtrl = TextEditingController(text: widget.record?.note ?? '');
  bool _hasCheckIn = false;
  bool _hasCheckOut = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.record?.checkIn != null) {
      _hasCheckIn = true;
      _checkInTime = TimeOfDay.fromDateTime(widget.record!.checkIn!);
    } else {
      _checkInTime = const TimeOfDay(hour: 8, minute: 30);
    }

    if (widget.record?.checkOut != null) {
      _hasCheckOut = true;
      _checkOutTime = TimeOfDay.fromDateTime(widget.record!.checkOut!);
    } else {
      _checkOutTime = const TimeOfDay(hour: 18, minute: 0);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);

    DateTime? inDt;
    DateTime? outDt;
    final parts = widget.date.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    if (_hasCheckIn) {
      inDt = DateTime(y, m, d, _checkInTime.hour, _checkInTime.minute);
    }
    if (_hasCheckOut) {
      outDt = DateTime(y, m, d, _checkOutTime.hour, _checkOutTime.minute);
    }

    double worked = 0;
    if (inDt != null && outDt != null) {
      worked = double.parse((outDt.difference(inDt).inMinutes / 60.0).clamp(0.0, 24.0).toStringAsFixed(1));
    }

    final rec = AttendanceRecord(
      id: widget.record?.id ?? 0,
      userId: widget.user.id,
      userName: widget.user.fullName,
      date: widget.date,
      checkIn: inDt,
      checkOut: outDt,
      workedHours: worked,
      status: _status,
      note: _noteCtrl.text.trim(),
    );

    try {
      await widget.repo.saveRecord(rec);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, 'Xatolik: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.access_time_rounded, color: AppColors.darkCard, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${widget.date} davomati', style: TextStyle(fontSize: 12, color: context.mutedColor)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kelish vaqti
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Kelgan vaqti: ${_checkInTime.format(context)}'),
                value: _hasCheckIn,
                onChanged: (v) => setState(() => _hasCheckIn = v ?? false),
                secondary: IconButton(
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _checkInTime);
                    if (t != null) setState(() => _checkInTime = t);
                  },
                ),
              ),
              // Ketish vaqti
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Ketgan vaqti: ${_checkOutTime.format(context)}'),
                value: _hasCheckOut,
                onChanged: (v) => setState(() => _hasCheckOut = v ?? false),
                secondary: IconButton(
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _checkOutTime);
                    if (t != null) setState(() => _checkOutTime = t);
                  },
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Davomat holati'),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('✓ Kelgan (Vaqtida)')),
                  DropdownMenuItem(value: 'late', child: Text('⚠ Kechikkan')),
                  DropdownMenuItem(value: 'half_day', child: Text('⏱ Yarim kun')),
                  DropdownMenuItem(value: 'absent', child: Text('✕ Kelmagan')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'present'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Izoh / Sababi',
                  hintText: 'masalan: Navbatchilikda bo‘ldi, ruxsat olgan...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.neonLime,
            foregroundColor: AppColors.ink,
          ),
          child: const Text('Saqlash', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
