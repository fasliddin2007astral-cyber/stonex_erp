import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late Future<List<AppUser>> _future;
  String _selectedFilter = 'Barchasi';
  final _searchCtrl = TextEditingController();

  UserRepository get _repo => context.read<AppRepositories>().users;

  @override
  void initState() {
    super.initState();
    _future = _repo.list();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _future = _repo.list();
      });
    }
  }

  Future<void> _addUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => UserDialog(repo: _repo),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Yangi xodim muvaffaqiyatli qo‘shildi');
      _reload();
    }
  }

  Future<void> _editUser(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => UserDialog(repo: _repo, user: user),
    );
    if (ok == true && mounted) {
      showMessage(context, 'Xodim ma’lumotlari yangilandi');
      _reload();
    }
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final action = user.isActive ? 'bloklash' : 'faollashtirish';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
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
      await _repo.update(
        user.id,
        fullName: user.fullName,
        role: user.role,
        isActive: !user.isActive,
      );
      if (mounted) {
        showMessage(context, 'Xodim muvaffaqiyatli $action qilindi');
        _reload();
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Xatolik: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions = ['Barchasi', 'Adminlar', 'Kassirlar', 'Ishchilar', 'Bloklanganlar'];

    return Scaffold(
      backgroundColor: AppColors.panel,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.darkCard,
        foregroundColor: Colors.white,
        onPressed: _addUser,
        icon: const Icon(Icons.person_add_rounded, color: AppColors.neonLime),
        label: const Text('Xodim qo‘shish', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(message: snap.error.toString(), onRetry: _reload);
          }

          final allUsers = snap.data ?? [];

          // Statistika
          final totalCount = allUsers.length;
          final adminCount = allUsers.where((u) => u.role == Role.admin).length;
          final cashierCount = allUsers.where((u) => u.role == Role.kassir).length;
          final workerCount = allUsers.where((u) => u.role == Role.ishchi).length;
          final blockedCount = allUsers.where((u) => !u.isActive).length;

          // Filtr va Qidiruv
          var displayList = List<AppUser>.from(allUsers);
          if (_selectedFilter == 'Adminlar') {
            displayList = displayList.where((u) => u.role == Role.admin).toList();
          } else if (_selectedFilter == 'Kassirlar') {
            displayList = displayList.where((u) => u.role == Role.kassir).toList();
          } else if (_selectedFilter == 'Ishchilar') {
            displayList = displayList.where((u) => u.role == Role.ishchi).toList();
          } else if (_selectedFilter == 'Bloklanganlar') {
            displayList = displayList.where((u) => !u.isActive).toList();
          }

          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            displayList = displayList.where((u) {
              return u.fullName.toLowerCase().contains(q) ||
                  u.username.toLowerCase().contains(q) ||
                  u.role.label.toLowerCase().contains(q);
            }).toList();
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 80),
                  children: [
                    // 1. Yuqori statistika kartalari (Vault uslubida)
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStat(
                              'Jami Xodimlar',
                              '$totalCount nafar',
                              Icons.groups_rounded,
                              AppColors.neonLime,
                              true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Adminlar',
                              '$adminCount nafar',
                              Icons.admin_panel_settings_rounded,
                              const Color(0xFF1D3A2B),
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Kassirlar',
                              '$cashierCount nafar',
                              Icons.point_of_sale_rounded,
                              AppColors.green,
                              false,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStat(
                              'Ishchilar',
                              '$workerCount nafar',
                              Icons.precision_manufacturing_rounded,
                              const Color(0xFF245580),
                              false,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildStat('Jami Xodimlar', '$totalCount nafar', Icons.groups_rounded, AppColors.neonLime, true),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStat(
                              'Admin / Kassir',
                              '$adminCount / $cashierCount',
                              Icons.badge_rounded,
                              AppColors.green,
                              false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStat(
                              'Ishchilar',
                              '$workerCount nafar',
                              Icons.precision_manufacturing_rounded,
                              const Color(0xFF245580),
                              false,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 2. Qidiruv va Yangi Xodim qo'shish paneli
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Xodim ismi, login yoki lavozimi bo‘yicha...',
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
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _addUser,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkCard,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.add, size: 18, color: AppColors.neonLime),
                          label: const Text('Xodim qo‘shish', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Pill filtrlar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filterOptions.map((opt) {
                          final selected = _selectedFilter == opt;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                opt == 'Bloklanganlar' && blockedCount > 0 ? '$opt ($blockedCount)' : opt,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? Colors.white : AppColors.ink,
                                ),
                              ),
                              selected: selected,
                              selectedColor: AppColors.darkCard,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: selected ? AppColors.darkCard : AppColors.border,
                                ),
                              ),
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _selectedFilter = opt),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 4. Xodimlar ro'yxati
                    if (displayList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.badge_outlined, size: 48, color: AppColors.muted),
                            const SizedBox(height: 12),
                            const Text(
                              'Xodimlar topilmadi',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'Qidiruv so‘rovi bo‘yicha hech kim topilmadi'
                                  : 'Bu toifada hozircha xodimlar mavjud emas',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final u = displayList[index];
                          final initial = u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?';

                          Color roleColor;
                          IconData roleIcon;
                          switch (u.role) {
                            case Role.admin:
                              roleColor = const Color(0xFF1D3A2B);
                              roleIcon = Icons.shield_rounded;
                              break;
                            case Role.kassir:
                              roleColor = AppColors.green;
                              roleIcon = Icons.point_of_sale_rounded;
                              break;
                            case Role.ishchi:
                              roleColor = const Color(0xFF245580);
                              roleIcon = Icons.precision_manufacturing_rounded;
                              break;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Profil avatari
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: u.isActive
                                        ? roleColor.withValues(alpha: 0.12)
                                        : const Color(0xFFFFECEB),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: u.isActive ? roleColor : AppColors.danger,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // F.I.O va Login
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              u.fullName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: u.isActive ? AppColors.ink : AppColors.muted,
                                                decoration: u.isActive ? null : TextDecoration.lineThrough,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: roleColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(roleIcon, size: 11, color: roleColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  u.role.label,
                                                  style: TextStyle(
                                                    color: roleColor,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Login: @${u.username}',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                // Holat nishoni (Faol / Bloklangan)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: u.isActive
                                        ? AppColors.green.withValues(alpha: 0.12)
                                        : AppColors.danger.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: u.isActive ? AppColors.green : AppColors.danger,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        u.isActive ? 'Faol' : 'Bloklangan',
                                        style: TextStyle(
                                          color: u.isActive ? AppColors.green : AppColors.danger,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Boshqaruv tugmalari
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                      tooltip: 'Tahrirlash',
                                      onPressed: () => _editUser(u),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        u.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                        size: 19,
                                        color: u.isActive ? AppColors.danger : AppColors.green,
                                      ),
                                      tooltip: u.isActive ? 'Bloklash' : 'Faollashtirish',
                                      onPressed: () => _toggleUserStatus(u),
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
// Xodim qo'shish va tahrirlash dialogi (Vault uslubida)
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
  late Role _role = widget.user?.role ?? Role.ishchi;
  late bool _isActive = widget.user?.isActive ?? true;

  String? _error;
  bool _busy = false;

  bool get _isEditing => widget.user != null;

  @override
  void dispose() {
    _userCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _userCtrl.text.trim();
    final n = _nameCtrl.text.trim();
    final p = _passCtrl.text;

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
          isActive: _isActive,
        );
      } else {
        await widget.repo.create(
          username: u,
          fullName: n,
          password: p,
          role: _role,
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditing ? Icons.manage_accounts_rounded : Icons.person_add_rounded,
              color: AppColors.ink,
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
        width: 380,
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
              if (_isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
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
                      color: const Color(0xFFFFECEB),
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
            backgroundColor: AppColors.darkCard,
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
