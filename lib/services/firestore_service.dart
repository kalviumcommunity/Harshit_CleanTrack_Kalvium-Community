import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../models/task_model.dart';
import '../models/task_assignment_model.dart';
import 'auth_service.dart';

class SupervisorDashboardStats {
  final int availableWorkers;
  final int busyWorkers;
  final int pendingVerify;
  final int overdueTasks;
  final String wardName;

  const SupervisorDashboardStats({
    this.availableWorkers = 0,
    this.busyWorkers = 0,
    this.pendingVerify = 0,
    this.overdueTasks = 0,
    this.wardName = 'ICU Ward',
  });
}

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore get firestore => _firestoreInstance ?? FirebaseFirestore.instance;

  void setFirestore(FirebaseFirestore firestore) {
    _firestoreInstance = firestore;
  }

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _wardsCollection =>
      firestore.collection('wards');

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      firestore.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _taskAssignmentsCollection =>
      firestore.collection('taskAssignments');

  // In-memory data structures for testing & offline mode
  final List<UserModel> _inMemoryUsers = [];
  final List<WardModel> _inMemoryWards = [];
  final List<TaskModel> _inMemoryTasks = [];
  final List<TaskAssignmentModel> _inMemoryAssignments = [];

  void clearAllData() {
    _inMemoryUsers.clear();
    _inMemoryWards.clear();
    _inMemoryTasks.clear();
    _inMemoryAssignments.clear();
  }

  void seedWard(WardModel ward) {
    _inMemoryWards.removeWhere((w) => w.wardId == ward.wardId);
    _inMemoryWards.add(ward);
  }

  void seedWorker(UserModel worker) {
    _inMemoryUsers.removeWhere((u) => u.userId == worker.userId);
    _inMemoryUsers.add(worker);
  }

  void seedTask(TaskModel task) {
    _inMemoryTasks.removeWhere((t) => t.taskId == task.taskId);
    _inMemoryTasks.add(task);
  }

  void seedAssignment(TaskAssignmentModel assignment) {
    _inMemoryAssignments.removeWhere((a) => a.assignmentId == assignment.assignmentId);
    _inMemoryAssignments.add(assignment);
  }

  // ==================== USER OPERATIONS ====================

  /// Saves or updates a user profile in Firestore
  Future<bool> saveUserProfile(UserModel user) async {
    _inMemoryUsers.removeWhere((u) => u.userId == user.userId);
    _inMemoryUsers.add(user);

    if (isFirebaseAvailable) {
      try {
        await _usersCollection.doc(user.userId).set(
              user.toJson(),
              SetOptions(merge: true),
            );
        return true;
      } catch (e) {
        debugPrint('Error saving user profile to Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Fetches a user profile document from Firestore by user ID
  Future<UserModel?> getUserProfile(String uid) async {
    if (isFirebaseAvailable) {
      try {
        final doc = await _usersCollection.doc(uid).get();
        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data()!, doc.id);
        }
        return null;
      } catch (e) {
        debugPrint('Error fetching user profile from Firestore: $e');
        return null;
      }
    }
    final memUser = _inMemoryUsers.where((u) => u.userId == uid);
    return memUser.isNotEmpty ? memUser.first : null;
  }

  /// Fetches a user profile document from Firestore by user email
  Future<UserModel?> getUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
        }
        return null;
      } catch (e) {
        debugPrint('Error fetching user profile by email from Firestore: $e');
        return null;
      }
    }
    final memUser = _inMemoryUsers.where((u) => u.email.toLowerCase() == cleanEmail);
    return memUser.isNotEmpty ? memUser.first : null;
  }

  /// Real-time stream of a user's profile
  Stream<UserModel?> streamUserProfile(String uid) {
    if (isFirebaseAvailable) {
      return _usersCollection.doc(uid).snapshots().map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          return UserModel.fromMap(snapshot.data()!, snapshot.id);
        }
        return null;
      });
    }
    final memUser = _inMemoryUsers.where((u) => u.userId == uid);
    return Stream.value(memUser.isNotEmpty ? memUser.first : null);
  }

  /// Updates the status of a user
  Future<bool> updateStatus(String uid, UserStatus status) async {
    final idx = _inMemoryUsers.indexWhere((u) => u.userId == uid);
    if (idx != -1) {
      _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(status: status);
    }

    if (isFirebaseAvailable) {
      try {
        await _usersCollection.doc(uid).update({
          'status': status.displayName,
        });
        return true;
      } catch (e) {
        debugPrint('Error updating user status in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Assigns a ward to a user
  Future<bool> assignWard(String uid, String wardId, {UserStatus? newStatus}) async {
    final idx = _inMemoryUsers.indexWhere((u) => u.userId == uid);
    if (idx != -1) {
      _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
        wardId: wardId,
        status: newStatus ?? _inMemoryUsers[idx].status,
      );
    }

    if (isFirebaseAvailable) {
      try {
        final updateData = <String, dynamic>{
          'wardId': wardId,
        };
        if (newStatus != null) {
          updateData['status'] = newStatus.displayName;
        }
        await _usersCollection.doc(uid).update(updateData);
        return true;
      } catch (e) {
        debugPrint('Error assigning ward in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Checks if an employee ID is registered in Firestore
  Future<bool> isEmployeeIdRegistered(String employeeId) async {
    final cleanId = employeeId.trim().toUpperCase();
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('employeeId', isEqualTo: cleanId)
            .limit(1)
            .get();
        return query.docs.isNotEmpty;
      } catch (e) {
        debugPrint('Error checking employee ID uniqueness in Firestore: $e');
        return false;
      }
    }
    return _inMemoryUsers.any((u) => u.employeeId.toUpperCase() == cleanId);
  }

  /// Gets users by status
  Future<List<UserModel>> getUsersByStatus(UserStatus status) async {
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('status', isEqualTo: status.displayName)
            .get();
        return query.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList();
      } catch (e) {
        debugPrint('Error querying users by status from Firestore: $e');
        return [];
      }
    }
    return _inMemoryUsers.where((u) => u.status == status).toList();
  }

  // ==================== WARD OPERATIONS ====================

  /// Fetches a ward by ID from Firestore
  Future<WardModel?> getWard(String wardId) async {
    if (isFirebaseAvailable) {
      try {
        final doc = await _wardsCollection.doc(wardId).get();
        if (doc.exists && doc.data() != null) {
          return WardModel.fromMap(doc.data()!, doc.id);
        }
        return null;
      } catch (e) {
        debugPrint('Error fetching ward from Firestore: $e');
        return null;
      }
    }
    final memWard = _inMemoryWards.where((w) => w.wardId == wardId);
    return memWard.isNotEmpty ? memWard.first : null;
  }

  /// Streams a ward by ID from Firestore
  Stream<WardModel?> streamWard(String wardId) {
    if (isFirebaseAvailable) {
      return _wardsCollection.doc(wardId).snapshots().map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          return WardModel.fromMap(snapshot.data()!, snapshot.id);
        }
        return null;
      });
    }
    final memWard = _inMemoryWards.where((w) => w.wardId == wardId);
    return Stream.value(memWard.isNotEmpty ? memWard.first : null);
  }

  /// Saves or updates a ward document in Firestore
  Future<bool> saveWard(WardModel ward) async {
    seedWard(ward);
    if (isFirebaseAvailable) {
      try {
        await _wardsCollection.doc(ward.wardId).set(ward.toJson(), SetOptions(merge: true));
        return true;
      } catch (e) {
        debugPrint('Error saving ward to Firestore: $e');
        return false;
      }
    }
    return true;
  }

  // ==================== WORKER OPERATIONS FOR SUPERVISOR ====================

  /// Gets all workers assigned to a specific ward from Firestore
  Future<List<UserModel>> getWorkersByWard(String wardId) async {
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('role', isEqualTo: 'Worker')
            .where('wardId', isEqualTo: wardId)
            .get();
        return query.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      } catch (e) {
        debugPrint('Error fetching workers by ward from Firestore: $e');
        return [];
      }
    }
    final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
    final unique = <String, UserModel>{};
    for (final u in all) {
      if (u.role == UserRole.worker && (wardId.isEmpty || u.wardId == wardId)) {
        unique[u.userId] = u;
      }
    }
    return unique.values.toList();
  }

  /// Streams workers assigned to a specific ward from Firestore
  Stream<List<UserModel>> streamWorkersByWard(String wardId) {
    if (isFirebaseAvailable) {
      if (wardId.isEmpty) {
        return _usersCollection
            .where('role', isEqualTo: 'Worker')
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
      }
      return _usersCollection
          .where('role', isEqualTo: 'Worker')
          .where('wardId', isEqualTo: wardId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
      });
    }
    final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
    final unique = <String, UserModel>{};
    for (final u in all) {
      if (u.role == UserRole.worker && (wardId.isEmpty || u.wardId == wardId)) {
        unique[u.userId] = u;
      }
    }
    return Stream.value(unique.values.toList());
  }

  // ==================== TASK & ASSIGNMENT OPERATIONS ====================

  /// Streams tasks for a specific ward from Firestore
  Stream<List<TaskModel>> streamTasksByWard(String wardId) {
    if (isFirebaseAvailable) {
      if (wardId.isEmpty) {
        return _tasksCollection.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => TaskModel.fromMap(doc.data(), doc.id)).toList();
        });
      }
      return _tasksCollection
          .where('wardId', isEqualTo: wardId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => TaskModel.fromMap(doc.data(), doc.id)).toList();
      });
    }
    final filtered = _inMemoryTasks.where((t) => wardId.isEmpty || t.wardId == wardId).toList();
    return Stream.value(filtered);
  }

  /// Streams task assignments for a specific ward from Firestore
  Stream<List<TaskAssignmentModel>> streamAssignmentsByWard(String wardId) {
    if (isFirebaseAvailable) {
      if (wardId.isEmpty) {
        return _taskAssignmentsCollection.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id)).toList();
        });
      }
      return _taskAssignmentsCollection
          .where('wardId', isEqualTo: wardId)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id)).toList();
      });
    }
    final filtered = _inMemoryAssignments.where((a) => wardId.isEmpty || a.wardId == wardId).toList();
    return Stream.value(filtered);
  }

  /// Streams live Supervisor Dashboard statistics from Firestore
  Stream<SupervisorDashboardStats> streamSupervisorStats(String wardId) async* {
    SupervisorDashboardStats getCalculatedStats(List<UserModel> workers, List<TaskAssignmentModel> assignments, String wardName) {
      int available = 0;
      int busy = 0;
      for (final w in workers) {
        if (w.status == UserStatus.available) available++;
        if (w.status == UserStatus.busy) busy++;
      }

      int pendingVerify = 0;
      int overdue = 0;
      final now = DateTime.now();

      for (final a in assignments) {
        if (a.status == AssignmentStatus.pendingVerification) {
          pendingVerify++;
        }
        if (a.status != AssignmentStatus.verified && a.status != AssignmentStatus.autoVerified) {
          if (a.deadline.isBefore(now)) {
            overdue++;
          }
        }
      }

      return SupervisorDashboardStats(
        availableWorkers: available,
        busyWorkers: busy,
        pendingVerify: pendingVerify,
        overdueTasks: overdue,
        wardName: wardName,
      );
    }

    if (!isFirebaseAvailable) {
      final workers = _inMemoryUsers.where((u) => u.role == UserRole.worker && (wardId.isEmpty || u.wardId == wardId)).toList();
      final assignments = _inMemoryAssignments.where((a) => wardId.isEmpty || a.wardId == wardId).toList();
      final ward = _inMemoryWards.where((w) => w.wardId == wardId);
      final wardName = ward.isNotEmpty ? ward.first.name : (wardId.isNotEmpty ? wardId : 'ICU Ward');
      yield getCalculatedStats(workers, assignments, wardName);
      return;
    }

    try {
      await for (final workersSnap in (wardId.isNotEmpty
          ? _usersCollection.where('role', isEqualTo: 'Worker').where('wardId', isEqualTo: wardId).snapshots()
          : _usersCollection.where('role', isEqualTo: 'Worker').snapshots())) {
        
        final workers = workersSnap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
        
        List<TaskAssignmentModel> assignments = [];
        try {
          final aSnap = wardId.isNotEmpty
              ? await _taskAssignmentsCollection.where('wardId', isEqualTo: wardId).get()
              : await _taskAssignmentsCollection.get();
          assignments = aSnap.docs.map((d) => TaskAssignmentModel.fromMap(d.data(), d.id)).toList();
        } catch (_) {}

        String wardName = wardId.isNotEmpty ? wardId : 'ICU Ward';
        try {
          if (wardId.isNotEmpty) {
            final wDoc = await _wardsCollection.doc(wardId).get();
            if (wDoc.exists && wDoc.data() != null) {
              wardName = wDoc.data()!['name'] ?? wardId;
            }
          }
        } catch (_) {}

        yield getCalculatedStats(workers, assignments, wardName);
      }
    } catch (e) {
      debugPrint('Error streaming supervisor stats: $e');
      yield const SupervisorDashboardStats();
    }
  }

  /// Creates a new Task and its initial Task Assignment record in Firestore (PRD 6.3 & S02)
  Future<TaskAssignmentModel?> createTaskAndAssignment({
    required String wardId,
    required String supervisorId,
    required String title,
    required String description,
    required String workerId,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    final taskId = 'task_${now.millisecondsSinceEpoch}';
    final assignmentId = 'assign_${now.millisecondsSinceEpoch}';

    final task = TaskModel(
      taskId: taskId,
      wardId: wardId,
      title: title.trim(),
      description: description.trim(),
      createdAt: now,
      status: TaskStatus.open,
      currentAssignmentId: assignmentId,
    );

    final assignment = TaskAssignmentModel(
      assignmentId: assignmentId,
      taskId: taskId,
      workerId: workerId,
      wardId: wardId,
      assignmentNumber: 1,
      attempts: 1,
      deadline: deadline,
      assignedAt: now,
      status: AssignmentStatus.pendingVerification,
    );

    seedTask(task);
    seedAssignment(assignment);

    final userIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
    if (userIdx != -1) {
      _inMemoryUsers[userIdx] = _inMemoryUsers[userIdx].copyWith(
        status: UserStatus.busy,
        activeAssignmentId: assignmentId,
      );
    }

    if (isFirebaseAvailable) {
      try {
        await _tasksCollection.doc(taskId).set(task.toJson());
        await _taskAssignmentsCollection.doc(assignmentId).set(assignment.toJson());
        await _usersCollection.doc(workerId).update({
          'status': UserStatus.busy.displayName,
          'activeAssignmentId': assignmentId,
        });
      } catch (e) {
        debugPrint('Error creating task and assignment in Firestore: $e');
      }
    }

    return assignment;
  }

  /// Verifies a completed task assignment in Firestore (PRD 6.5 & S03 & AC09)
  Future<bool> verifyTaskAssignment({
    required String assignmentId,
    required String taskId,
    required String workerId,
  }) async {
    final now = DateTime.now();

    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.verified,
        verifiedAt: now,
      );
    }

    final tIdx = _inMemoryTasks.indexWhere((t) => t.taskId == taskId);
    if (tIdx != -1) {
      _inMemoryTasks[tIdx] = _inMemoryTasks[tIdx].copyWith(
        status: TaskStatus.closed,
      );
    }

    final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
    if (uIdx != -1) {
      _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
        status: UserStatus.available,
        activeAssignmentId: null,
      );
    }

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.verified.displayName,
          'verifiedAt': now.toIso8601String(),
        });
        await _tasksCollection.doc(taskId).update({
          'status': TaskStatus.closed.displayName,
        });
        await _usersCollection.doc(workerId).update({
          'status': UserStatus.available.displayName,
          'activeAssignmentId': null,
        });
        return true;
      } catch (e) {
        debugPrint('Error verifying task assignment in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Reassigns task to the same worker with mandatory feedback in Firestore (PRD 6.6 & S04 & AC11)
  Future<TaskAssignmentModel?> reassignToSameWorker({
    required String assignmentId,
    required String taskId,
    required String workerId,
    required String wardId,
    required String supervisorId,
    required String feedback,
    required DateTime newDeadline,
    required int currentAttempts,
    required int currentAssignmentNumber,
  }) async {
    final newAttempts = currentAttempts + 1;

    // Check 3 attempts limit (PRD SU02 / AC14 / E05)
    if (newAttempts > 3) {
      final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (aIdx != -1) {
        _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
          status: AssignmentStatus.notCompleted,
        );
      }
      final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
      if (uIdx != -1) {
        _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
          status: UserStatus.suspended,
          activeAssignmentId: null,
        );
      }
      if (isFirebaseAvailable) {
        try {
          await _taskAssignmentsCollection.doc(assignmentId).update({
            'status': AssignmentStatus.notCompleted.displayName,
          });
          await _usersCollection.doc(workerId).update({
            'status': UserStatus.suspended.displayName,
            'activeAssignmentId': null,
          });
        } catch (_) {}
      }
      return null;
    }

    final now = DateTime.now();
    final newAssignmentId = 'assign_${now.millisecondsSinceEpoch}';

    final newAssignment = TaskAssignmentModel(
      assignmentId: newAssignmentId,
      taskId: taskId,
      workerId: workerId,
      wardId: wardId,
      assignmentNumber: currentAssignmentNumber + 1,
      attempts: newAttempts,
      supervisorFeedback: feedback.trim(),
      deadline: newDeadline,
      assignedAt: now,
      status: AssignmentStatus.pendingVerification,
    );

    seedAssignment(newAssignment);

    final tIdx = _inMemoryTasks.indexWhere((t) => t.taskId == taskId);
    if (tIdx != -1) {
      _inMemoryTasks[tIdx] = _inMemoryTasks[tIdx].copyWith(
        currentAssignmentId: newAssignmentId,
      );
    }

    final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
    if (uIdx != -1) {
      _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
        status: UserStatus.busy,
        activeAssignmentId: newAssignmentId,
      );
    }

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(newAssignmentId).set(newAssignment.toJson());
        await _tasksCollection.doc(taskId).update({
          'currentAssignmentId': newAssignmentId,
        });
        await _usersCollection.doc(workerId).update({
          'status': UserStatus.busy.displayName,
          'activeAssignmentId': newAssignmentId,
        });
      } catch (e) {
        debugPrint('Error reassigning to same worker in Firestore: $e');
      }
    }

    return newAssignment;
  }

  /// Reassigns task to another worker in Firestore (PRD 6.6 & S05 & AC12)
  Future<TaskAssignmentModel?> reassignToAnotherWorker({
    required String oldAssignmentId,
    required String taskId,
    required String failedWorkerId,
    required String newWorkerId,
    required String wardId,
    required String supervisorId,
    required DateTime newDeadline,
    required int currentAssignmentNumber,
  }) async {
    final now = DateTime.now();

    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == oldAssignmentId);
    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.notCompleted,
      );
    }

    final fIdx = _inMemoryUsers.indexWhere((u) => u.userId == failedWorkerId);
    if (fIdx != -1) {
      _inMemoryUsers[fIdx] = _inMemoryUsers[fIdx].copyWith(
        status: UserStatus.suspended,
        activeAssignmentId: null,
      );
    }

    final newAssignmentId = 'assign_${now.millisecondsSinceEpoch}';
    final newAssignment = TaskAssignmentModel(
      assignmentId: newAssignmentId,
      taskId: taskId,
      workerId: newWorkerId,
      wardId: wardId,
      assignmentNumber: currentAssignmentNumber + 1,
      attempts: 1,
      supervisorFeedback: null,
      deadline: newDeadline,
      assignedAt: now,
      status: AssignmentStatus.pendingVerification,
    );

    seedAssignment(newAssignment);

    final tIdx = _inMemoryTasks.indexWhere((t) => t.taskId == taskId);
    if (tIdx != -1) {
      _inMemoryTasks[tIdx] = _inMemoryTasks[tIdx].copyWith(
        currentAssignmentId: newAssignmentId,
      );
    }

    final nIdx = _inMemoryUsers.indexWhere((u) => u.userId == newWorkerId);
    if (nIdx != -1) {
      _inMemoryUsers[nIdx] = _inMemoryUsers[nIdx].copyWith(
        status: UserStatus.busy,
        activeAssignmentId: newAssignmentId,
      );
    }

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(oldAssignmentId).update({
          'status': AssignmentStatus.notCompleted.displayName,
        });
        await _usersCollection.doc(failedWorkerId).update({
          'status': UserStatus.suspended.displayName,
          'activeAssignmentId': null,
        });
        await _taskAssignmentsCollection.doc(newAssignmentId).set(newAssignment.toJson());
        await _tasksCollection.doc(taskId).update({
          'currentAssignmentId': newAssignmentId,
        });
        await _usersCollection.doc(newWorkerId).update({
          'status': UserStatus.busy.displayName,
          'activeAssignmentId': newAssignmentId,
        });
      } catch (e) {
        debugPrint('Error reassigning to another worker in Firestore: $e');
      }
    }

    return newAssignment;
  }

  /// Streams real-time workforce statistics for the Admin Dashboard from Firestore
  Stream<AdminDashboardStats> streamAdminDashboardStats() async* {
    AdminDashboardStats getFallbackStats() {
      final inMemory = AuthService().registeredUsers;
      int supervisors = 0;
      int workers = 0;
      int pending = 0;
      for (final u in inMemory) {
        if (u.role == UserRole.supervisor) supervisors++;
        if (u.role == UserRole.worker) workers++;
        if (u.status == UserStatus.pending) pending++;
      }
      return AdminDashboardStats(
        totalWards: _inMemoryWards.length,
        totalSupervisors: supervisors,
        totalWorkers: workers,
        pendingRegistrations: pending,
      );
    }

    if (!isFirebaseAvailable) {
      yield getFallbackStats();
      return;
    }

    yield getFallbackStats();

    try {
      await for (final usersSnap in _usersCollection.snapshots()) {
        int realWardsCount = 0;
        try {
          final wardsSnap = await _wardsCollection.get();
          realWardsCount = wardsSnap.docs.length;
        } catch (e) {
          debugPrint('Notice: Wards collection read in admin stats: $e');
        }

        int supervisors = 0;
        int workers = 0;
        int pending = 0;

        final seenUserIds = <String>{};

        for (final doc in usersSnap.docs) {
          seenUserIds.add(doc.id);
          final data = doc.data();
          final roleStr = (data['role'] ?? '').toString().toLowerCase();
          final statusStr = (data['status'] ?? '').toString().toLowerCase();

          if (roleStr.contains('supervisor') || roleStr == 'supervisor') {
            supervisors++;
          } else if (roleStr.contains('worker') || roleStr == 'worker') {
            workers++;
          }

          if (statusStr.contains('pending') || statusStr == 'pending') {
            pending++;
          }
        }

        for (final u in AuthService().registeredUsers) {
          if (!seenUserIds.contains(u.userId)) {
            if (u.role == UserRole.supervisor) supervisors++;
            if (u.role == UserRole.worker) workers++;
            if (u.status == UserStatus.pending) pending++;
          }
        }

        yield AdminDashboardStats(
          totalWards: realWardsCount,
          totalSupervisors: supervisors,
          totalWorkers: workers,
          pendingRegistrations: pending,
        );
      }
    } catch (e) {
      debugPrint('Firestore stream error in admin stats: $e');
      yield getFallbackStats();
    }
  }
}

/// Snapshot model for Admin Dashboard workforce overview
class AdminDashboardStats {
  final int totalWards;
  final int totalSupervisors;
  final int totalWorkers;
  final int pendingRegistrations;

  const AdminDashboardStats({
    this.totalWards = 0,
    this.totalSupervisors = 0,
    this.totalWorkers = 0,
    this.pendingRegistrations = 0,
  });
}
