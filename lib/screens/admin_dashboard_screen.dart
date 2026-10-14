import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'pending_registrations_screen.dart';
import 'supervisor_management_screen.dart';
import 'ward_management_screen.dart';
import 'worker_management_screen.dart';
import 'monthly_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel? user;
  final FirestoreService? firestoreService;

  const AdminDashboardScreen({
    super.key,
    this.user,
    this.firestoreService,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Stream<AdminDashboardStats> _statsStream;
  UserModel? _loadedUser;

  @override
  void initState() {
    super.initState();
    _loadedUser = widget.user;
    _resolveCurrentUser();
    _initStatsStream();
  }

  void _initStatsStream() {
    final service = widget.firestoreService ?? FirestoreService();
    _statsStream = service.streamAdminDashboardStats();
  }

  Future<void> _resolveCurrentUser() async {
    if (_loadedUser != null && _loadedUser!.name.trim().isNotEmpty) return;

    if (AuthService().isFirebaseAvailable) {
      final fbUser = AuthService().auth.currentUser;
      if (fbUser != null) {
        final profile = await FirestoreService().getUserProfile(fbUser.uid);
        if (mounted && profile != null) {
          setState(() {
            _loadedUser = profile;
          });
          return;
        }
      }
    }

    if (_loadedUser == null && widget.user != null) {
      setState(() {
        _loadedUser = widget.user;
      });
    }
  }

  UserModel? get _currentUser => _loadedUser ?? widget.user;

  String _getEffectiveUserName() {
    final user = _currentUser;
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

  String _getUserInitials() {
    final name = _getEffectiveUserName();
    if (name.isEmpty) return 'A';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'A';
  }

  String _getCurrentMonthPerformance() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year} performance';
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

  void _showComingSoonSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title module is coming up next.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'CleanTrack',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'HOSPITAL HOUSEKEEPING MANAGEMENT',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                    tooltip: 'Notifications',
                    onPressed: () {
                      _showComingSoonSnackBar('Notifications');
                    },
                  ),
                  const SizedBox(width: 4),
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
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (_loadedUser ?? widget.user)?.name ?? 'Admin User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              (_loadedUser ?? widget.user)?.email ?? 'admin@cleantrack.org',
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
                    ],
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getUserInitials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<AdminDashboardStats>(
        stream: _statsStream,
        initialData: const AdminDashboardStats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? const AdminDashboardStats();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hospital workforce overview',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // WORKFORCE SNAPSHOT Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'WORKFORCE SNAPSHOT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            InkWell(
                              key: const Key('syncSnapshotButton'),
                              onTap: () {
                                setState(() {
                                  _initStatsStream();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Workforce snapshot refreshed.'),
                                    backgroundColor: Color(0xFF16A34A),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatColumn(
                              icon: Icons.apartment_rounded,
                              value: stats.totalWards.toString(),
                              label: 'TOTAL WARDS',
                            ),
                            _buildStatColumn(
                              icon: Icons.manage_accounts_outlined,
                              value: stats.totalSupervisors.toString(),
                              label: 'SUPERVISORS',
                            ),
                            _buildStatColumn(
                              icon: Icons.groups_outlined,
                              value: stats.totalWorkers.toString(),
                              label: 'WORKERS',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QUICK MANAGEMENT Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'QUICK MANAGEMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '5 destinations',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5 Destinations
                  _buildQuickActionTile(
                    context: context,
                    key: const Key('pendingRegistrationsTile'),
                    icon: Icons.person_add_alt_outlined,
                    title: 'Pending registrations',
                    badgeCount: stats.pendingRegistrations > 0
                        ? stats.pendingRegistrations
                        : null,
                    subtitle: 'Review and assign personnel',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PendingRegistrationsScreen(adminUser: widget.user),
                        ),
                      );
                      if (mounted) {
                        setState(() {
                          _initStatsStream();
                        });
                      }
                    },
                  ),
                  _buildQuickActionTile(
                    context: context,
                    key: const Key('supervisorManagementTile'),
                    icon: Icons.manage_accounts_outlined,
                    title: 'Supervisor management',
                    subtitle: 'Wards, teams and account status',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupervisorManagementScreen(),
                      ),
                    ),
                  ),
                  _buildQuickActionTile(
                    context: context,
                    key: const Key('wardManagementTile'),
                    icon: Icons.apartment_rounded,
                    title: 'Ward management',
                    subtitle: 'Coverage across ${stats.totalWards} wards',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WardManagementScreen(),
                      ),
                    ),
                  ),
                  _buildQuickActionTile(
                    context: context,
                    key: const Key('workerManagementTile'),
                    icon: Icons.groups_outlined,
                    title: 'Worker management',
                    subtitle: 'Roster, status and suspensions',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerManagementScreen(adminUser: _currentUser),
                      ),
                    ),
                  ),
                  _buildQuickActionTile(
                    context: context,
                    key: const Key('monthlyReportsTile'),
                    icon: Icons.description_outlined,
                    title: 'Monthly ward reports',
                    subtitle: _getCurrentMonthPerformance(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonthlyReportsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (badgeCount != null && badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
