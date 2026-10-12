import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final UserModel? user;
  final FirestoreService? firestoreService;

  const WorkerDashboardScreen({
    super.key,
    this.user,
    this.firestoreService,
  });

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late final FirestoreService _firestoreService;

  // Local state for current task assignment
  bool _isLoading = false;
  bool _hasActiveTask = false;
  String _taskTitle = '';
  String _taskDescription = '';
  String _wardName = '';
  String _targetDeadline = '';
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  String _taskStatus = '';
  String? _supervisorFeedback;
  String? _currentAssignmentId;
  UserModel? _loadedUser;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadWorkerTaskData();
  }

  Future<void> _loadWorkerTaskData() async {
    final effectiveUser = _loadedUser ?? widget.user;
    final workerId = effectiveUser?.userId ??
        (AuthService().isFirebaseAvailable
            ? AuthService().auth.currentUser?.uid ?? ''
            : '');

    if (workerId.isNotEmpty && _loadedUser == null) {
      final profile = await _firestoreService.getUserProfile(workerId);
      if (mounted && profile != null) {
        setState(() {
          _loadedUser = profile;
        });
      }
    }

    final currentUser = _loadedUser ?? widget.user;
    if (currentUser == null) {
      if (mounted) setState(() => _hasActiveTask = false);
      return;
    }

    // Load ward name if wardId exists
    if (currentUser.wardId != null && currentUser.wardId!.isNotEmpty) {
      await _loadWardName(currentUser.wardId!);
    }

    // Check if worker status is Available with no active assignment
    if (currentUser.status == UserStatus.available &&
        currentUser.activeAssignmentId == null) {
      if (mounted) {
        setState(() {
          _hasActiveTask = false;
        });
      }
      return;
    }

    // Attempt to load from Firestore/in-memory if user ID exists
    if (currentUser.userId.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final assignment = await _firestoreService
            .getActiveAssignmentForWorker(currentUser.userId);
        if (assignment != null) {
          String title = 'Cleaning Task';
          String desc = '';
          if (assignment.taskId.isNotEmpty) {
            final task = await _firestoreService.getTask(assignment.taskId);
            if (task != null) {
              title = task.title;
              desc = task.description;
            }
          }

          if (assignment.wardId.isNotEmpty && _wardName.isEmpty) {
            await _loadWardName(assignment.wardId);
          }

          final hour = assignment.deadline.hour;
          final minute = assignment.deadline.minute.toString().padLeft(2, '0');
          final ampm = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;

          if (mounted) {
            setState(() {
              _hasActiveTask = true;
              _currentAssignmentId = assignment.assignmentId;
              _taskTitle = title;
              _taskDescription = desc;
              _taskStatus = assignment.status.displayName;
              _failedAttempts = assignment.attempts;
              _supervisorFeedback = assignment.supervisorFeedback;
              _targetDeadline = '$hour12:$minute $ampm';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasActiveTask = false;
              _currentAssignmentId = null;
            });
          }
        }
      } catch (e) {
        debugPrint('Note loading task assignment: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWardName(String wardId) async {
    try {
      final ward = await _firestoreService.getWard(wardId);
      if (mounted && ward != null && ward.name.isNotEmpty) {
        setState(() {
          _wardName = ward.name;
        });
      }
    } catch (e) {
      debugPrint('Note loading ward: $e');
    }
  }

  Future<void> _handleMarkComplete() async {
    setState(() => _isLoading = true);

    // If assignmentId exists, mark complete in Firestore/in-memory
    final assignmentId = _currentAssignmentId ?? widget.user?.activeAssignmentId;
    if (assignmentId != null && assignmentId.isNotEmpty) {
      await _firestoreService.markAssignmentCompleted(assignmentId);
    }

    // Transition to Pending Verification
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _taskStatus = 'Pending Verification';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task submitted! Supervisor will review within 1 hour.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Worker Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_hasActiveTask && _taskTitle.isNotEmpty) ...[
                  _notificationTile(
                    icon: Icons.assignment_turned_in,
                    iconColor: const Color(0xFF1E3A8A),
                    title: 'Task Assigned',
                    subtitle:
                        'Supervisor assigned you "$_taskTitle"${_targetDeadline.isNotEmpty ? ' with deadline $_targetDeadline' : ''}.',
                    timeAgo: 'Active',
                  ),
                  const Divider(height: 24),
                ] else ...[
                  _notificationTile(
                    icon: Icons.notifications_none_rounded,
                    iconColor: const Color(0xFF64748B),
                    title: 'No New Tasks',
                    subtitle: 'You have no active task assignments at this moment.',
                    timeAgo: 'Up to date',
                  ),
                  const Divider(height: 24),
                ],
                _notificationTile(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Verification Window',
                  subtitle:
                      'Supervisor has 1 hour to review your completed task.',
                  timeAgo: 'Information',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeAgo,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  UserModel? get _currentUser => _loadedUser ?? widget.user;

  String _getEffectiveUserName() {
    final user = _currentUser;
    if (user != null && user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    if (AuthService().isFirebaseAvailable) {
      final authName = AuthService().auth.currentUser?.displayName;
      if (authName != null && authName.trim().isNotEmpty) {
        return authName.trim();
      }
    }
    final email = _getEffectiveEmail();
    if (email.contains('@')) {
      final prefix = email.split('@').first;
      final parts = prefix.replaceAll(RegExp(r'[._\d]'), ' ').trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        return parts.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
      }
    }
    return 'Worker';
  }

  String _getEffectiveEmployeeId() {
    final user = _currentUser;
    if (user != null && user.employeeId.trim().isNotEmpty) {
      return user.employeeId.trim();
    }
    if (user != null && user.userId.trim().isNotEmpty) {
      return user.userId.trim();
    }
    return '';
  }

  String _getEffectiveEmail() {
    final user = _currentUser;
    if (user != null && user.email.trim().isNotEmpty) {
      return user.email.trim();
    }
    if (AuthService().isFirebaseAvailable) {
      final authEmail = AuthService().auth.currentUser?.email;
      if (authEmail != null && authEmail.trim().isNotEmpty) {
        return authEmail.trim();
      }
    }
    return '';
  }

  String _getUserInitials() {
    final name = _getEffectiveUserName();
    if (name.isEmpty) return 'W';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'W';
  }

  String _formatWardDisplay(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Ward';
    if (trimmed.toLowerCase().endsWith('ward')) {
      return trimmed;
    }
    return '$trimmed Ward';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getEffectiveUserName();
    final employeeId = _getEffectiveEmployeeId();
    final ward = _wardName.isNotEmpty
        ? _wardName
        : ((_currentUser?.wardId != null && _currentUser!.wardId!.isNotEmpty)
            ? _currentUser!.wardId!
            : 'General');
    final workerEmail = _getEffectiveEmail();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // Top App Bar matching Admin Dashboard: CleanTrack Worker + HOUSEKEEPING MANAGEMENT + Bell + Profile
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
                  // CleanTrack Worker branding
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

                  // Notifications Bell
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                    tooltip: 'Notifications',
                    onPressed: _showNotificationsSheet,
                  ),
                  const SizedBox(width: 4),

                  // Avatar with Popup Menu (includes workerLogoutButton key)
                  PopupMenuButton<String>(
                    key: const Key('workerLogoutButton'),
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
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              workerEmail,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Prominent Section Header (matches Admin Dashboard layout with Live pill)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Worker Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ward housekeeping operations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  // Live status indicator pill (matching admin dashboard)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 1. Worker Profile Header Card (Shifted below section header)
              _buildWorkerProfileCard(displayName, employeeId, ward),

              const SizedBox(height: 16),

              // 2. Main Content Area (Active Task vs No Task Available)
              if (_hasActiveTask)
                _buildActiveTaskCard(ward)
              else
                _buildNoTaskAvailableCard(ward),


            ],
          ),
        ),
      ),
    );
  }

  /// Worker Profile Card
  Widget _buildWorkerProfileCard(
      String displayName, String employeeId, String ward) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Badge Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBFDBFE),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.badge_outlined,
                color: Color(0xFF1E3A8A),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Worker Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: $employeeId',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Ward Pill (e.g. ICU Ward) - Styled with black text just like supervisor dashboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatWardDisplay(ward),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Active Task Card (Pixel-accurate match to the prompt's screenshot)
  Widget _buildActiveTaskCard(String ward) {
    final isPendingVerification = _taskStatus == 'Pending Verification';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Task Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Status Pill (Ward box removed as it is already shown in worker card)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPendingVerification
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isPendingVerification
                              ? const Color(0xFFD97706)
                              : const Color(0xFF475569),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _taskStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPendingVerification
                              ? const Color(0xFFB45309)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Task Title
              Text(
                _taskTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),

              // Task Description / Instructions
              if (_taskDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _taskDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],

              // Supervisor Feedback Banner
              if (_supervisorFeedback != null &&
                  _supervisorFeedback!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.feedback_outlined,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supervisor Reassignment Feedback',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _supervisorFeedback!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF78350F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Target Deadline Box
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    // Grey Circle with Clock
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.access_time_rounded,
                          size: 22,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Deadline Label & Value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARGET DEADLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _targetDeadline,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Failed Attempts Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    // Failed Attempts Count & Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Failed Attempts: $_failedAttempts / $_maxAttempts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Row(
                          children: List.generate(_maxAttempts, (index) {
                            final isFilled = index < _failedAttempts;
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isFilled
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFCBD5E1),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Warning Alert Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reaching 3 failed attempts results in suspension for this task.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
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
        ),

        const SizedBox(height: 20),

        // Action Section
        if (!isPendingVerification) ...[
          // Mark Task Complete Button
          ElevatedButton(
            key: const Key('markTaskCompleteButton'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _isLoading ? null : _handleMarkComplete,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'MARK TASK COMPLETE',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),

          // Footnote notice
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Submitting moves task to Pending Verification. Supervisor will review within 1 hour.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ] else ...[
          // Pending Verification Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFB45309),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Task Submitted — Pending Verification',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Your supervisor has 1 hour to review and verify this task.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// No Task Available State (Only displays assigned tasks when allotted; no status or policy list when idle)
  Widget _buildNoTaskAvailableCard(String ward) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Empty State Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Clean Housekeeping Check Illustration
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.cleaning_services_outlined,
                    size: 40,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Headline & Description
              const Text(
                'No Tasks Assigned',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'You currently have no cleaning tasks in ${_formatWardDisplay(ward)}. Tasks assigned by your supervisor will appear here.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Refresh / Check for New Tasks Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: () {
            _loadWorkerTaskData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Checking for new ward tasks...'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text(
            'CHECK FOR NEW TASKS',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
