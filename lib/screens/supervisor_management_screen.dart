import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'admin_dashboard_screen.dart';

class SupervisorManagementScreen extends StatefulWidget {
  final UserModel? adminUser;
  final FirestoreService? firestoreService;

  const SupervisorManagementScreen({
    super.key,
    this.adminUser,
    this.firestoreService,
  });

  @override
  State<SupervisorManagementScreen> createState() =>
      _SupervisorManagementScreenState();
}

class _SupervisorManagementScreenState
    extends State<SupervisorManagementScreen> {
  late final FirestoreService _firestoreService;
  UserModel? _adminUser;
  List<UserModel> _supervisors = [];
  Map<String, int> _workerCounts = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _adminUser = widget.adminUser;
    _resolveAdmin();
    _loadSupervisors();
  }

  Future<void> _resolveAdmin() async {
    if (_adminUser != null && _adminUser!.name.trim().isNotEmpty) return;
    if (AuthService().isFirebaseAvailable) {
      final firebaseUser = AuthService().auth.currentUser;
      if (firebaseUser != null) {
        final profile = await _firestoreService.getUserProfile(
          firebaseUser.uid,
        );
        if (mounted && profile != null) {
          setState(() => _adminUser = profile);
        }
      }
    }
  }

  Future<void> _loadSupervisors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _firestoreService.getSupervisors(),
        _firestoreService.getWorkerCountsByWard(),
      ]);
      if (!mounted) return;
      setState(() {
        _supervisors = (results[0] as List<UserModel>)
            .where((supervisor) => supervisor.status == UserStatus.assigned)
            .toList();
        _workerCounts = results[1] as Map<String, int>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load supervisors. Please try again.';
        _isLoading = false;
      });
      debugPrint('Supervisor management load failed: $error');
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

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  String _adminInitials() => getUserInitials(_adminUser?.name);

  String _wardName(UserModel supervisor) {
    final ward = supervisor.wardName?.trim();
    if (ward != null && ward.isNotEmpty) return formatWardDisplayName(ward);
    final wardId = supervisor.wardId?.trim();
    if (wardId != null && wardId.isNotEmpty) {
      return formatWardDisplayName(wardId);
    }
    return 'Awaiting ward assignment';
  }

  int _workerCount(UserModel supervisor) {
    final wardId = supervisor.wardId?.trim();
    final wardName = supervisor.wardName?.trim();
    return _workerCounts[wardId] ??
        _workerCounts[wardName] ??
        (wardId == null ? 0 : _workerCounts[formatWardDisplayName(wardId)]) ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: _loadSupervisors,
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 64,
      leading: BackButton(
        key: const Key('supervisorManagementBackButton'),
        color: const Color(0xFF0F172A),
        onPressed: _handleBackNavigation,
      ),
      title: const Text(
        'Supervisor Management',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          key: const Key('supervisorManagementNotificationButton'),
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF0F172A),
          ),
          tooltip: 'Notifications',
          onPressed: () {},
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          key: const Key('supervisorManagementProfileButton'),
          tooltip: 'Admin profile',
          offset: const Offset(0, 48),
          onSelected: (value) {
            if (value == 'logout') _handleLogout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Text(
                _adminUser?.name.trim().isNotEmpty == true
                    ? _adminUser!.name
                    : 'Admin',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                  Text('LOG OUT'),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0F172A),
            child: Text(
              _adminInitials(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          Center(child: Text(_errorMessage!)),
          TextButton(onPressed: _loadSupervisors, child: const Text('RETRY')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supervisors',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ward leads and workforce coverage',
                    style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            _countBadge(_supervisors.length),
          ],
        ),
        const SizedBox(height: 18),
        if (_supervisors.isEmpty)
          _emptyState()
        else
          ..._supervisors.map(_buildSupervisorCard),
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      width: 66,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'TOTAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(UserModel supervisor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(name: supervisor.name, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supervisor.name.isEmpty
                            ? 'Unnamed supervisor'
                            : supervisor.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${supervisor.employeeId}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_center_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Assigned ward',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _wardName(supervisor),
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_workerCount(supervisor)}',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 64),
      child: Center(
        child: Text(
          'No supervisors found',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}
