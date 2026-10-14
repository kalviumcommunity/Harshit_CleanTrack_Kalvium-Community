import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'supervisor_assign_task_screen.dart';
import 'login_screen.dart';

class SupervisorWorkerListScreen extends StatefulWidget {
  final UserModel? user;
  final WardModel? ward;
  final FirestoreService? firestoreService;

  const SupervisorWorkerListScreen({
    super.key,
    this.user,
    this.ward,
    this.firestoreService,
  });

  @override
  State<SupervisorWorkerListScreen> createState() => _SupervisorWorkerListScreenState();
}

class _SupervisorWorkerListScreenState extends State<SupervisorWorkerListScreen> {
  late final FirestoreService _firestoreService;
  UserModel? _loadedUser;
  WardModel? _loadedWard;

  // Real-time cache for active task titles & statuses of busy workers
  final Map<String, String> _workerTaskTitles = {};
  final Map<String, String> _workerTaskStatuses = {};

  StreamSubscription? _assignmentsSubscription;
  List<UserModel> _latestWorkers = [];

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadedUser = widget.user;
    _loadedWard = widget.ward;
    _loadSupervisorAndWardData();
    _subscribeToAssignments();
  }

  void _subscribeToAssignments() {
    _assignmentsSubscription?.cancel();
    final wardId = _effectiveWardId;
    _assignmentsSubscription = _firestoreService.streamAssignmentsByWard(wardId).listen((_) {
      if (mounted && _latestWorkers.isNotEmpty) {
        _loadActiveTasksForWorkers(_latestWorkers, force: true);
      }
    });
  }

  @override
  void dispose() {
    _assignmentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSupervisorAndWardData() async {
    // 1. Fetch live user profile if needed
    final uid = _currentUser?.userId ??
        (AuthService().isFirebaseAvailable ? AuthService().auth.currentUser?.uid : null);
    if (uid != null && uid.isNotEmpty && (_loadedUser == null || _loadedUser!.name.isEmpty)) {
      final profile = await _firestoreService.getUserProfile(uid);
      if (mounted && profile != null) {
        setState(() {
          _loadedUser = profile;
        });
      }
    }

    // 2. Fetch assigned ward if needed
    final wardId = _effectiveWardId;
    if (wardId.isNotEmpty && _loadedWard == null) {
      final ward = await _firestoreService.getWard(wardId);
      if (mounted && ward != null) {
        setState(() {
          _loadedWard = ward;
        });
        _subscribeToAssignments();
      }
    }
  }

  UserModel? get _currentUser => _loadedUser ?? widget.user;

  String get _effectiveWardId {
    if (_loadedWard != null && _loadedWard!.wardId.isNotEmpty) {
      return _loadedWard!.wardId;
    }
    if (widget.ward != null && widget.ward!.wardId.isNotEmpty) {
      return widget.ward!.wardId;
    }
    if (_currentUser?.wardId != null && _currentUser!.wardId!.isNotEmpty) {
      return _currentUser!.wardId!;
    }
    return '';
  }

  String get _effectiveWardDisplayName {
    if (_loadedWard != null && _loadedWard!.name.isNotEmpty) {
      return formatWardDisplayName(_loadedWard!.name);
    }
    if (widget.ward != null && widget.ward!.name.isNotEmpty) {
      return formatWardDisplayName(widget.ward!.name);
    }
    final wardId = _currentUser?.wardId ?? '';
    if (wardId.isNotEmpty) {
      return formatWardDisplayName(wardId);
    }
    return '';
  }

  String _getSupervisorName() {
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
    return '';
  }

  String _getSupervisorEmail() {
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

  void _loadActiveTasksForWorkers(List<UserModel> workers, {bool force = false}) {
    _latestWorkers = workers;
    for (final worker in workers) {
      if (worker.status == UserStatus.busy) {
        if (force || !_workerTaskTitles.containsKey(worker.userId)) {
          _firestoreService.getActiveAssignmentForWorker(worker.userId).then((assignment) async {
            if (assignment != null) {
              final task = await _firestoreService.getTask(assignment.taskId);
              if (mounted) {
                setState(() {
                  _workerTaskTitles[worker.userId] =
                      task != null && task.title.isNotEmpty ? task.title : 'Active Task';
                  _workerTaskStatuses[worker.userId] = assignment.status.displayName;
                });
              }
            } else {
              if (mounted) {
                setState(() {
                  _workerTaskTitles[worker.userId] = 'Active Task';
                  _workerTaskStatuses[worker.userId] = worker.status.displayName;
                });
              }
            }
          }).catchError((_) {
            if (mounted) {
              setState(() {
                _workerTaskTitles[worker.userId] = 'Active Task';
                _workerTaskStatuses[worker.userId] = worker.status.displayName;
              });
            }
          });
        }
      }
    }
  }

  Future<void> _handleLogout() async {
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
    final wardId = _effectiveWardId;
    final wardDisplayName = _effectiveWardDisplayName;
    final effectiveWard = _loadedWard ??
        widget.ward ??
        WardModel(wardId: wardId, name: wardDisplayName);
    final supervisorName = _getSupervisorName();
    final supervisorEmail = _getSupervisorEmail();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('workerListBackButton'),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0F172A),
            size: 24,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Worker List',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('workerListNotificationButton'),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0F172A),
              size: 24,
            ),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications module is coming up next.'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          // Supervisor Profile Avatar using reusable UserAvatar component
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              key: const Key('workerListProfileButton'),
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
                        supervisorName.isNotEmpty ? supervisorName : 'Supervisor',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (supervisorEmail.isNotEmpty)
                        Text(
                          supervisorEmail,
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
              child: UserAvatar(
                name: supervisorName,
                size: 38,
                backgroundColor: const Color(0xFF0F172A),
                textColor: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.streamWorkersByWard(wardId),
        builder: (context, snapshot) {
          final workers = snapshot.data ?? [];

          // Trigger task loading for any busy workers
          _loadActiveTasksForWorkers(workers);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ward & Total Staff Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ward Title & Pill
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Ward : ',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            key: const Key('wardNamePill'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              wardDisplayName.isNotEmpty
                                  ? wardDisplayName
                                  : (widget.ward != null && widget.ward!.name.isNotEmpty
                                      ? widget.ward!.name
                                      : 'ICU Ward'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Total Staff Pill Card
                      Container(
                        key: const Key('totalStaffCard'),
                        padding: const EdgeInsets.only(left: 6, top: 6, bottom: 6, right: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0F172A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.groups_outlined,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${workers.length}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    height: 1.1,
                                  ),
                                ),
                                const Text(
                                  'Total Staff',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List of Workers or Clean Empty State
                if (workers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No Workers Assigned',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Workers assigned to this ward by Admin will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: workers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      return _buildWorkerCard(
                        context: context,
                        worker: worker,
                        effectiveWard: effectiveWard,
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkerCard({
    required BuildContext context,
    required UserModel worker,
    required WardModel effectiveWard,
  }) {
    final isAvailable = worker.status == UserStatus.available;
    final isBusy = worker.status == UserStatus.busy;
    final isSuspended = worker.status == UserStatus.suspended;

    final employeeDisplayId = worker.employeeId.isNotEmpty
        ? worker.employeeId
        : (worker.userId.startsWith('wrk-')
            ? worker.userId.toUpperCase().replaceAll('-', '-')
            : 'WRK-${worker.userId.substring(0, worker.userId.length.clamp(0, 4))}');

    final taskTitle = _workerTaskTitles[worker.userId] ?? 'Active Task';
    final taskStatus = _workerTaskStatuses[worker.userId] ?? worker.status.displayName;

    return Container(
      key: Key('workerCard_${worker.userId}'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar using reusable UserAvatar component, Name, Employee ID, Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                name: worker.name,
                size: 48,
                backgroundColor: const Color(0xFFF1F5F9),
                textColor: const Color(0xFF0F172A),
                fontSize: 16,
              ),
              const SizedBox(width: 14),
              // Worker Name and WRK ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      employeeDisplayId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isAvailable ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      worker.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom Section depending on worker status
          if (isAvailable) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ready for assignment',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  key: Key('assignTaskButton_${worker.userId}'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupervisorAssignTaskScreen(
                          selectedWorker: worker,
                          user: _currentUser,
                          ward: effectiveWard,
                          firestoreService: _firestoreService,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.add_task_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ASSIGN TASK',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (isBusy) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_outlined,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Task',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          taskTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: taskStatus == 'Pending Verification'
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      taskStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: taskStatus == 'Pending Verification'
                            ? const Color(0xFFB45309)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isSuspended) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.block_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Suspended - Restricted from task assignment',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pending ward activation',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
