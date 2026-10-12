import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class PendingRegistrationsScreen extends StatefulWidget {
  final UserModel? adminUser;
  final bool seedInitialData;

  const PendingRegistrationsScreen({
    super.key,
    this.adminUser,
    this.seedInitialData = true,
  });

  @override
  State<PendingRegistrationsScreen> createState() =>
      _PendingRegistrationsScreenState();
}

class _PendingRegistrationsScreenState
    extends State<PendingRegistrationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  UserRole _selectedRole = UserRole.supervisor;
  final Map<String, String> _selectedWards = {};
  List<WardModel> _availableWards = [];
  bool _isLoadingWards = true;
  final Set<String> _processingUserIds = {};
  final Set<String> _removedUserIds = {};
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.adminUser;
    _resolveCurrentUser();
    _initData();
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

    final adminInMem = AuthService().registeredUsers.where((u) => u.role == UserRole.admin);
    if (adminInMem.isNotEmpty && mounted) {
      setState(() {
        _currentUser = adminInMem.first;
      });
    }
  }

  Future<void> _initData() async {
    if (widget.seedInitialData) {
      final existingUsers = await _firestoreService.getUsersByStatus(UserStatus.pending);
      if (existingUsers.isEmpty) {
        _firestoreService.seedDemoPendingUsers();
      }
    }

    final wards = await _firestoreService.getWards();
    if (mounted) {
      setState(() {
        _availableWards = wards;
        _isLoadingWards = false;
      });
    }
  }

  String _getUserInitials() {
    final user = _currentUser ?? widget.adminUser;
    if (user != null && user.name.trim().isNotEmpty) {
      return user.name.trim().substring(0, 1).toUpperCase();
    }
    if (AuthService().isFirebaseAvailable) {
      final fbName = AuthService().auth.currentUser?.displayName;
      if (fbName != null && fbName.trim().isNotEmpty) {
        return fbName.trim().substring(0, 1).toUpperCase();
      }
      final email = AuthService().auth.currentUser?.email;
      if (email != null && email.trim().isNotEmpty) {
        return email.trim().substring(0, 1).toUpperCase();
      }
    }
    final adminInMem = AuthService().registeredUsers.where((u) => u.role == UserRole.admin);
    if (adminInMem.isNotEmpty && adminInMem.first.name.trim().isNotEmpty) {
      return adminInMem.first.name.trim().substring(0, 1).toUpperCase();
    }
    return 'A';
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

  String _getWardDisplayName(String wardId) {
    final match = _availableWards.where((w) => w.wardId == wardId);
    if (match.isNotEmpty) {
      return match.first.name;
    }
    return wardId;
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
                child: Icon(Icons.person_add_alt_1_outlined, size: 18, color: Color(0xFF0F172A)),
              ),
              title: Text(
                'Pending Registrations',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Newly registered personnel require ward assignment to activate their CleanTrack accounts.',
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
                'All database services are operational.',
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

  Future<void> _confirmRejectUser(UserModel user) async {
    final roleTitle = user.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Text(
                'Reject Registration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to reject $roleTitle ${user.name} (${user.employeeId}) and delete this account from the database? This action cannot be undone.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              key: const Key('confirmRejectDialogButton'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text(
                'Reject & Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) return;

    setState(() {
      _processingUserIds.add(user.userId);
      _removedUserIds.add(user.userId);
      if (user.employeeId.isNotEmpty) {
        _removedUserIds.add(user.employeeId);
      }
      if (user.email.isNotEmpty) {
        _removedUserIds.add(user.email.toLowerCase());
      }
    });

    final success = await _firestoreService.deleteUser(
      user.userId,
      employeeId: user.employeeId,
      email: user.email,
    );

    if (!mounted) return;

    setState(() {
      _processingUserIds.remove(user.userId);
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Registration for $roleTitle ${user.name} was rejected and removed.',
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete user. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _assignWard(UserModel user) async {
    final effectiveWardId = _selectedWards[user.userId] ??
        (_availableWards.isNotEmpty ? _availableWards.first.wardId : '');

    if (effectiveWardId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a hospital ward first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _processingUserIds.add(user.userId);
    });

    final success = await _firestoreService.assignUserToWard(
      userId: user.userId,
      wardId: effectiveWardId,
      role: user.role,
    );

    if (!mounted) return;

    setState(() {
      _processingUserIds.remove(user.userId);
      if (success) {
        _removedUserIds.add(user.userId);
        if (user.employeeId.isNotEmpty) {
          _removedUserIds.add(user.employeeId);
        }
        if (user.email.isNotEmpty) {
          _removedUserIds.add(user.email.toLowerCase());
        }
      }
    });

    if (success) {
      final wardName = _getWardDisplayName(effectiveWardId);
      final roleTitle = user.role == UserRole.supervisor ? 'Supervisor' : 'Worker';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$roleTitle ${user.name} assigned to $wardName successfully.',
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign ward. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          key: const Key('awaitingActivationBackButton'),
          color: const Color(0xFF0F172A),
          onPressed: _handleBackNavigation,
        ),
        title: const Text(
          'Awaiting Activation',
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
            key: const Key('awaitingActivationNotificationButton'),
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
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 16),
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
      body: SafeArea(
        child: Column(
          children: [
            // Role Selection Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRolePill(
                      role: UserRole.supervisor,
                      label: 'Supervisor',
                      key: const Key('roleToggleSupervisor'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRolePill(
                      role: UserRole.worker,
                      label: 'Worker',
                      key: const Key('roleToggleWorker'),
                    ),
                  ),
                ],
              ),
            ),

            // Pending Users List Stream
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _firestoreService.streamPendingUsers(role: _selectedRole),
                builder: (context, snapshot) {
                  if (_isLoadingWards && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                      ),
                    );
                  }

                  final users = snapshot.data ?? [];
                  final pendingUsers = users.where((u) {
                    if (u.status != UserStatus.pending) return false;
                    if (u.role != _selectedRole) return false;
                    if (_removedUserIds.contains(u.userId)) return false;
                    if (u.employeeId.isNotEmpty && _removedUserIds.contains(u.employeeId)) return false;
                    if (u.email.isNotEmpty && _removedUserIds.contains(u.email.toLowerCase())) return false;
                    return true;
                  }).toList();

                  if (pendingUsers.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: pendingUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildUserCard(pendingUsers[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill({
    required UserRole role,
    required String label,
    required Key key,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      key: key,
      onTap: () {
        if (_selectedRole != role) {
          setState(() {
            _selectedRole = role;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final effectiveWardId = _selectedWards[user.userId] ??
        (_availableWards.isNotEmpty ? _availableWards.first.wardId : null);
    final isProcessing = _processingUserIds.contains(user.userId);

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
          // Applicant Name
          Text(
            user.name.isNotEmpty ? user.name : 'Applicant',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Employee ID with Badge icon
          Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                'ID: ${user.employeeId}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Select Ward Label
          const Text(
            'Select Ward',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),

          // Ward Selection Dropdown
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                width: 1.2,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: Key('wardDropdown_${user.userId}'),
                isExpanded: true,
                value: effectiveWardId,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                hint: const Text(
                  'Select Ward',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                items: _availableWards.map((ward) {
                  return DropdownMenuItem<String>(
                    value: ward.wardId,
                    child: Text(
                      ward.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newWardId) {
                  if (newWardId != null) {
                    setState(() {
                      _selectedWards[user.userId] = newWardId;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: REJECT & ASSIGN WARD
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: Key('rejectUserButton_${user.userId}'),
                    onPressed: isProcessing ? null : () => _confirmRejectUser(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                      backgroundColor: const Color(0xFFFEF2F2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'REJECT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    key: Key('assignWardButton_${user.userId}'),
                    onPressed: isProcessing ? null : () => _assignWard(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: isProcessing
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
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'ASSIGN WARD',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final roleName = _selectedRole == UserRole.supervisor ? 'Supervisors' : 'Workers';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.how_to_reg_outlined,
                size: 40,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No $roleName Pending Activation',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All registered ${_selectedRole.displayName.toLowerCase()}s have been assigned to hospital wards.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
