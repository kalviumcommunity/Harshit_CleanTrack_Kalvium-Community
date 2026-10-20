import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

class SupervisorAssignTaskScreen extends StatefulWidget {
  final UserModel? selectedWorker;
  final UserModel? user;
  final WardModel? ward;
  final FirestoreService? firestoreService;

  const SupervisorAssignTaskScreen({
    super.key,
    this.selectedWorker,
    this.user,
    this.ward,
    this.firestoreService,
  });

  @override
  State<SupervisorAssignTaskScreen> createState() => _SupervisorAssignTaskScreenState();
}

class _SupervisorAssignTaskScreenState extends State<SupervisorAssignTaskScreen> {
  late final FirestoreService _firestoreService;
  UserModel? _loadedUser;
  WardModel? _loadedWard;

  UserModel? _selectedWorker;
  late final TextEditingController _taskTitleController;
  late final TextEditingController _descriptionController;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 30);
  late DateTime _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _loadedUser = widget.user;
    _loadedWard = widget.ward;
    _selectedWorker = widget.selectedWorker;

    // Initialize deadline date (defaults to tomorrow if 10:30 AM has already passed today)
    final now = DateTime.now();
    final today1030 = DateTime(now.year, now.month, now.day, 10, 30);
    _selectedDate = now.isAfter(today1030) ? now.add(const Duration(days: 1)) : now;

    // Editable text controllers
    _taskTitleController = TextEditingController();
    _descriptionController = TextEditingController();

    _loadSupervisorAndWardData();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _descriptionController.dispose();
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

  String _formatTimeDisplay(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute';
  }

  String _formatDateDisplay(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = target.difference(today).inDays;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[date.month - 1];

    if (diffDays == 0) {
      return 'Today, ${date.day} $monthName';
    } else if (diffDays == 1) {
      return 'Tomorrow, ${date.day} $monthName';
    } else {
      return '${date.day} $monthName ${date.year}';
    }
  }

  Future<void> _pickDeadlineDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate.isBefore(today) ? today : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime _buildDeadlineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _handleAssignTask() async {
    if (_selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available worker to assign this task.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_selectedWorker!.status != UserStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedWorker!.name} is not available for assignment.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final rawTitle = _taskTitleController.text.trim();
    final title = rawTitle.isNotEmpty ? rawTitle : 'Floor Cleaning';

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter task instructions in the description field.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final deadline = _buildDeadlineDateTime(_selectedDate, _selectedTime);
    if (deadline.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a deadline in the future.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final wardId = _effectiveWardId.isNotEmpty ? _effectiveWardId : (_selectedWorker!.wardId ?? 'ward-icu');
      final supervisorId = _currentUser?.userId ?? '';

      final assignment = await _firestoreService.createTaskAndAssignment(
        wardId: wardId,
        supervisorId: supervisorId,
        title: title,
        description: description,
        workerId: _selectedWorker!.userId,
        deadline: deadline,
      );

      if (mounted) {
        if (assignment != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task successfully assigned to ${_selectedWorker!.name}.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to assign task. Please try again.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning task: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
    final supervisorName = _getSupervisorName();
    final supervisorEmail = _getSupervisorEmail();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('assignTaskBackButton'),
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0F172A),
            size: 24,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Assign Task',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('assignTaskNotificationButton'),
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
              key: const Key('assignTaskProfileButton'),
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
          final liveWorkers = sortWorkersByStatus(snapshot.data ?? []);

          // Auto-select initial worker if not already selected
          if (_selectedWorker == null && liveWorkers.isNotEmpty) {
            final firstAvailable = liveWorkers.where((w) => w.status == UserStatus.available);
            if (firstAvailable.isNotEmpty) {
              _selectedWorker = firstAvailable.first;
            } else {
              _selectedWorker = liveWorkers.first;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available Worker Section
                const Text(
                  'Available Worker',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),

                if (liveWorkers.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No workers found in this ward. Assign workers via Admin Dashboard first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: liveWorkers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final worker = liveWorkers[index];
                      return _buildWorkerSelectCard(worker);
                    },
                  ),
                const SizedBox(height: 24),

                // Task Section
                const Text(
                  'Task',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.note_add_outlined,
                        color: Color(0xFF0F172A),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('taskTitleInput'),
                          controller: _taskTitleController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter task title',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Description Section
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: TextField(
                    key: const Key('taskDescriptionInput'),
                    controller: _descriptionController,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Task explanation ...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Deadline Section (Date and Time Pickers)
                const Text(
                  'Deadline',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Date Picker Tile
                    Expanded(
                      flex: 6,
                      child: InkWell(
                        key: const Key('datePickerTile'),
                        borderRadius: BorderRadius.circular(28),
                        onTap: _pickDeadlineDate,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF0F172A),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDateDisplay(_selectedDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time Picker Tile
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        key: const Key('deadlinePickerTile'),
                        borderRadius: BorderRadius.circular(28),
                        onTap: _pickDeadlineTime,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: Color(0xFF0F172A),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimeDisplay(_selectedTime),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _selectedTime.period == DayPeriod.am ? 'AM' : 'PM',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Submit Assign Task Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('submitAssignTaskButton'),
                    onPressed: _isSubmitting ? null : _handleAssignTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'ASSIGN TASK',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkerSelectCard(UserModel worker) {
    final isAvailable = worker.status == UserStatus.available;
    final isBusy = worker.status == UserStatus.busy;
    final isSelected = isAvailable && _selectedWorker?.userId == worker.userId;

    final employeeDisplayId = worker.employeeId.isNotEmpty
        ? worker.employeeId
        : (worker.userId.startsWith('wrk-')
            ? worker.userId.toUpperCase()
            : 'WRK-${worker.userId.substring(0, worker.userId.length.clamp(0, 4))}');

    if (isAvailable) {
      return InkWell(
        key: Key('workerSelectTile_${worker.userId}'),
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          setState(() {
            _selectedWorker = worker;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Selection Indicator (Dark circle with checkmark or empty ring)
              if (isSelected)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                ),
              const SizedBox(width: 14),

              // Worker Initials Avatar
              UserAvatar(
                name: worker.name,
                size: 44,
                backgroundColor: const Color(0xFFF1F5F9),
                textColor: const Color(0xFF0F172A),
                fontSize: 15,
              ),
              const SizedBox(width: 14),

              // Name and Employee ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $employeeDisplayId',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
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

    // Disabled worker card (Busy with lock icon or Suspended with block icon)
    return InkWell(
      key: Key('workerDisabledTile_${worker.userId}'),
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBusy
                  ? '${worker.name} is currently busy with an active task.'
                  : '${worker.name} is suspended and restricted from task assignment.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Disabled Icon
            SizedBox(
              width: 26,
              height: 26,
              child: Icon(
                isBusy ? Icons.lock_outline_rounded : Icons.block_rounded,
                color: const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Muted Avatar
            UserAvatar(
              name: worker.name,
              size: 44,
              backgroundColor: const Color(0xFFF1F5F9),
              textColor: const Color(0xFF94A3B8),
              fontSize: 15,
            ),
            const SizedBox(width: 14),

            // Muted Name and Employee ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $employeeDisplayId',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFCBD5E1),
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
}
