import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class WorkerManagementScreen extends StatefulWidget {
  final UserModel? adminUser;
  final FirestoreService? firestoreService;

  const WorkerManagementScreen({
    super.key,
    this.adminUser,
    this.firestoreService,
  });

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen> {
  late final FirestoreService _firestoreService;
  UserModel? _currentUser;

  List<WardModel> _wards = [];
  List<UserModel> _workers = [];
  String _selectedWardFilter = 'all';
  bool _isLoading = true;

  StreamSubscription<List<WardModel>>? _wardsSub;
  StreamSubscription<List<UserModel>>? _workersSub;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _currentUser = widget.adminUser;
    _resolveCurrentUser();
    _subscribeData();
  }

  @override
  void dispose() {
    _wardsSub?.cancel();
    _workersSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveCurrentUser() async {
    if (_currentUser != null && _currentUser!.name.trim().isNotEmpty) return;

    if (AuthService().isFirebaseAvailable) {
      final fbUser = AuthService().auth.currentUser;
      if (fbUser != null) {
        final profile = await _firestoreService.getUserProfile(fbUser.uid);
        if (mounted && profile != null) {
          setState(() {
            _currentUser = profile;
          });
          return;
        }
      }
    }

    if (_currentUser == null && widget.adminUser != null) {
      setState(() {
        _currentUser = widget.adminUser;
      });
    }
  }

  void _subscribeData() {
    _wardsSub = _firestoreService.streamWards().listen((wards) {
      if (mounted) {
        setState(() {
          _wards = wards;
        });
      }
    });

    _workersSub = _firestoreService.streamWorkersByWard('').listen((workers) {
      if (mounted) {
        setState(() {
          _workers = workers;
          _isLoading = false;
        });
      }
    });

    // Also fetch initial data directly for fast offline/test mode response
    _loadData();
  }

  Future<void> _loadData() async {
    final wards = await _firestoreService.getWards();
    final workers = await _firestoreService.getWorkersByWard('');

    if (mounted) {
      setState(() {
        _wards = wards;
        _workers = workers;
        _isLoading = false;
      });
    }
  }

  String _getEffectiveUserName() {
    final user = _currentUser ?? widget.adminUser;
    if (user != null && user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    if (AuthService().isFirebaseAvailable) {
      final fbName = AuthService().auth.currentUser?.displayName;
      if (fbName != null && fbName.trim().isNotEmpty) {
        return fbName.trim();
      }
      final email = AuthService().auth.currentUser?.email;
      if (email != null && email.contains('@')) {
        final prefix = email.split('@').first;
        final parts = prefix.replaceAll(RegExp(r'[._\d]'), ' ').trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          return parts.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
        }
      }
    }
    return 'Admin';
  }

  void _handleLogout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleBackNavigation() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(user: widget.adminUser),
        ),
      );
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.notifications_active_outlined, color: Color(0xFF0F172A), size: 22),
            SizedBox(width: 8),
            Text(
              'Admin Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF0F172A)),
              ),
              title: Text(
                'Housekeeping Workforce',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'All hospital housekeeping staff and ward rosters are monitored.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            Divider(color: Color(0xFFE2E8F0)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFECFDF5),
                child: Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF10B981)),
              ),
              title: Text(
                'Staff Roster Live',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Worker statuses, active tasks, and assignments are up to date.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  List<WardModel> get _assignedWards {
    return _wards.where((w) {
      final hasId = w.supervisorId != null && w.supervisorId!.trim().isNotEmpty;
      final hasRef = w.supervisorRef != null;
      return hasId || hasRef;
    }).toList();
  }

  List<UserModel> get _verifiedWorkers {
    return sortWorkersByStatus(_workers.where((w) => w.status != UserStatus.pending));
  }

  List<UserModel> get _filteredWorkers {
    final baseWorkers = _verifiedWorkers;
    if (_selectedWardFilter == 'all') {
      return baseWorkers;
    }
    return sortWorkersByStatus(baseWorkers.where((w) {
      if (w.wardId != null && w.wardId == _selectedWardFilter) return true;
      if (w.wardName != null && w.wardName!.toLowerCase() == _selectedWardFilter.toLowerCase()) return true;

      final matchedWard = _assignedWards.firstWhere(
        (ward) => ward.wardId == _selectedWardFilter,
        orElse: () => WardModel(wardId: '', name: ''),
      );
      if (matchedWard.name.isNotEmpty) {
        if (w.wardName != null && w.wardName!.toLowerCase() == matchedWard.name.toLowerCase()) return true;
        if (w.wardId != null && w.wardId!.toLowerCase() == matchedWard.name.toLowerCase()) return true;
      }
      return false;
    }));
  }

  int _countWorkersForWard(WardModel ward) {
    return _verifiedWorkers.where((w) {
      if (w.wardId != null && w.wardId == ward.wardId) return true;
      if (w.wardName != null && w.wardName!.toLowerCase() == ward.name.toLowerCase()) return true;
      if (w.wardId != null && w.wardId!.toLowerCase() == ward.name.toLowerCase()) return true;
      return false;
    }).length;
  }

  String _getWardDisplayName(UserModel worker) {
    if (worker.wardName != null && worker.wardName!.trim().isNotEmpty) {
      return formatWardDisplayName(worker.wardName!);
    }
    if (worker.wardId != null && worker.wardId!.trim().isNotEmpty) {
      final match = _wards.where((w) => w.wardId == worker.wardId);
      if (match.isNotEmpty) {
        return match.first.name;
      }
      return formatWardDisplayName(worker.wardId!);
    }
    return 'Unassigned';
  }

  IconData _getWardIcon(String wardName) {
    final lower = wardName.toLowerCase();
    if (lower.contains('emergency')) {
      return Icons.emergency_outlined;
    }
    if (lower.contains('icu')) {
      return Icons.add_box_outlined;
    }
    if (lower.contains('ot') || lower.contains('operation')) {
      return Icons.medical_services_outlined;
    }
    return Icons.domain_rounded;
  }

  Widget _buildStatusPill(UserStatus status) {
    Color dotColor;
    String label;
    bool isUppercase = false;

    switch (status) {
      case UserStatus.available:
        dotColor = const Color(0xFF475569);
        label = 'Available';
        break;
      case UserStatus.busy:
        dotColor = const Color(0xFF94A3B8);
        label = 'Busy';
        break;
      case UserStatus.suspended:
        dotColor = const Color(0xFF0F172A);
        label = 'SUSPENDED';
        isUppercase = true;
        break;
      case UserStatus.pending:
        dotColor = const Color(0xFFEAB308);
        label = 'Pending';
        break;
      case UserStatus.assigned:
        dotColor = const Color(0xFF3B82F6);
        label = 'Assigned';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isUppercase ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF475569),
              letterSpacing: isUppercase ? 0.4 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardTabs() {
    final assignedWards = _assignedWards;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(
            key: const Key('wardChip_all'),
            label: 'All Wards (${_verifiedWorkers.length})',
            isSelected: _selectedWardFilter == 'all',
            onTap: () {
              setState(() {
                _selectedWardFilter = 'all';
              });
            },
          ),
          const SizedBox(width: 8),
          ...assignedWards.map((ward) {
            final count = _countWorkersForWard(ward);
            final isSelected = _selectedWardFilter == ward.wardId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                key: Key('wardChip_${ward.wardId}'),
                label: '${ward.name} ($count)',
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedWardFilter = ward.wardId;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerCard(UserModel worker) {
    final wardName = _getWardDisplayName(worker);
    final wardIcon = _getWardIcon(wardName);

    return Container(
      key: Key('workerCard_${worker.userId}'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: UserAvatar component
          UserAvatar(
            name: worker.name,
            size: 46,
            backgroundColor: const Color(0xFFF1F5F9),
            textColor: const Color(0xFF0F172A),
            fontSize: 15,
          ),
          const SizedBox(width: 14),

          // Middle: Worker details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ID: ${worker.employeeId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Icon(
                      wardIcon,
                      size: 14,
                      color: const Color(0xFF475569),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        wardName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Status badge
          _buildStatusPill(worker.status),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('workerEmptyState'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No workers found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedWardFilter == 'all'
                  ? 'No workers are currently registered in the hospital system.'
                  : 'No workers are currently assigned to this ward.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStaffCount = _verifiedWorkers.where((w) => w.status != UserStatus.suspended).length;
    final filteredWorkers = _filteredWorkers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: BackButton(
          key: const Key('workerManagementBackButton'),
          color: const Color(0xFF0F172A),
          onPressed: _handleBackNavigation,
        ),
        title: const Text(
          'Worker Management',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('workerManagementNotificationButton'),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0F172A),
              size: 24,
            ),
            tooltip: 'Notifications',
            onPressed: _showNotificationsDialog,
          ),
          PopupMenuButton<String>(
            key: const Key('adminLogoutButton'),
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) {
              final user = _currentUser ?? widget.adminUser;
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Admin User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        user?.email ?? 'admin@cleantrack.org',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'LOG OUT',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: UserAvatar(
                name: _getEffectiveUserName(),
                size: 38,
                backgroundColor: const Color(0xFF0F172A),
                textColor: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0F172A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Subheader row: Subtitle + Active Staff count badge
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Manage Hospital Workers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      key: const Key('activeStaffCountPill'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF334155),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$activeStaffCount Staff Active',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Ward Filter Tabs
              _buildWardTabs(),
              const SizedBox(height: 14),

              // Workers List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                        ),
                      )
                    : filteredWorkers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: _buildEmptyState(),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: filteredWorkers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildWorkerCard(filteredWorkers[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
