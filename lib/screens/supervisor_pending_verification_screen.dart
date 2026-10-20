import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_assignment_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

class SupervisorPendingVerificationScreen extends StatefulWidget {
  final UserModel? user;
  final WardModel? ward;
  final FirestoreService? firestoreService;

  const SupervisorPendingVerificationScreen({
    super.key,
    this.user,
    this.ward,
    this.firestoreService,
  });

  @override
  State<SupervisorPendingVerificationScreen> createState() =>
      _SupervisorPendingVerificationScreenState();
}

class _SupervisorPendingVerificationScreenState
    extends State<SupervisorPendingVerificationScreen> {
  late final FirestoreService _firestoreService;
  UserModel? _currentUser;
  WardModel? _currentWard;

  // Caches for fast synchronous lookups
  final Map<String, TaskModel> _taskCache = {};
  final Map<String, UserModel> _workerCache = {};

  // Tracks assignments currently awaiting supervisor reselection (3rd rejection)
  final Set<String> _suspendedAssignmentIds = {};
  final Map<String, String?> _selectedNewWorkerIds = {};

  Timer? _autoVerifyTimer;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _currentUser = widget.user;
    _currentWard = widget.ward;

    _resolveUserAndWard();

    // Check for auto-verification on launch and periodically every minute
    _firestoreService.checkAndAutoVerifyAssignments();
    _autoVerifyTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _firestoreService.checkAndAutoVerifyAssignments();
    });
  }

  @override
  void dispose() {
    _autoVerifyTimer?.cancel();
    super.dispose();
  }

  Future<void> _resolveUserAndWard() async {
    if (_currentUser == null && AuthService().isFirebaseAvailable) {
      final fbUser = AuthService().auth.currentUser;
      if (fbUser != null) {
        final profile = await _firestoreService.getUserProfile(fbUser.uid);
        if (mounted && profile != null) {
          setState(() {
            _currentUser = profile;
          });
        }
      }
    }

    final effectiveWardId = _getEffectiveWardId();
    if (_currentWard == null && effectiveWardId.isNotEmpty) {
      final w = await _firestoreService.getWard(effectiveWardId);
      if (mounted && w != null) {
        setState(() {
          _currentWard = w;
        });
      }
    }
  }

  String _getEffectiveWardId() {
    if (_currentWard != null && _currentWard!.wardId.isNotEmpty) {
      return _currentWard!.wardId;
    }
    if (_currentUser != null &&
        _currentUser!.wardId != null &&
        _currentUser!.wardId!.isNotEmpty) {
      return _currentUser!.wardId!;
    }
    return '';
  }

  String _getEffectiveWardDisplayName() {
    if (_currentWard != null && _currentWard!.name.isNotEmpty) {
      return formatWardDisplayName(_currentWard!.name);
    }
    if (_currentUser != null &&
        _currentUser!.wardName != null &&
        _currentUser!.wardName!.isNotEmpty) {
      return formatWardDisplayName(_currentUser!.wardName!);
    }
    if (_currentUser != null &&
        _currentUser!.wardId != null &&
        _currentUser!.wardId!.isNotEmpty) {
      return formatWardDisplayName(_currentUser!.wardId!);
    }
    return 'ICU';
  }

  String _getSupervisorName() {
    if (_currentUser != null && _currentUser!.name.isNotEmpty) {
      return _currentUser!.name;
    }
    if (AuthService().isFirebaseAvailable) {
      final fbName = AuthService().auth.currentUser?.displayName;
      if (fbName != null && fbName.isNotEmpty) return fbName;
    }
    return 'Supervisor';
  }

  String _formatTime12h(DateTime? dt) {
    if (dt == null) return '--:--';
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $ampm';
  }

  String _formatDeadline(DateTime deadline, DateTime? referenceTime) {
    final ref = referenceTime ?? DateTime.now();
    final timeStr = _formatTime12h(deadline);
    final isNextDay = deadline.day != ref.day || deadline.difference(ref).inHours >= 12;
    final diff = deadline.difference(DateTime.now());
    final hoursLeft = diff.inHours;

    String leftStr;
    if (diff.isNegative) {
      leftStr = 'Overdue';
    } else if (hoursLeft >= 24) {
      leftStr = '${hoursLeft}h left';
    } else if (hoursLeft > 0) {
      leftStr = '${hoursLeft}h left';
    } else {
      leftStr = '${diff.inMinutes.clamp(0, 59)}m left';
    }

    if (isNextDay) {
      return '$timeStr next day ($leftStr)';
    } else {
      return '$timeStr ($leftStr)';
    }
  }

  TaskModel? _getTaskSync(String taskId) {
    if (_taskCache.containsKey(taskId)) return _taskCache[taskId];
    final inMem = _firestoreService.inMemoryTasks.where((t) => t.taskId == taskId);
    if (inMem.isNotEmpty) {
      _taskCache[taskId] = inMem.first;
      return inMem.first;
    }
    _firestoreService.getTask(taskId).then((t) {
      if (t != null && mounted) {
        setState(() => _taskCache[taskId] = t);
      }
    });
    return null;
  }

  UserModel? _getWorkerSync(String workerId) {
    if (_workerCache.containsKey(workerId)) return _workerCache[workerId];
    final inMem = _firestoreService.inMemoryUsers.where((u) => u.userId == workerId);
    if (inMem.isNotEmpty) {
      _workerCache[workerId] = inMem.first;
      return inMem.first;
    }
    _firestoreService.getUserProfile(workerId).then((u) {
      if (u != null && mounted) {
        setState(() => _workerCache[workerId] = u);
      }
    });
    return null;
  }

  Future<void> _handleVerify(TaskAssignmentModel assignment, String taskTitle) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    try {
      final success = await _firestoreService.verifyTaskAssignment(
        assignmentId: assignment.assignmentId,
        taskId: assignment.taskId,
        workerId: assignment.workerId,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Task "$taskTitle" verified successfully.',
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
            content: Text('Failed to verify task. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleReject(TaskAssignmentModel assignment, UserModel? worker) async {
    if (_isProcessingAction) return;

    final workerName = worker?.name ?? 'Worker';
    final currentAttempts = assignment.attempts;

    if (currentAttempts >= 2) {
      // 3rd rejection: instantly suspend the worker and show inline reassignment dropdown
      setState(() => _isProcessingAction = true);
      try {
        final success = await _firestoreService.rejectTaskAssignment(
          assignmentId: assignment.assignmentId,
          taskId: assignment.taskId,
          workerId: assignment.workerId,
          currentAttempts: currentAttempts,
        );

        if (!mounted) return;
        if (success) {
          _workerCache.remove(assignment.workerId);
          setState(() {
            _suspendedAssignmentIds.add(assignment.assignmentId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$workerName suspended after 3 failed attempts (PRD SU02). Reassign task below.',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFBE123C),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    } else {
      // 1st or 2nd rejection: reset status back to Pending in worker dashboard
      setState(() => _isProcessingAction = true);
      try {
        final nextAttempt = currentAttempts + 1;
        final success = await _firestoreService.rejectTaskAssignment(
          assignmentId: assignment.assignmentId,
          taskId: assignment.taskId,
          workerId: assignment.workerId,
          currentAttempts: currentAttempts,
        );

        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Task rejected. Resent to $workerName (Attempt $nextAttempt of 3).',
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
        }
      } finally {
        if (mounted) setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleReassignToAnotherWorker({
    required TaskAssignmentModel oldAssignment,
    required String newWorkerId,
    required List<UserModel> wardWorkers,
  }) async {
    if (_isProcessingAction || newWorkerId.isEmpty) return;
    setState(() => _isProcessingAction = true);

    try {
      final newWorker = wardWorkers.firstWhere(
        (w) => w.userId == newWorkerId,
        orElse: () => UserModel(
          userId: newWorkerId,
          name: 'New Worker',
          employeeId: 'WRK',
          email: '',
          role: UserRole.worker,
        ),
      );
      final supervisorId = _currentUser?.userId ?? '';

      final reassigned = await _firestoreService.reassignToAnotherWorker(
        oldAssignmentId: oldAssignment.assignmentId,
        taskId: oldAssignment.taskId,
        failedWorkerId: oldAssignment.workerId,
        newWorkerId: newWorkerId,
        wardId: oldAssignment.wardId,
        supervisorId: supervisorId,
        newDeadline: oldAssignment.deadline,
        currentAssignmentNumber: oldAssignment.assignmentNumber,
      );

      if (!mounted) return;
      if (reassigned != null) {
        _workerCache.remove(newWorkerId);
        _workerCache.remove(oldAssignment.workerId);
        setState(() {
          _suspendedAssignmentIds.remove(oldAssignment.assignmentId);
          _selectedNewWorkerIds.remove(oldAssignment.assignmentId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Task reassigned to ${newWorker.name}. Previous worker suspended.',
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
            content: Text('Failed to reassign task. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _showNotificationsDialog() {
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
                      'Supervisor Notifications',
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
                _notificationTile(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFFD97706),
                  title: 'Auto-Verification Protocol',
                  subtitle: 'Completed tasks are auto-verified after 1 hour if not reviewed.',
                  timeAgo: 'Protocol',
                ),
                const Divider(height: 24),
                _notificationTile(
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: const Color(0xFF1E3A8A),
                  title: 'Task Review Reminder',
                  subtitle: 'Verify work promptly to maintain clean wards and accurate reporting.',
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final effectiveWardId = _getEffectiveWardId();
    final wardDisplayName = _getEffectiveWardDisplayName();
    final supervisorName = _getSupervisorName();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('pendingVerificationBackButton'),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Pending Verification',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('pendingVerificationBellButton'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _showNotificationsDialog,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            key: const Key('supervisorAvatarMenuButton'),
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supervisorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Supervisor • Ward: $wardDisplayName',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: UserAvatar(
                name: supervisorName,
                size: 36,
                backgroundColor: const Color(0xFF0F172A),
                textColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.streamWorkersByWard(effectiveWardId),
        builder: (context, workersSnapshot) {
          final wardWorkers = workersSnapshot.data ?? [];

          return StreamBuilder<List<TaskAssignmentModel>>(
            stream: _firestoreService.streamPendingVerificationAssignments(effectiveWardId),
            builder: (context, assignmentsSnapshot) {
              final rawAssignments = assignmentsSnapshot.data ?? [];

              // Merge any assignments that are in reassigning state (3rd rejection)
              final displayedAssignments = <TaskAssignmentModel>[...rawAssignments];
              for (final suspendedId in _suspendedAssignmentIds) {
                if (!displayedAssignments.any((a) => a.assignmentId == suspendedId)) {
                  final suspendedAssignment = _firestoreService.inMemoryAssignments
                      .where((a) => a.assignmentId == suspendedId)
                      .firstOrNull;
                  if (suspendedAssignment != null) {
                    displayedAssignments.add(suspendedAssignment);
                  }
                }
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ward Subheader
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.domain_outlined,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ward: $wardDisplayName',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Auto-Verification Protocol Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
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
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.timer_outlined,
                                size: 20,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Auto-Verification Protocol',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            'If no action is taken within 1 hour of submission, the task automatically becomes ',
                                      ),
                                      TextSpan(
                                        text: 'Auto Verified',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Empty State or List of Task Cards
                    if (displayedAssignments.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedAssignments.length,
                        itemBuilder: (ctx, index) {
                          final assignment = displayedAssignments[index];
                          return _buildTaskCard(assignment, wardWorkers);
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 52,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 16),
          Text(
            'No Tasks Pending Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'All completed housekeeping tasks in this ward have been verified.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskAssignmentModel assignment, List<UserModel> wardWorkers) {
    final task = _getTaskSync(assignment.taskId);
    final worker = _getWorkerSync(assignment.workerId);

    final taskTitle = task?.title ?? 'Housekeeping Task';
    final workerName = worker?.name ?? 'Worker';
    final workerEmployeeId = worker?.employeeId.isNotEmpty == true
        ? worker!.employeeId
        : 'WRK';

    final completedTime = _formatTime12h(assignment.completedAt ?? assignment.assignedAt);
    final deadlineText = _formatDeadline(assignment.deadline, assignment.completedAt);
    final isSuspendedCard = _suspendedAssignmentIds.contains(assignment.assignmentId);

    return Container(
      key: Key('pendingVerificationCard_${assignment.assignmentId}'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Header Row: Task Title & Worker badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  taskTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$workerName ($workerEmployeeId)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Completed & Deadline Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMPLETED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        completedTime,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEADLINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deadlineText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Failed Attempts Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Failed Attempts: ${assignment.attempts} / 3',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildAttemptDot(active: assignment.attempts >= 1),
                    const SizedBox(width: 6),
                    _buildAttemptDot(active: assignment.attempts >= 2),
                    const SizedBox(width: 6),
                    _buildAttemptDot(active: assignment.attempts >= 3),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Action Buttons or Inline Reassign UI
          if (isSuspendedCard)
            _buildReassignInlineSection(assignment, wardWorkers)
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      key: Key('verifyButton_${assignment.assignmentId}'),
                      onPressed: _isProcessingAction
                          ? null
                          : () => _handleVerify(assignment, taskTitle),
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'VERIFY',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      key: Key('rejectButton_${assignment.assignmentId}'),
                      onPressed: _isProcessingAction
                          ? null
                          : () => _handleReject(assignment, worker),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: Color(0xFF0F172A),
                      ),
                      label: const Text(
                        'REJECT / FAILED',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(
                          color: Color(0xFF94A3B8),
                          width: 1.5,
                        ),
                        shape: const StadiumBorder(),
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

  Widget _buildAttemptDot({required bool active}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildReassignInlineSection(
    TaskAssignmentModel assignment,
    List<UserModel> wardWorkers,
  ) {
    // Only available workers who are NOT suspended and not the current failed worker
    final availableWorkers = wardWorkers
        .where((w) =>
            w.role == UserRole.worker &&
            w.status == UserStatus.available &&
            w.userId != assignment.workerId)
        .toList();

    final selectedWorkerId = _selectedNewWorkerIds[assignment.assignmentId];

    return Container(
      key: Key('reassignSection_${assignment.assignmentId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Worker suspended (3 failed attempts - PRD SU02). Choose another available worker to reassign this task:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (availableWorkers.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No other available workers in this ward right now.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: Key('reassignWorkerDropdown_${assignment.assignmentId}'),
                  isExpanded: true,
                  value: selectedWorkerId,
                  hint: const Text(
                    'Select Available Worker',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  items: availableWorkers.map((w) {
                    return DropdownMenuItem<String>(
                      value: w.userId,
                      child: Text(
                        '${w.name} (${w.employeeId})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    setState(() {
                      _selectedNewWorkerIds[assignment.assignmentId] = newId;
                    });
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              key: Key('reassignTaskButton_${assignment.assignmentId}'),
              onPressed: (_isProcessingAction ||
                      selectedWorkerId == null ||
                      selectedWorkerId.isEmpty)
                  ? null
                  : () => _handleReassignToAnotherWorker(
                        oldAssignment: assignment,
                        newWorkerId: selectedWorkerId,
                        wardWorkers: wardWorkers,
                      ),
              icon: const Icon(Icons.assignment_turned_in, size: 18),
              label: const Text(
                'REASSIGN TASK',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
