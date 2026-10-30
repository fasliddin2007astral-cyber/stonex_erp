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
  Future<void> _checkIn(AppUser user) async {
    try {
      final now = DateTime.now();
      await _attRepo.checkIn(user.id, time: now);
      if (mounted) {
        showMessage(
          context,
          '✓ ${user.fullName} keldi deb qayd etildi (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})',
        );
        _reloadAttendance();
        _reloadSalary();
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Xatolik: $e', error: true);
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
  // Top Tabs
  // ---------------------------------------------------------------------------
  Widget _buildTopTabs() {
    final tabs = [
      ('Xodimlar', Icons.people_alt_rounded),
      ('Davomat (Keldi / Ketdi)', Icons.access_time_rounded),
      ('Oylik hisobi', Icons.account_balance_wallet_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              InkWell(
                onTap: () => setState(() => _currentTab = i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTab == i
                        ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                        : context.pillColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentTab == i
                          ? (context.isDark ? AppColors.neonLime : AppColors.darkCard)
                          : context.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].$2,
                        size: 16,
                        color: _currentTab == i
                            ? (context.isDark ? AppColors.ink : Colors.white)
                            : context.mutedColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tabs[i].$1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _currentTab == i ? FontWeight.w800 : FontWeight.w600,
                          color: _currentTab == i
                              ? (context.isDark ? AppColors.ink : Colors.white)
                              : context.mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: Xodimlar Ro'yxati
  // ---------------------------------------------------------------------------
  Widget _buildUsersTab() {
    final filterOptions = ['Barchasi', 'Adminlar', 'Kassirlar', 'Ishchilar', 'Bloklanganlar'];

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
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '@${u.username}',
                      style: TextStyle(fontSize: 11.5, color: context.mutedColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·  Maosh: ${money(u.salary)} (${u.salaryType == "daily" ? "kunbay" : (u.salaryType == "hourly" ? "soatbay" : "oylik")})',
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
  // TAB 1: Davomat (Keldi / Ketdi)
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
        final absentCount = totalActive - (presentCount + lateCount);

        return RefreshIndicator(
          onRefresh: () async => _reloadAttendance(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Sana tanlash paneli
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
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                          _reloadAttendance();
                        });
                      },
                      tooltip: 'Oldingi kun',
                    ),
                    Expanded(
                      child: InkWell(
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.neonLime),
                            const SizedBox(width: 8),
                            Text(
                              '$_dateStr ${_isToday(_selectedDate) ? "(Bugun)" : ""}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.inkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                          _reloadAttendance();
                        });
                      },
                      tooltip: 'Keyingi kun',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // KPI kartalari
              Row(
                children: [
                  _buildKpiCard('Jami xodimlar', '$totalActive ta', Icons.people_outline_rounded, AppColors.ink),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kelganlar', '$presentCount ta', Icons.check_circle_outline_rounded, AppColors.green),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kechikkanlar', '$lateCount ta', Icons.warning_amber_rounded, const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _buildKpiCard('Kelmaganlar', '${absentCount < 0 ? 0 : absentCount} ta', Icons.cancel_outlined, AppColors.danger),
                ],
              ),
              const SizedBox(height: 14),

              // Xodimlar davomat kartalari
              for (final u in users) _buildAttendanceRow(u, attMap[u.id]),
            ],
          ),
        );
      },
    );
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
    if (isLate) {
      statusText = 'Kechikkan';
      statusColor = const Color(0xFFD97706);
    } else if (hasCheckedIn) {
      statusText = 'Kelgan';
      statusColor = AppColors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasCheckedIn
              ? (isLate ? const Color(0xFFD97706).withValues(alpha: 0.35) : AppColors.green.withValues(alpha: 0.3))
              : context.borderColor,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(
              hasCheckedIn ? (isLate ? Icons.timer_outlined : Icons.check_rounded) : Icons.close_rounded,
              color: statusColor,
              size: 18,
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
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.inkColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (hasCheckedIn)
                      Text(
                        'Keldi: ${_formatTime(att!.checkIn!)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                      )
                    else
                      Text('Kirish qayd etilmagan', style: TextStyle(fontSize: 11, color: context.mutedColor)),
                    if (hasCheckedOut) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· Ketdi: ${_formatTime(att!.checkOut!)} (${att.workedHours.toStringAsFixed(1)} soat)',
                        style: TextStyle(fontSize: 11, color: context.inkColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Harakat tugmalari
          if (!hasCheckedIn)
            FilledButton.icon(
              onPressed: () => _checkIn(u),
              icon: const Icon(Icons.login_rounded, size: 14),
              label: const Text('Keldi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            )
          else if (!hasCheckedOut)
            FilledButton.icon(
              onPressed: () => _checkOut(u),
              icon: const Icon(Icons.logout_rounded, size: 14),
              label: const Text('Ketdi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            onPressed: () => _editAttendance(u, att),
            tooltip: 'Davomatni to‘liq tahrirlash',
          ),
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
    final u = _userCtrl.text.trim();
    final n = _nameCtrl.text.trim();
    final p = _passCtrl.text;
    final sal = double.tryParse(_salaryCtrl.text.replaceAll(' ', '')) ?? 0;

    if (u.isEmpty || n.isEmpty) {
      setState(() {
        _error = 'Login va to‘liq ismni kiriting';
      });
      return;
    }

    if (!_isEditing && p.isEmpty) {
      setState(() {
        _error = 'Yangi xodim uchun parol kiritish shart';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.repo.update(
          widget.user!.id,
          fullName: n,
          password: p.isNotEmpty ? p : null,
          role: _role,
          salary: sal,
          salaryType: _salaryType,
          isActive: _isActive,
        );
      } else {
        await widget.repo.create(
          username: u,
          fullName: n,
          password: p,
          role: _role,
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
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _userCtrl,
                enabled: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'Login (foydalanuvchi nomi)',
                  hintText: 'masalan: bobur_uz',
                  helperText: _isEditing ? 'Loginni o‘zgartirib bo‘lmaydi' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'To‘liq ismi (F.I.O)',
                  hintText: 'masalan: Bobur Rahimov',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEditing ? 'Yangi parol (ixtiyoriy)' : 'Parol',
                  hintText: _isEditing ? 'O‘zgartirmaslik uchun bo‘sh qoldiring' : 'Kamida 6 ta belgi',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Role>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Tizimdagi roli'),
                items: Role.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _role = v ?? _role;
                  });
                },
              ),
              const SizedBox(height: 12),
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
              DropdownButtonFormField<String>(
                value: _salaryType,
                decoration: const InputDecoration(labelText: 'Maosh hisoblash turi'),
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
                              _isActive ? 'Tizimga kirishga ruxsat berilgan' : 'Hisob bloklangan',
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
