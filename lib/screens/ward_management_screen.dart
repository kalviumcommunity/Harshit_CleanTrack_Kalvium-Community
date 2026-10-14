import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class WardManagementScreen extends StatefulWidget {
  final UserModel? adminUser;
  final FirestoreService? firestoreService;

  const WardManagementScreen({
    super.key,
    this.adminUser,
    this.firestoreService,
  });

  @override
  State<WardManagementScreen> createState() => _WardManagementScreenState();
}

class _WardManagementScreenState extends State<WardManagementScreen> {
  late final FirestoreService _firestoreService;
  final TextEditingController _wardNameController = TextEditingController();

  bool _isCreating = false;
  bool _isLoading = true;
  List<WardModel> _wards = [];
  Map<String, int> _workerCounts = {};
  Map<String, String> _supervisorNames = {};
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _currentUser = widget.adminUser;
    _resolveCurrentUser();
    _loadWardsData();
  }

  @override
  void dispose() {
    _wardNameController.dispose();
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

  Future<void> _loadWardsData() async {
    final wards = await _firestoreService.getWards();
    final workerCounts = await _firestoreService.getWorkerCountsByWard();
    final supervisorNames = await _firestoreService.getSupervisorNames();

    if (mounted) {
      setState(() {
        _wards = wards;
        _workerCounts = workerCounts;
        _supervisorNames = supervisorNames;
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
                child: Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF0F172A)),
              ),
              title: Text(
                'Ward Coverage Active',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'All hospital departments and specialized wards are monitored in real time.',
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
                'System Status',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'All ward database registries are synchronized.',
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

  Future<void> _handleCreateWard() async {
    final rawName = _wardNameController.text.trim();
    if (rawName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a ward name.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formattedName = formatWardDisplayName(rawName);
    final exists = _wards.any((w) =>
        w.name.toLowerCase() == formattedName.toLowerCase() ||
        w.name.toLowerCase() == rawName.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ward "$formattedName" already exists.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final createdWard = await _firestoreService.createWard(rawName);

    if (!mounted) return;

    setState(() {
      _isCreating = false;
      if (createdWard != null) {
        _wardNameController.clear();
      }
    });

    if (createdWard != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ward "${createdWard.name}" created successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadWardsData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create ward. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _getWorkerCount(WardModel ward) {
    if (_workerCounts.containsKey(ward.wardId)) {
      return _workerCounts[ward.wardId]!;
    }
    if (_workerCounts.containsKey(ward.name)) {
      return _workerCounts[ward.name]!;
    }
    return 0;
  }

  String? _getSupervisorName(WardModel ward) {
    if (ward.supervisorId != null && ward.supervisorId!.trim().isNotEmpty) {
      final name = _supervisorNames[ward.supervisorId!.trim()];
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    if (_supervisorNames.containsKey(ward.wardId)) {
      final name = _supervisorNames[ward.wardId];
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    if (_supervisorNames.containsKey(ward.name)) {
      final name = _supervisorNames[ward.name];
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: BackButton(
          key: const Key('wardManagementBackButton'),
          color: const Color(0xFF0F172A),
          onPressed: _handleBackNavigation,
        ),
        title: const Text(
          'Ward Management',
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
            key: const Key('wardManagementNotificationButton'),
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
          onRefresh: _loadWardsData,
          color: const Color(0xFF0F172A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Create Ward Card
                _buildCreateWardCard(),
                const SizedBox(height: 24),

                // Wards Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Wards',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_wards.length} ${_wards.length == 1 ? 'Ward' : 'Wards'}',
                        key: const Key('totalWardsCountPill'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Wards List
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                      ),
                    ),
                  )
                else if (_wards.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _wards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return _buildWardCard(_wards[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWardCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.domain_add_rounded,
                size: 22,
                color: Color(0xFF0F172A),
              ),
              SizedBox(width: 8),
              Text(
                'Create Ward',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Ward Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _wardNameController,
            key: const Key('wardNameInput'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleCreateWard(),
            decoration: InputDecoration(
              hintText: 'e.g. Ward B',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('createWardButton'),
              onPressed: _isCreating ? null : _handleCreateWard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'CREATE WARD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardCard(WardModel ward) {
    final workerCount = _getWorkerCount(ward);
    final supervisorName = _getSupervisorName(ward);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with Ward Name and Workers count
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WARD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ward.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 16,
                        color: Color(0xFF1E3A8A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$workerCount ${workerCount == 1 ? 'Worker' : 'Workers'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom banner with Supervisor info or Not Assigned badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Supervisor',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
                if (supervisorName != null && supervisorName.isNotEmpty)
                  Text(
                    supervisorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Color(0xFFDC2626),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Not Assigned',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: const [
            Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No wards found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create a ward above to begin.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
