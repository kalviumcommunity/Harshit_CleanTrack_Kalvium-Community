import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../models/task_model.dart';
import '../models/task_assignment_model.dart';
import 'auth_service.dart';
import 'ward_seed_service.dart';

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

  /// Assigns a user to a ward (activating pending supervisor to Assigned or worker to Available)
  Future<bool> assignUserToWard({
    required String userId,
    required String wardId,
    required UserRole role,
  }) async {
    final UserStatus newStatus = (role == UserRole.supervisor)
        ? UserStatus.assigned
        : UserStatus.available;

    final cleanWardName = formatWardDisplayName(wardId);

    // 1. In-memory user update
    final idx = _inMemoryUsers.indexWhere((u) => u.userId == userId);
    if (idx != -1) {
      _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
        wardId: wardId,
        wardName: cleanWardName,
        status: newStatus,
      );
      AuthService().updateUser(_inMemoryUsers[idx]);
    } else {
      final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == userId);
      if (authIdx != -1) {
        final updated = AuthService().registeredUsers[authIdx].copyWith(
          wardId: wardId,
          wardName: cleanWardName,
          status: newStatus,
        );
        AuthService().updateUser(updated);
        _inMemoryUsers.add(updated);
      }
    }

    // 2. In-memory ward update (if supervisor, link supervisor to ward)
    if (role == UserRole.supervisor) {
      final wardIdx = _inMemoryWards.indexWhere((w) => w.wardId == wardId || w.name == cleanWardName);
      if (wardIdx != -1) {
        _inMemoryWards[wardIdx] = _inMemoryWards[wardIdx].copyWith(
          name: cleanWardName,
          supervisorId: userId,
        );
      } else {
        final defWard = defaultHospitalWards.firstWhere(
          (w) => w.wardId == wardId || w.name == cleanWardName,
          orElse: () => WardModel(wardId: wardId, name: cleanWardName),
        );
        _inMemoryWards.add(defWard.copyWith(supervisorId: userId));
      }
    }

    // 3. Firestore persistence
    if (isFirebaseAvailable) {
      try {
        final userUpdate = <String, dynamic>{
          'wardId': wardId,
          'wardName': cleanWardName,
          'status': newStatus.displayName,
          'wardRef': _wardsCollection.doc(wardId),
        };
        await _usersCollection.doc(userId).update(userUpdate);

        if (role == UserRole.supervisor) {
          await _wardsCollection.doc(wardId).set({
            'name': cleanWardName,
            'supervisorId': userId,
            'supervisorRef': _usersCollection.doc(userId),
          }, SetOptions(merge: true));
        }
        return true;
      } catch (e) {
        debugPrint('Error assigning user to ward in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Streams pending users awaiting ward assignment / activation
  Stream<List<UserModel>> streamPendingUsers({UserRole? role}) {
    if (isFirebaseAvailable) {
      return _usersCollection.snapshots().map((snapshot) {
        final list = <UserModel>[];
        final seenIds = <String>{};

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final user = UserModel.fromMap(data, doc.id);
          if (user.status == UserStatus.pending) {
            if (role == null || user.role == role) {
              list.add(user);
              seenIds.add(user.userId);
              if (user.employeeId.isNotEmpty) {
                seenIds.add(user.employeeId.toLowerCase());
              }
              if (user.email.isNotEmpty) {
                seenIds.add(user.email.toLowerCase());
              }
            }
          }
        }

        for (final u in [..._inMemoryUsers, ...AuthService().registeredUsers]) {
          final isSeen = seenIds.contains(u.userId) ||
              (u.employeeId.isNotEmpty && seenIds.contains(u.employeeId.toLowerCase())) ||
              (u.email.isNotEmpty && seenIds.contains(u.email.toLowerCase()));
          if (!isSeen && u.status == UserStatus.pending) {
            if (role == null || u.role == role) {
              list.add(u);
              seenIds.add(u.userId);
            }
          }
        }

        return list;
      });
    }

    final all = <UserModel>[..._inMemoryUsers, ...AuthService().registeredUsers];
    final unique = <String, UserModel>{};
    for (final u in all) {
      if (u.status == UserStatus.pending) {
        if (role == null || u.role == role) {
          unique[u.userId] = u;
        }
      }
    }
    return Stream.value(unique.values.toList());
  }

  /// Seeds demo pending personnel when needed for demonstration/testing
  void seedDemoPendingUsers() {
    final demoUsers = [
      UserModel(
        userId: 'sup-012',
        name: 'Neha Sharma',
        employeeId: 'SUP-012',
        email: 'neha.sharma@cleantrack.org',
        role: UserRole.supervisor,
        status: UserStatus.pending,
      ),
      UserModel(
        userId: 'wrk-125',
        name: 'Ravi Kumar',
        employeeId: 'WRK-125',
        email: 'ravi.kumar@cleantrack.org',
        role: UserRole.worker,
        status: UserStatus.pending,
      ),
      UserModel(
        userId: 'wrk-128',
        name: 'Vikram Patel',
        employeeId: 'WRK-128',
        email: 'vikram.patel@cleantrack.org',
        role: UserRole.worker,
        status: UserStatus.pending,
      ),
    ];

    for (final user in demoUsers) {
      if (!_inMemoryUsers.any((u) => u.employeeId == user.employeeId)) {
        _inMemoryUsers.add(user);
        AuthService().updateUser(user);
      }
    }
  }

  /// Permanently deletes/rejects a user registration from Firestore and memory
  Future<bool> deleteUser(String userId, {String? employeeId, String? email}) async {
    try {
      _inMemoryUsers.removeWhere((u) =>
          u.userId == userId ||
          (employeeId != null &&
              employeeId.isNotEmpty &&
              u.employeeId.trim().toLowerCase() == employeeId.trim().toLowerCase()) ||
          (email != null &&
              email.isNotEmpty &&
              u.email.trim().toLowerCase() == email.trim().toLowerCase()));

      AuthService().removeUser(userId, employeeId: employeeId, email: email);

      if (isFirebaseAvailable) {
        // 1. Direct document deletion by userId
        try {
          await _usersCollection.doc(userId).delete();
        } catch (e) {
          debugPrint('Direct doc delete failed ($e)');
        }

        // 2. Also clean up by employeeId query if present
        if (employeeId != null && employeeId.isNotEmpty) {
          try {
            final query = await _usersCollection.where('employeeId', isEqualTo: employeeId).get();
            for (final doc in query.docs) {
              try {
                await doc.reference.delete();
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('EmployeeId cleanup caught: $e');
          }
        }

        // 3. Also clean up by email query if present
        if (email != null && email.isNotEmpty) {
          try {
            final cleanEmail = email.trim().toLowerCase();
            final query = await _usersCollection.where('email', isEqualTo: cleanEmail).get();
            for (final doc in query.docs) {
              try {
                await doc.reference.delete();
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('Email cleanup caught: $e');
          }
        }

        // 4. Unlink any ward where this user was supervisor
        try {
          final wardQuery = await _wardsCollection.where('supervisorId', isEqualTo: userId).get();
          for (final doc in wardQuery.docs) {
            await doc.reference.update({'supervisorId': null});
          }
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('deleteUser caught general error: $e');
      return true;
    }
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
    if (wardId.isEmpty) return null;
    if (isFirebaseAvailable) {
      try {
        final doc = await _wardsCollection.doc(wardId).get();
        if (doc.exists && doc.data() != null) {
          return WardModel.fromMap(doc.data()!, doc.id);
        }
        // Also check uppercase Wards collection or formatted name document
        final docW = await firestore.collection('Wards').doc(wardId).get();
        if (docW.exists && docW.data() != null) {
          return WardModel.fromMap(docW.data()!, docW.id);
        }
      } catch (e) {
        debugPrint('Error fetching ward from Firestore: $e');
      }
    }
    final clean = formatWardDisplayName(wardId);
    final memWard = _inMemoryWards.where((w) => w.wardId == wardId || w.name == clean || w.wardId == clean);
    if (memWard.isNotEmpty) return memWard.first;

    final defWard = defaultHospitalWards.where((w) => w.wardId == wardId || w.name == clean);
    if (defWard.isNotEmpty) return defWard.first;

    return WardModel(wardId: wardId, name: clean);
  }

  /// Streams a ward by ID from Firestore
  Stream<WardModel?> streamWard(String wardId) {
    if (isFirebaseAvailable) {
      return _wardsCollection.doc(wardId).snapshots().map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          return WardModel.fromMap(snapshot.data()!, snapshot.id);
        }
        return defaultHospitalWards.firstWhere(
          (w) => w.wardId == wardId || w.name == formatWardDisplayName(wardId),
          orElse: () => WardModel(wardId: wardId, name: formatWardDisplayName(wardId)),
        );
      });
    }
    final clean = formatWardDisplayName(wardId);
    final memWard = _inMemoryWards.where((w) => w.wardId == wardId || w.name == clean || w.wardId == clean);
    return Stream.value(memWard.isNotEmpty
        ? memWard.first
        : defaultHospitalWards.firstWhere(
            (w) => w.wardId == wardId || w.name == clean,
            orElse: () => WardModel(wardId: wardId, name: clean),
          ));
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

  /// Default hospital wards list (ICU 1, ICU 2, ICU 3, Minor OT, OT 1, OT 2)
  static List<WardModel> get defaultHospitalWards => WardSeedService.defaultHospitalWards;

  /// Seeds default hospital wards into Cloud Firestore if the wards collection is empty
  Future<bool> seedInitialWardsToFirestore({bool overwrite = false}) async {
    if (!isFirebaseAvailable) {
      if (overwrite) {
        for (final ward in defaultHospitalWards) {
          seedWard(ward);
        }
      }
      return true;
    }

    for (final ward in defaultHospitalWards) {
      seedWard(ward);
    }

    return await WardSeedService.seedWards(
      overwrite: overwrite,
      firestoreInstance: firestore,
    );
  }

  /// Creates a new ward in Firestore and in-memory (PRD W04)
  Future<WardModel?> createWard(String wardName) async {
    final cleanName = formatWardDisplayName(wardName);
    final slug = cleanName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+ward$'), '')
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final wardId = slug.startsWith('ward_') ? slug : 'ward_$slug';

    final newWard = WardModel(
      wardId: wardId,
      name: cleanName,
      createdAt: DateTime.now(),
    );

    seedWard(newWard);

    if (isFirebaseAvailable) {
      try {
        await _wardsCollection.doc(wardId).set(
          newWard.toJson(),
          SetOptions(merge: true),
        );
        debugPrint('Successfully created ward in Firestore: $cleanName ($wardId)');
      } catch (e) {
        debugPrint('Error creating ward in Firestore: $e');
      }
    }

    return newWard;
  }

  /// Deletes a ward from Firestore and in-memory
  Future<bool> deleteWard(String wardId) async {
    _inMemoryWards.removeWhere((w) => w.wardId == wardId);
    if (isFirebaseAvailable) {
      try {
        await _wardsCollection.doc(wardId).delete();
        return true;
      } catch (e) {
        debugPrint('Error deleting ward from Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Gets all wards from Firestore or memory, auto-seeding to Firestore if empty
  Future<List<WardModel>> getWards() async {
    if (isFirebaseAvailable) {
      try {
        final query = await _wardsCollection.get();
        if (query.docs.isNotEmpty) {
          if (query.docs.any((d) =>
              (d.data()['name'] ?? '').toString().contains('Ward') ||
              d.data().containsKey('wardName') ||
              d.data().containsKey('id'))) {
            unawaited(seedInitialWardsToFirestore(overwrite: true));
          }
          return query.docs.map((doc) => WardModel.fromMap(doc.data(), doc.id)).toList();
        } else {
          // Check uppercase 'Wards' as fallback
          final altQuery = await firestore.collection('Wards').get();
          if (altQuery.docs.isNotEmpty) {
            return altQuery.docs.map((doc) => WardModel.fromMap(doc.data(), doc.id)).toList();
          }
          await seedInitialWardsToFirestore();
          final reQuery = await _wardsCollection.get();
          if (reQuery.docs.isNotEmpty) {
            return reQuery.docs.map((doc) => WardModel.fromMap(doc.data(), doc.id)).toList();
          }
        }
      } catch (e) {
        debugPrint('Error getting wards from Firestore: $e');
      }
    }
    if (_inMemoryWards.isNotEmpty) {
      return List.unmodifiable(_inMemoryWards);
    }
    return defaultHospitalWards;
  }

  /// Streams all wards in real time
  Stream<List<WardModel>> streamWards() {
    if (isFirebaseAvailable) {
      return _wardsCollection.snapshots().map((snap) {
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) => WardModel.fromMap(d.data(), d.id)).toList();
        }
        return defaultHospitalWards;
      });
    }
    if (_inMemoryWards.isNotEmpty) {
      return Stream.value(List.unmodifiable(_inMemoryWards));
    }
    return Stream.value(defaultHospitalWards);
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
      status: AssignmentStatus.pending,
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

  /// Automatically marks an unverified assignment as Auto Verified after 1 hour (PRD 6.5 & V03 & AC10)
  Future<bool> autoVerifyTaskAssignment({
    required String assignmentId,
    required String taskId,
    required String workerId,
  }) async {
    final now = DateTime.now();

    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.autoVerified,
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
          'status': AssignmentStatus.autoVerified.displayName,
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
        debugPrint('Error auto-verifying task assignment in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Checks and transitions assignments unverified for >1 hour to Auto Verified (PRD 6.5 & V03)
  Future<void> checkAndAutoVerifyAssignments() async {
    final threshold = DateTime.now().subtract(const Duration(hours: 1));

    for (int i = 0; i < _inMemoryAssignments.length; i++) {
      final a = _inMemoryAssignments[i];
      if (a.status == AssignmentStatus.pendingVerification &&
          a.completedAt != null &&
          a.completedAt!.isBefore(threshold)) {
        await autoVerifyTaskAssignment(
          assignmentId: a.assignmentId,
          taskId: a.taskId,
          workerId: a.workerId,
        );
      }
    }

    if (isFirebaseAvailable) {
      try {
        final snap = await _taskAssignmentsCollection
            .where('status', isEqualTo: AssignmentStatus.pendingVerification.displayName)
            .get();
        for (final doc in snap.docs) {
          final assignment = TaskAssignmentModel.fromMap(doc.data(), doc.id);
          if (assignment.completedAt != null && assignment.completedAt!.isBefore(threshold)) {
            await autoVerifyTaskAssignment(
              assignmentId: assignment.assignmentId,
              taskId: assignment.taskId,
              workerId: assignment.workerId,
            );
          }
        }
      } catch (e) {
        debugPrint('Note during auto-verify scan: $e');
      }
    }
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
      status: AssignmentStatus.pending,
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
      status: AssignmentStatus.pending,
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
  /// Streams real-time workforce statistics for the Admin Dashboard from Firestore
  Stream<AdminDashboardStats> streamAdminDashboardStats() {
    AdminDashboardStats calculateFallbackStats() {
      final inMemory = AuthService().registeredUsers;
      int supervisors = 0;
      int workers = 0;
      int pending = 0;
      for (final u in inMemory) {
        if (u.status == UserStatus.pending) {
          pending++;
        } else if (u.status != UserStatus.suspended) {
          if (u.role == UserRole.supervisor) supervisors++;
          if (u.role == UserRole.worker) workers++;
        }
      }
      return AdminDashboardStats(
        totalWards: _inMemoryWards.length,
        totalSupervisors: supervisors,
        totalWorkers: workers,
        pendingRegistrations: pending,
      );
    }

    if (!isFirebaseAvailable) {
      return Stream.value(calculateFallbackStats());
    }

    final controller = StreamController<AdminDashboardStats>.broadcast();
    StreamSubscription? usersSub;
    StreamSubscription? wardsSub;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> latestUsers = [];
    int latestWardsCount = 0;

    void recalculateAndEmit() {
      if (controller.isClosed) return;
      int supervisors = 0;
      int workers = 0;
      int pending = 0;
      final seenUserIds = <String>{};

      for (final doc in latestUsers) {
        seenUserIds.add(doc.id);
        final data = doc.data();
        final roleStr = (data['role'] ?? '').toString().toLowerCase();
        final statusStr = (data['status'] ?? '').toString().toLowerCase();

        final isPending = statusStr == 'pending' || statusStr.contains('pending');
        final isSuspended = statusStr == 'suspended' || statusStr.contains('suspended');

        if (isPending) {
          pending++;
        }

        // Do NOT count pending or suspended personnel in active workforce
        if (!isPending && !isSuspended) {
          if (roleStr == 'supervisor' || roleStr.contains('supervisor')) {
            supervisors++;
          } else if (roleStr == 'worker' || roleStr.contains('worker')) {
            workers++;
          }
        }
      }

      for (final u in AuthService().registeredUsers) {
        if (!seenUserIds.contains(u.userId)) {
          if (u.status == UserStatus.pending) {
            pending++;
          } else if (u.status != UserStatus.suspended) {
            if (u.role == UserRole.supervisor) supervisors++;
            if (u.role == UserRole.worker) workers++;
          }
        }
      }

      int finalWards = latestWardsCount;
      if (finalWards == 0 && _inMemoryWards.isNotEmpty) {
        finalWards = _inMemoryWards.length;
      }
      if (finalWards == 0 && isFirebaseAvailable) {
        finalWards = defaultHospitalWards.length;
      }

      controller.add(AdminDashboardStats(
        totalWards: finalWards,
        totalSupervisors: supervisors,
        totalWorkers: workers,
        pendingRegistrations: pending,
      ));
    }

    // Initial check on both collections & auto-seed if empty
    Future.microtask(() async {
      try {
        final wSnap = await _wardsCollection.get();
        if (wSnap.docs.isNotEmpty) {
          latestWardsCount = wSnap.docs.length;
          if (wSnap.docs.any((d) =>
              (d.data()['name'] ?? '').toString().contains('Ward') ||
              d.data().containsKey('wardName') ||
              d.data().containsKey('id'))) {
            await seedInitialWardsToFirestore(overwrite: true);
          }
        } else {
          // If empty, auto-seed default hospital wards to Cloud Firestore
          await seedInitialWardsToFirestore();
          final reSnap = await _wardsCollection.get();
          if (reSnap.docs.isNotEmpty) {
            latestWardsCount = reSnap.docs.length;
          } else {
            final wAltSnap = await firestore.collection('Wards').get();
            if (wAltSnap.docs.isNotEmpty) {
              latestWardsCount = wAltSnap.docs.length;
            }
          }
        }
        recalculateAndEmit();
      } catch (e) {
        debugPrint('Wards initial check error: $e');
        await seedInitialWardsToFirestore();
        try {
          final reSnap = await _wardsCollection.get();
          if (reSnap.docs.isNotEmpty) {
            latestWardsCount = reSnap.docs.length;
          }
        } catch (_) {}
        recalculateAndEmit();
      }
    });

    usersSub = _usersCollection.snapshots().listen(
      (snap) {
        latestUsers = snap.docs;
        recalculateAndEmit();
      },
      onError: (e) {
        debugPrint('Users snapshot error in admin stats: $e');
        if (!controller.isClosed) {
          controller.add(calculateFallbackStats());
        }
      },
    );

    wardsSub = _wardsCollection.snapshots().listen(
      (snap) {
        if (snap.docs.isNotEmpty) {
          latestWardsCount = snap.docs.length;
          recalculateAndEmit();
        } else {
          firestore.collection('Wards').get().then((wAlt) {
            if (wAlt.docs.isNotEmpty) {
              latestWardsCount = wAlt.docs.length;
            }
            recalculateAndEmit();
          }).catchError((_) {
            recalculateAndEmit();
          });
        }
      },
      onError: (e) {
        debugPrint('Wards snapshot error in admin stats: $e');
      },
    );

    controller.onCancel = () {
      usersSub?.cancel();
      wardsSub?.cancel();
    };

    return controller.stream;
  }

  // ==================== WORKER TASK OPERATIONS ====================

  /// Retrieves the active task assignment for a given worker from Firestore or in-memory
  Future<TaskAssignmentModel?> getActiveAssignmentForWorker(String workerId) async {
    // First check in-memory assignments (for tests and offline mode)
    final inMemoryMatch = _inMemoryAssignments.where((a) =>
        a.workerId == workerId &&
        a.status != AssignmentStatus.verified &&
        a.status != AssignmentStatus.autoVerified);
    if (inMemoryMatch.isNotEmpty) {
      return inMemoryMatch.last;
    }

    if (!isFirebaseAvailable) return null;

    try {
      final query = await _taskAssignmentsCollection
          .where('workerId', isEqualTo: workerId)
          .get();

      if (query.docs.isNotEmpty) {
        final assignments = query.docs
            .map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id))
            .where((a) =>
                a.status != AssignmentStatus.verified &&
                a.status != AssignmentStatus.autoVerified)
            .toList();
        if (assignments.isNotEmpty) {
          return assignments.last;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active assignment for worker from Firestore: $e');
      return null;
    }
  }

  /// Marks an assignment as completed / pending verification by the worker (PRD 6.4 & C01)
  Future<bool> markAssignmentCompleted(String assignmentId) async {
    final now = DateTime.now();
    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.pendingVerification,
        completedAt: now,
      );
    }

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.pendingVerification.displayName,
          'completedAt': now.toIso8601String(),
        });
        return true;
      } catch (e) {
        debugPrint('Error marking assignment completed in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Fetches a task document by ID from Firestore or in-memory
  Future<TaskModel?> getTask(String taskId) async {
    final inMem = _inMemoryTasks.where((t) => t.taskId == taskId);
    if (inMem.isNotEmpty) return inMem.first;

    if (!isFirebaseAvailable) return null;

    try {
      final doc = await _tasksCollection.doc(taskId).get();
      if (doc.exists && doc.data() != null) {
        return TaskModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting task from Firestore: $e');
      return null;
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