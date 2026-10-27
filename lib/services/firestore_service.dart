import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/ward_model.dart';
import '../models/task_model.dart';
import '../models/task_assignment_model.dart';
import '../models/notification_model.dart';
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

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      firestore.collection('notifications');

  // In-memory data structures for testing & offline mode
  final List<UserModel> _inMemoryUsers = [];
  final List<WardModel> _inMemoryWards = [];
  final List<TaskModel> _inMemoryTasks = [];
  final List<TaskAssignmentModel> _inMemoryAssignments = [];
  final List<NotificationModel> _inMemoryNotifications = [];

  final StreamController<void> _inMemoryChangeNotifier = StreamController<void>.broadcast();

  void _notifyInMemoryChange() {
    if (!_inMemoryChangeNotifier.isClosed) {
      _inMemoryChangeNotifier.add(null);
    }
  }

  void clearAllData() {
    _inMemoryUsers.clear();
    _inMemoryWards.clear();
    _inMemoryTasks.clear();
    _inMemoryAssignments.clear();
    _inMemoryNotifications.clear();
    _notifyInMemoryChange();
  }

  // ==================== NOTIFICATIONS ====================

  /// Creates a per-user notification. Expired notifications are eligible for
  /// Firestore TTL deletion through the expiresAt field.
  Future<void> createNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    if (recipientId.trim().isEmpty) return;
    final now = DateTime.now();
    final notificationId =
        'notification_${now.microsecondsSinceEpoch}_$recipientId';
    final notification = NotificationModel(
      notificationId: notificationId,
      recipientId: recipientId,
      title: title,
      message: message,
      type: type,
      relatedId: relatedId,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 45)),
    );
    _inMemoryNotifications.add(notification);
    _notifyInMemoryChange();

    if (isFirebaseAvailable) {
      try {
        await _notificationsCollection
            .doc(notificationId)
            .set(notification.toJson());
      } catch (e) {
        debugPrint('Error creating notification: $e');
      }
    }
  }

  Future<void> _notifyUsers({
    required Iterable<String> recipientIds,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) async {
    for (final recipientId in recipientIds.toSet()) {
      await createNotification(
        recipientId: recipientId,
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
      );
    }
  }

  Future<List<String>> _userIdsForRole(UserRole role) async {
    if (isFirebaseAvailable) {
      try {
        final snapshot = await _usersCollection
            .where('role', isEqualTo: role.displayName)
            .get();
        return snapshot.docs.map((doc) => doc.id).toList();
      } catch (e) {
        debugPrint('Error finding notification recipients: $e');
      }
    }
    return [..._inMemoryUsers, ...AuthService().registeredUsers]
        .where((user) => user.role == role)
        .map((user) => user.userId)
        .toSet()
        .toList();
  }

  Future<String?> _supervisorIdForWard(String wardId) async {
    if (wardId.isEmpty) return null;
    if (isFirebaseAvailable) {
      try {
        final ward = await _wardsCollection.doc(wardId).get();
        return ward.data()?['supervisorId'] as String?;
      } catch (e) {
        debugPrint('Error finding ward supervisor for notification: $e');
      }
    }
    for (final ward in _inMemoryWards) {
      if (ward.wardId == wardId) return ward.supervisorId;
    }
    return null;
  }

  Future<void> _notifySuspension({
    required String workerId,
    required String wardId,
    required String reason,
    String? relatedId,
  }) async {
    final supervisorId = await _supervisorIdForWard(wardId);
    final admins = await _userIdsForRole(UserRole.admin);
    await _notifyUsers(
      recipientIds: [...admins, ?supervisorId, workerId],
      title: 'Worker suspended',
      message: 'A worker was suspended. Reason: $reason.',
      type: 'worker_suspended',
      relatedId: relatedId,
    );
  }

  Stream<List<NotificationModel>> streamNotifications(String recipientId) {
    if (isFirebaseAvailable) {
      return _notificationsCollection
          .where('recipientId', isEqualTo: recipientId)
          .snapshots()
          .map((snapshot) {
        final now = DateTime.now();
        final expired = <DocumentSnapshot<Map<String, dynamic>>>[];
        final notifications = <NotificationModel>[];
        for (final doc in snapshot.docs) {
          final notification = NotificationModel.fromMap(doc.data(), doc.id);
          if (notification.expiresAt.isAfter(now)) {
            notifications.add(notification);
          } else {
            expired.add(doc);
          }
        }
        if (expired.isNotEmpty) {
          Future.wait(expired.map((doc) => doc.reference.delete()));
        }
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      });
    }

    List<NotificationModel> currentNotifications() {
      final notifications = _inMemoryNotifications
          .where((notification) =>
              notification.recipientId == recipientId &&
              notification.expiresAt.isAfter(DateTime.now()))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }

    late StreamController<List<NotificationModel>> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<List<NotificationModel>>(
      onListen: () {
        controller.add(currentNotifications());
        subscription = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) controller.add(currentNotifications());
        });
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<void> markNotificationRead(String notificationId) async {
    final index = _inMemoryNotifications
        .indexWhere((notification) => notification.notificationId == notificationId);
    if (index != -1) {
      _inMemoryNotifications[index] =
          _inMemoryNotifications[index].copyWith(isRead: true);
      _notifyInMemoryChange();
    }
    if (isFirebaseAvailable) {
      try {
        await _notificationsCollection.doc(notificationId).update({'isRead': true});
      } catch (e) {
        debugPrint('Error marking notification as read: $e');
      }
    }
  }

  Future<void> markAllNotificationsRead(String recipientId) async {
    final unread = _inMemoryNotifications
        .where((notification) =>
            notification.recipientId == recipientId && !notification.isRead)
        .toList();
    for (final notification in unread) {
      final index = _inMemoryNotifications
          .indexWhere((item) => item.notificationId == notification.notificationId);
      if (index != -1) {
        _inMemoryNotifications[index] =
            _inMemoryNotifications[index].copyWith(isRead: true);
      }
    }
    if (unread.isNotEmpty) _notifyInMemoryChange();
    if (isFirebaseAvailable) {
      try {
        final snapshot = await _notificationsCollection
            .where('recipientId', isEqualTo: recipientId)
            .where('isRead', isEqualTo: false)
            .get();
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Error marking all notifications as read: $e');
      }
    }
  }

  void seedWard(WardModel ward) {
    if (_inMemoryWards.isEmpty) {
      _inMemoryWards.addAll(defaultHospitalWards);
    }
    _inMemoryWards.removeWhere((w) => w.wardId == ward.wardId);
    _inMemoryWards.add(ward);
    _notifyInMemoryChange();
  }

  void seedWorker(UserModel worker) {
    _inMemoryUsers.removeWhere((u) => u.userId == worker.userId);
    _inMemoryUsers.add(worker);
    _notifyInMemoryChange();
  }

  void seedTask(TaskModel task) {
    _inMemoryTasks.removeWhere((t) => t.taskId == task.taskId);
    _inMemoryTasks.add(task);
    _notifyInMemoryChange();
  }

  void seedAssignment(TaskAssignmentModel assignment) {
    _inMemoryAssignments.removeWhere((a) => a.assignmentId == assignment.assignmentId);
    _inMemoryAssignments.add(assignment);
    _notifyInMemoryChange();
  }

  // ==================== USER OPERATIONS ====================

  /// Saves or updates a user profile in Firestore
  Future<bool> saveUserProfile(UserModel user) async {
    _inMemoryUsers.removeWhere((u) => u.userId == user.userId);
    _inMemoryUsers.add(user);
    _notifyInMemoryChange();

    if (isFirebaseAvailable) {
      try {
        await _usersCollection.doc(user.userId).set(
              user.toJson(),
              SetOptions(merge: true),
            );
        if (user.status == UserStatus.pending) {
          await _notifyUsers(
            recipientIds: await _userIdsForRole(UserRole.admin),
            title: 'New registration',
            message: '${user.name} submitted a registration for review.',
            type: 'registration_submitted',
            relatedId: user.userId,
          );
        }
        return true;
      } catch (e) {
        debugPrint('Error saving user profile to Firestore: $e');
        return false;
      }
    }
    if (user.status == UserStatus.pending) {
      await _notifyUsers(
        recipientIds: await _userIdsForRole(UserRole.admin),
        title: 'New registration',
        message: '${user.name} submitted a registration for review.',
        type: 'registration_submitted',
        relatedId: user.userId,
      );
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

    UserModel? getProfile() {
      final memUser = _inMemoryUsers.where((u) => u.userId == uid);
      return memUser.isNotEmpty ? memUser.first : null;
    }

    late StreamController<UserModel?> controller;
    StreamSubscription? sub;
    controller = StreamController<UserModel?>(
      onListen: () {
        controller.add(getProfile());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getProfile());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
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
  /// Enforces:
  /// 1. One Ward - One Supervisor (PRD AC03 / W01): Rejects if ward is already assigned to a supervisor.
  /// 2. Worker assignment requirement: Rejects if ward does not have an assigned supervisor.
  Future<bool> assignUserToWard({
    required String userId,
    required String wardId,
    required UserRole role,
  }) async {
    final UserStatus newStatus = (role == UserRole.supervisor)
        ? UserStatus.assigned
        : UserStatus.available;

    final cleanWardName = formatWardDisplayName(wardId);

    // 1. Live Firestore persistence and validation (no in-memory interference)
    if (isFirebaseAvailable) {
      try {
        final wardDocRef = _wardsCollection.doc(wardId);
        final userDocRef = _usersCollection.doc(userId);

        if (role == UserRole.supervisor) {
          final wardSnapshot = await wardDocRef.get();
          String? currentSup;
          if (wardSnapshot.exists && wardSnapshot.data() != null) {
            currentSup = (wardSnapshot.data()!['supervisorId'] as String?)?.trim();
          }
          if (currentSup != null && currentSup.isNotEmpty && currentSup != userId) {
            debugPrint('[FirestoreService] Rejected: Ward $wardId already assigned to supervisor $currentSup');
            return false;
          }

          final batch = firestore.batch();
          batch.update(userDocRef, {
            'wardId': wardId,
            'wardName': cleanWardName,
            'status': newStatus.displayName,
            'wardRef': wardDocRef,
          });
          batch.set(
            wardDocRef,
            {
              'name': cleanWardName,
              'supervisorId': userId,
              'supervisorRef': userDocRef,
            },
            SetOptions(merge: true),
          );
          await batch.commit();

          final idx = _inMemoryUsers.indexWhere((u) => u.userId == userId);
          if (idx != -1) {
            _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
              wardId: wardId,
              wardName: cleanWardName,
              status: newStatus,
            );
          } else {
            final regUsers = AuthService().registeredUsers.where((u) => u.userId == userId);
            if (regUsers.isNotEmpty) {
              _inMemoryUsers.add(regUsers.first.copyWith(
                wardId: wardId,
                wardName: cleanWardName,
                status: newStatus,
              ));
            }
          }
          final regIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == userId);
          if (regIdx != -1) {
            AuthService().updateUser(AuthService().registeredUsers[regIdx].copyWith(
              wardId: wardId,
              wardName: cleanWardName,
              status: newStatus,
            ));
          }
          final inMemWIdx = _inMemoryWards.indexWhere((w) => w.wardId == wardId || w.name == cleanWardName);
          if (inMemWIdx != -1) {
            _inMemoryWards[inMemWIdx] = _inMemoryWards[inMemWIdx].copyWith(
              name: cleanWardName,
              supervisorId: userId,
            );
          } else {
            _inMemoryWards.add(WardModel(wardId: wardId, name: cleanWardName, supervisorId: userId));
          }
          _notifyInMemoryChange();
          await createNotification(
            recipientId: userId,
            title: 'Registration approved',
            message: 'Your CleanTrack registration has been approved.',
            type: 'registration_approved',
            relatedId: userId,
          );
          return true;
        } else if (role == UserRole.worker) {
          final wardSnapshot = await wardDocRef.get();
          String? currentSup;
          if (wardSnapshot.exists && wardSnapshot.data() != null) {
            currentSup = (wardSnapshot.data()!['supervisorId'] as String?)?.trim();
            if (currentSup == null || currentSup.isEmpty) {
              if (wardSnapshot.data()!['supervisorRef'] != null) {
                currentSup = 'assigned_ref';
              }
            }
          }

          // Fallback: Check if any supervisor in Firestore is assigned to this ward
          if (currentSup == null || currentSup.isEmpty) {
            final supQuery = await _usersCollection
                .where('role', isEqualTo: 'Supervisor')
                .where('wardId', isEqualTo: wardId)
                .get();
            if (supQuery.docs.isNotEmpty) {
              currentSup = supQuery.docs.first.id;
            } else {
              final supQuery2 = await _usersCollection
                  .where('role', isEqualTo: 'Supervisor')
                  .where('wardName', isEqualTo: cleanWardName)
                  .get();
              if (supQuery2.docs.isNotEmpty) {
                currentSup = supQuery2.docs.first.id;
              }
            }
          }

          if (currentSup == null || currentSup.isEmpty) {
            debugPrint('[FirestoreService] Rejected: Ward $wardId has no supervisor.');
            return false;
          }

          await userDocRef.update({
            'wardId': wardId,
            'wardName': cleanWardName,
            'status': newStatus.displayName,
            'wardRef': wardDocRef,
          });

          final idx = _inMemoryUsers.indexWhere((u) => u.userId == userId);
          if (idx != -1) {
            _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
              wardId: wardId,
              wardName: cleanWardName,
              status: newStatus,
            );
          } else {
            final regUsers = AuthService().registeredUsers.where((u) => u.userId == userId);
            if (regUsers.isNotEmpty) {
              _inMemoryUsers.add(regUsers.first.copyWith(
                wardId: wardId,
                wardName: cleanWardName,
                status: newStatus,
              ));
            } else {
              _inMemoryUsers.add(UserModel(
                userId: userId,
                name: 'Worker $userId',
                employeeId: 'WRK-${userId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(3, '0')}',
                email: '$userId@hospital.org',
                role: role,
                wardId: wardId,
                wardName: cleanWardName,
                status: newStatus,
              ));
            }
          }
          final regIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == userId);
          if (regIdx != -1) {
            AuthService().updateUser(AuthService().registeredUsers[regIdx].copyWith(
              wardId: wardId,
              wardName: cleanWardName,
              status: newStatus,
            ));
          }
          _notifyInMemoryChange();
          await createNotification(
            recipientId: userId,
            title: 'Registration approved',
            message: 'Your CleanTrack registration has been approved.',
            type: 'registration_approved',
            relatedId: userId,
          );
          return true;
        }
      } catch (e) {
        debugPrint('Error assigning user to ward in Firestore: $e');
        return false;
      }
    }

    // 2. In-memory validation & updates (strictly isolated fallback for offline widget tests)
    final inMemWardIdx = _inMemoryWards.indexWhere((w) => w.wardId == wardId || w.name == cleanWardName);
    final inMemWard = inMemWardIdx != -1
        ? _inMemoryWards[inMemWardIdx]
        : defaultHospitalWards.firstWhere(
            (w) => w.wardId == wardId || w.name == cleanWardName,
            orElse: () => WardModel(wardId: wardId, name: cleanWardName),
          );

    String? inMemSupervisorId = inMemWard.supervisorId;
    if (inMemSupervisorId == null || inMemSupervisorId.trim().isEmpty) {
      if (inMemWard.supervisorRef != null) {
        inMemSupervisorId = 'assigned_ref';
      } else {
        final allUsers = [..._inMemoryUsers, ...AuthService().registeredUsers];
        final matchedSup = allUsers.firstWhere(
          (u) =>
              u.role == UserRole.supervisor &&
              (u.wardId == wardId ||
                  u.wardName == cleanWardName ||
                  u.wardId == cleanWardName ||
                  (u.wardId != null && formatWardDisplayName(u.wardId!) == cleanWardName)),
          orElse: () => UserModel(userId: '', name: '', employeeId: '', email: '', role: UserRole.worker),
        );
        if (matchedSup.userId.isNotEmpty) {
          inMemSupervisorId = matchedSup.userId;
        }
      }
    }

    if (role == UserRole.supervisor) {
      if (inMemSupervisorId != null &&
          inMemSupervisorId.trim().isNotEmpty &&
          inMemSupervisorId != userId) {
        debugPrint('[FirestoreService] Rejected: Ward $cleanWardName already assigned to supervisor $inMemSupervisorId');
        return false;
      }
    }

    if (role == UserRole.worker) {
      if (inMemSupervisorId == null || inMemSupervisorId.trim().isEmpty) {
        debugPrint('[FirestoreService] Rejected: Cannot assign worker because ward $cleanWardName does not have an assigned supervisor.');
        return false;
      }
    }

    final idx = _inMemoryUsers.indexWhere((u) => u.userId == userId);
    if (idx != -1) {
      _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
        wardId: wardId,
        wardName: cleanWardName,
        status: newStatus,
      );
    } else {
      final regUsers = AuthService().registeredUsers.where((u) => u.userId == userId);
      if (regUsers.isNotEmpty) {
        _inMemoryUsers.add(regUsers.first.copyWith(
          wardId: wardId,
          wardName: cleanWardName,
          status: newStatus,
        ));
      } else {
        _inMemoryUsers.add(UserModel(
          userId: userId,
          name: 'Worker $userId',
          employeeId: 'WRK-${userId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(3, '0')}',
          email: '$userId@hospital.org',
          role: role,
          wardId: wardId,
          wardName: cleanWardName,
          status: newStatus,
        ));
      }
    }

    final regIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == userId);
    if (regIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[regIdx].copyWith(
        wardId: wardId,
        wardName: cleanWardName,
        status: newStatus,
      ));
    }

    if (role == UserRole.supervisor) {
      if (inMemWardIdx != -1) {
        _inMemoryWards[inMemWardIdx] = _inMemoryWards[inMemWardIdx].copyWith(
          name: cleanWardName,
          supervisorId: userId,
        );
      } else {
        _inMemoryWards.add(inMemWard.copyWith(supervisorId: userId));
      }
    }

    _notifyInMemoryChange();
    await createNotification(
      recipientId: userId,
      title: 'Registration approved',
      message: 'Your CleanTrack registration has been approved.',
      type: 'registration_approved',
      relatedId: userId,
    );
    return true;
  }

  /// Streams pending users awaiting ward assignment / activation directly from Firestore
  Stream<List<UserModel>> streamPendingUsers({UserRole? role}) {
    if (isFirebaseAvailable) {
      return _usersCollection.snapshots().map((snapshot) {
        final list = <UserModel>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final user = UserModel.fromMap(data, doc.id);
          if (user.status == UserStatus.pending) {
            if (role == null || user.role == role) {
              list.add(user);
            }
          }
        }
        return list;
      });
    }

    // Isolated fallback for offline widget tests
    final list = _inMemoryUsers
        .where((u) => u.status == UserStatus.pending && (role == null || u.role == role))
        .toList();
    return Stream.value(list);
  }

  /// Seeds demo pending personnel when needed (disabled: registrations originate from Register screen)
  void seedDemoPendingUsers() {
    // No-op: hardcoded demo pending users removed per user requirement.
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
      _notifyInMemoryChange();
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

  /// Gets all supervisors, regardless of activation status.
  Future<List<UserModel>> getSupervisors() async {
    if (isFirebaseAvailable) {
      try {
        final snapshot = await _usersCollection.get();
        return snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .where((user) => user.role == UserRole.supervisor)
            .toList();
      } catch (e) {
        debugPrint('Error querying supervisors from Firestore: $e');
        return [];
      }
    }

    final users = <String, UserModel>{};
    for (final user in [...AuthService().registeredUsers, ..._inMemoryUsers]) {
      if (user.role == UserRole.supervisor) {
        users[user.userId] = user;
      }
    }
    return users.values.toList();
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
        return null;
      } catch (e) {
        debugPrint('Error fetching ward from Firestore: $e');
        return null;
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
        return null;
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
  static List<WardModel> get defaultHospitalWards => [
    WardModel(wardId: 'ward_icu_1', name: 'ICU 1'),
    WardModel(wardId: 'ward_icu_2', name: 'ICU 2'),
    WardModel(wardId: 'ward_icu_3', name: 'ICU 3'),
    WardModel(wardId: 'ward_minor_ot', name: 'Minor OT'),
    WardModel(wardId: 'ward_ot_1', name: 'OT 1'),
    WardModel(wardId: 'ward_ot_2', name: 'OT 2'),
  ];

  /// Seeds default hospital wards into Cloud Firestore if the wards collection is empty
  Future<bool> seedInitialWardsToFirestore({bool overwrite = false}) async {
    if (overwrite) {
      for (final ward in defaultHospitalWards) {
        final existingIdx = _inMemoryWards.indexWhere((w) => w.wardId == ward.wardId || w.name == ward.name);
        if (existingIdx != -1 &&
            _inMemoryWards[existingIdx].supervisorId != null &&
            _inMemoryWards[existingIdx].supervisorId!.trim().isNotEmpty) {
          continue; // preserve existing supervisor in memory
        }
        seedWard(ward);
      }
    }

    if (!isFirebaseAvailable) {
      return true;
    }

    try {
      final batch = firestore.batch();
      for (final ward in defaultHospitalWards) {
        batch.set(_wardsCollection.doc(ward.wardId), ward.toJson(), SetOptions(merge: true));
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error seeding wards to Firestore: $e');
      return false;
    }
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

  /// Gets all wards from Firestore or memory
  Future<List<WardModel>> getWards() async {
    if (isFirebaseAvailable) {
      try {
        final query = await _wardsCollection.get();
        List<WardModel> wardsList = [];
        if (query.docs.isNotEmpty) {
          wardsList = query.docs.map((doc) => WardModel.fromMap(doc.data(), doc.id)).toList();
        } else {
          // Check uppercase 'Wards' as fallback
          final altQuery = await firestore.collection('Wards').get();
          if (altQuery.docs.isNotEmpty) {
            wardsList = altQuery.docs.map((doc) => WardModel.fromMap(doc.data(), doc.id)).toList();
          }
        }

        if (wardsList.isNotEmpty) {
          final supQuery = await _usersCollection.where('role', isEqualTo: 'Supervisor').get();
          final supervisorByWard = <String, String>{};
          for (final doc in supQuery.docs) {
            final data = doc.data();
            final supId = doc.id;
            final wId = (data['wardId'] as String?)?.trim() ?? '';
            final wName = (data['wardName'] as String?)?.trim() ?? '';
            if (wId.isNotEmpty) supervisorByWard[wId.toLowerCase()] = supId;
            if (wName.isNotEmpty) supervisorByWard[wName.toLowerCase()] = supId;
            if (wId.isNotEmpty) supervisorByWard[formatWardDisplayName(wId).toLowerCase()] = supId;
            if (wName.isNotEmpty) supervisorByWard[formatWardDisplayName(wName).toLowerCase()] = supId;
          }

          return wardsList.map((w) {
            if (w.supervisorId != null && w.supervisorId!.trim().isNotEmpty) {
              return w;
            }
            final matchedSup = supervisorByWard[w.wardId.toLowerCase()] ??
                supervisorByWard[w.name.toLowerCase()] ??
                supervisorByWard[formatWardDisplayName(w.wardId).toLowerCase()];
            if (matchedSup != null) {
              return w.copyWith(supervisorId: matchedSup);
            }
            return w;
          }).toList();
        }
        return [];
      } catch (e) {
        debugPrint('Error getting wards from Firestore: $e');
        return [];
      }
    }

    final supervisorByWard = <String, String>{};
    for (final u in [..._inMemoryUsers, ...AuthService().registeredUsers]) {
      if (u.role == UserRole.supervisor) {
        final wId = u.wardId?.trim() ?? '';
        final wName = u.wardName?.trim() ?? '';
        if (wId.isNotEmpty) supervisorByWard[wId.toLowerCase()] = u.userId;
        if (wName.isNotEmpty) supervisorByWard[wName.toLowerCase()] = u.userId;
        if (wId.isNotEmpty) supervisorByWard[formatWardDisplayName(wId).toLowerCase()] = u.userId;
        if (wName.isNotEmpty) supervisorByWard[formatWardDisplayName(wName).toLowerCase()] = u.userId;
      }
    }
    final baseWards = _inMemoryWards.isNotEmpty ? _inMemoryWards : defaultHospitalWards;
    return baseWards.map((w) {
      if (w.supervisorId != null && w.supervisorId!.trim().isNotEmpty) {
        return w;
      }
      final matchedSup = supervisorByWard[w.wardId.toLowerCase()] ??
          supervisorByWard[w.name.toLowerCase()] ??
          supervisorByWard[formatWardDisplayName(w.wardId).toLowerCase()];
      if (matchedSup != null) {
        return w.copyWith(supervisorId: matchedSup);
      }
      return w;
    }).toList();
  }

  /// Streams all wards in real time
  Stream<List<WardModel>> streamWards() {
    if (isFirebaseAvailable) {
      return _wardsCollection.snapshots().asyncMap((snap) async {
        final wardsList = snap.docs.isNotEmpty
            ? snap.docs.map((d) => WardModel.fromMap(d.data(), d.id)).toList()
            : <WardModel>[];

        try {
          final supQuery = await _usersCollection.where('role', isEqualTo: 'Supervisor').get();
          final supervisorByWard = <String, String>{};
          for (final doc in supQuery.docs) {
            final data = doc.data();
            final supId = doc.id;
            final wId = (data['wardId'] as String?)?.trim() ?? '';
            final wName = (data['wardName'] as String?)?.trim() ?? '';
            if (wId.isNotEmpty) supervisorByWard[wId.toLowerCase()] = supId;
            if (wName.isNotEmpty) supervisorByWard[wName.toLowerCase()] = supId;
            if (wId.isNotEmpty) supervisorByWard[formatWardDisplayName(wId).toLowerCase()] = supId;
            if (wName.isNotEmpty) supervisorByWard[formatWardDisplayName(wName).toLowerCase()] = supId;
          }

          return wardsList.map((w) {
            if (w.supervisorId != null && w.supervisorId!.trim().isNotEmpty) {
              return w;
            }
            final matchedSup = supervisorByWard[w.wardId.toLowerCase()] ??
                supervisorByWard[w.name.toLowerCase()] ??
                supervisorByWard[formatWardDisplayName(w.wardId).toLowerCase()];
            if (matchedSup != null) {
              return w.copyWith(supervisorId: matchedSup);
            }
            return w;
          }).toList();
        } catch (_) {
          return wardsList;
        }
      });
    }

    final supervisorByWard = <String, String>{};
    for (final u in [..._inMemoryUsers, ...AuthService().registeredUsers]) {
      if (u.role == UserRole.supervisor) {
        final wId = u.wardId?.trim() ?? '';
        final wName = u.wardName?.trim() ?? '';
        if (wId.isNotEmpty) supervisorByWard[wId.toLowerCase()] = u.userId;
        if (wName.isNotEmpty) supervisorByWard[wName.toLowerCase()] = u.userId;
        if (wId.isNotEmpty) supervisorByWard[formatWardDisplayName(wId).toLowerCase()] = u.userId;
        if (wName.isNotEmpty) supervisorByWard[formatWardDisplayName(wName).toLowerCase()] = u.userId;
      }
    }
    final baseWards = _inMemoryWards.isNotEmpty ? _inMemoryWards : defaultHospitalWards;
    return Stream.value(baseWards.map((w) {
      if (w.supervisorId != null && w.supervisorId!.trim().isNotEmpty) {
        return w;
      }
      final matchedSup = supervisorByWard[w.wardId.toLowerCase()] ??
          supervisorByWard[w.name.toLowerCase()] ??
          supervisorByWard[formatWardDisplayName(w.wardId).toLowerCase()];
      if (matchedSup != null) {
        return w.copyWith(supervisorId: matchedSup);
      }
      return w;
    }).toList());
  }

  /// Gets worker counts grouped by ward ID and formatted ward name directly from Firestore
  Future<Map<String, int>> getWorkerCountsByWard() async {
    final counts = <String, int>{};
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('role', isEqualTo: 'Worker')
            .get();
        for (final doc in query.docs) {
          final data = doc.data();
          final wId = (data['wardId'] as String?)?.trim() ?? '';
          final wName = (data['wardName'] as String?)?.trim() ?? '';
          if (wId.isNotEmpty) {
            counts[wId] = (counts[wId] ?? 0) + 1;
          }
          if (wName.isNotEmpty) {
            counts[wName] = (counts[wName] ?? 0) + 1;
          }
        }
        return counts;
      } catch (e) {
        debugPrint('Error getting worker counts by ward: $e');
        return counts;
      }
    }

    // Isolated fallback for offline widget tests
    for (final u in _inMemoryUsers) {
      if (u.role == UserRole.worker) {
        if (u.wardId != null && u.wardId!.trim().isNotEmpty) {
          counts[u.wardId!] = (counts[u.wardId!] ?? 0) + 1;
        }
        if (u.wardName != null && u.wardName!.trim().isNotEmpty) {
          counts[u.wardName!] = (counts[u.wardName!] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Gets supervisor names mapped by supervisor userId and wardId directly from Firestore
  Future<Map<String, String>> getSupervisorNames() async {
    final names = <String, String>{};
    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection
            .where('role', isEqualTo: 'Supervisor')
            .get();
        for (final doc in query.docs) {
          final data = doc.data();
          final name = (data['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) {
            names[doc.id] = name;
            final wId = (data['wardId'] as String?)?.trim() ?? '';
            final wName = (data['wardName'] as String?)?.trim() ?? '';
            if (wId.isNotEmpty) {
              names[wId] = name;
            }
            if (wName.isNotEmpty) {
              names[wName] = name;
            }
          }
        }
        return names;
      } catch (e) {
        debugPrint('Error getting supervisor names: $e');
        return names;
      }
    }

    // Isolated fallback for offline widget tests
    for (final u in _inMemoryUsers) {
      if (u.role == UserRole.supervisor && u.name.trim().isNotEmpty) {
        names[u.userId] = u.name.trim();
        if (u.wardId != null && u.wardId!.trim().isNotEmpty) {
          names[u.wardId!] = u.name.trim();
        }
        if (u.wardName != null && u.wardName!.trim().isNotEmpty) {
          names[u.wardName!] = u.name.trim();
        }
      }
    }
    return names;
  }

  // ==================== WORKER OPERATIONS FOR SUPERVISOR ====================

  /// Gets all workers assigned to a specific ward from Firestore
  Future<List<UserModel>> getWorkersByWard(String wardId) async {
    bool matchesWard(String? itemWardId, String? itemWardName, String targetWardId) {
      if (targetWardId.isEmpty) return true;
      final cleanTarget = formatWardDisplayName(targetWardId).toLowerCase();
      if (itemWardId != null && itemWardId.trim().isNotEmpty) {
        if (itemWardId.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardId).toLowerCase() == cleanTarget) return true;
      }
      if (itemWardName != null && itemWardName.trim().isNotEmpty) {
        if (itemWardName.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardName).toLowerCase() == cleanTarget) return true;
      }
      return false;
    }

    if (isFirebaseAvailable) {
      try {
        final query = await _usersCollection.where('role', isEqualTo: 'Worker').get();
        final docs = query.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
        final allMem = [...AuthService().registeredUsers, ..._inMemoryUsers];
        final unique = <String, UserModel>{};
        for (final u in docs) {
          if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
            unique[u.userId] = u;
          }
        }
        for (final u in allMem) {
          if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
            unique[u.userId] = u;
          }
        }
        return sortWorkersByStatus(unique.values);
      } catch (e) {
        debugPrint('Error fetching workers by ward from Firestore: $e');
        return [];
      }
    }
    final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
    final unique = <String, UserModel>{};
    for (final u in all) {
      if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
        unique[u.userId] = u;
      }
    }
    return sortWorkersByStatus(unique.values);
  }

  /// Streams workers assigned to a specific ward from Firestore sorted by status:
  /// Available workers appear on top, then busy workers, and then suspended workers.
  Stream<List<UserModel>> streamWorkersByWard(String wardId) {
    bool matchesWard(String? itemWardId, String? itemWardName, String targetWardId) {
      if (targetWardId.isEmpty) return true;
      final cleanTarget = formatWardDisplayName(targetWardId).toLowerCase();
      if (itemWardId != null && itemWardId.trim().isNotEmpty) {
        if (itemWardId.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardId).toLowerCase() == cleanTarget) return true;
      }
      if (itemWardName != null && itemWardName.trim().isNotEmpty) {
        if (itemWardName.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardName).toLowerCase() == cleanTarget) return true;
      }
      return false;
    }

    if (isFirebaseAvailable) {
      return _usersCollection
          .where('role', isEqualTo: 'Worker')
          .snapshots()
          .map((snapshot) {
        final allDocs = snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
        final allMem = [...AuthService().registeredUsers, ..._inMemoryUsers];
        final unique = <String, UserModel>{};
        for (final u in allDocs) {
          if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
            unique[u.userId] = u;
          }
        }
        for (final u in allMem) {
          if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
            unique[u.userId] = u;
          }
        }
        return sortWorkersByStatus(unique.values);
      });
    }

    List<UserModel> getFiltered() {
      final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
      final unique = <String, UserModel>{};
      for (final u in all) {
        if (u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId)) {
          unique[u.userId] = u;
        }
      }
      return sortWorkersByStatus(unique.values);
    }

    late StreamController<List<UserModel>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<UserModel>>(
      onListen: () {
        controller.add(getFiltered());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getFiltered());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
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

    List<TaskModel> getFiltered() {
      return _inMemoryTasks.where((t) => wardId.isEmpty || t.wardId == wardId).toList();
    }

    late StreamController<List<TaskModel>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<TaskModel>>(
      onListen: () {
        controller.add(getFiltered());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getFiltered());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
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

    List<TaskAssignmentModel> getFiltered() {
      return _inMemoryAssignments.where((a) => wardId.isEmpty || a.wardId == wardId).toList();
    }

    late StreamController<List<TaskAssignmentModel>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<TaskAssignmentModel>>(
      onListen: () {
        controller.add(getFiltered());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getFiltered());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Streams live Supervisor Dashboard statistics from Firestore
  Stream<SupervisorDashboardStats> streamSupervisorStats(String wardId) {
    bool matchesWard(String? itemWardId, String? itemWardName, String targetWardId) {
      if (targetWardId.isEmpty) return true;
      final cleanTarget = formatWardDisplayName(targetWardId).toLowerCase();
      if (itemWardId != null && itemWardId.trim().isNotEmpty) {
        if (itemWardId.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardId).toLowerCase() == cleanTarget) return true;
      }
      if (itemWardName != null && itemWardName.trim().isNotEmpty) {
        if (itemWardName.trim().toLowerCase() == targetWardId.trim().toLowerCase()) return true;
        if (formatWardDisplayName(itemWardName).toLowerCase() == cleanTarget) return true;
      }
      return false;
    }

    SupervisorDashboardStats getCalculatedStats(
      List<UserModel> workers,
      List<TaskAssignmentModel> assignments,
      String wardName,
    ) {
      final filteredWorkers = workers
          .where((u) => u.role == UserRole.worker && matchesWard(u.wardId, u.wardName, wardId))
          .toList();

      final filteredAssignments = assignments
          .where((a) =>
              matchesWard(a.wardId, null, wardId) ||
              filteredWorkers.any((w) => w.userId == a.workerId))
          .toList();

      int pendingVerify = 0;
      int overdue = 0;
      final now = DateTime.now();

      final pendingWorkerIds = <String>{};
      final activeWorkerIds = <String>{};
      for (final a in filteredAssignments) {
        if (a.status == AssignmentStatus.pendingVerification) {
          pendingVerify++;
          pendingWorkerIds.add(a.workerId);
        } else if (a.status == AssignmentStatus.pending) {
          activeWorkerIds.add(a.workerId);
        }
        if (a.status != AssignmentStatus.verified && a.status != AssignmentStatus.autoVerified) {
          if (a.deadline.isBefore(now)) {
            overdue++;
          }
        }
      }

      int available = 0;
      int busy = 0;
      for (final w in filteredWorkers) {
        if (w.status == UserStatus.suspended) {
          continue;
        }
        if (w.status == UserStatus.busy || activeWorkerIds.contains(w.userId)) {
          if (!pendingWorkerIds.contains(w.userId)) {
            busy++;
          }
        } else if (w.status == UserStatus.available) {
          available++;
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

    late StreamController<SupervisorDashboardStats> controller;
    StreamSubscription? workersSub;
    StreamSubscription? assignmentsSub;
    StreamSubscription? memorySub;

    List<UserModel> latestWorkers = [];
    List<TaskAssignmentModel> latestAssignments = [];
    String wardName = wardId.isNotEmpty ? formatWardDisplayName(wardId) : 'ICU Ward';

    void updateStats() {
      if (!controller.isClosed) {
        controller.add(getCalculatedStats(latestWorkers, latestAssignments, wardName));
      }
    }

    void loadInMemory() {
      final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
      final unique = <String, UserModel>{};
      for (final u in all) {
        if (u.role == UserRole.worker) {
          unique[u.userId] = u;
        }
      }
      latestWorkers = unique.values.toList();
      latestAssignments = List.of(_inMemoryAssignments);
      final ward = _inMemoryWards.where((w) =>
          w.wardId == wardId || formatWardDisplayName(w.name) == formatWardDisplayName(wardId));
      wardName = ward.isNotEmpty ? ward.first.name : (wardId.isNotEmpty ? formatWardDisplayName(wardId) : 'ICU Ward');
      updateStats();
    }

    if (!isFirebaseAvailable) {
      controller = StreamController<SupervisorDashboardStats>(
        onListen: () {
          loadInMemory();
          memorySub = _inMemoryChangeNotifier.stream.listen((_) {
            loadInMemory();
          });
        },
        onCancel: () {
          memorySub?.cancel();
        },
      );
      return controller.stream;
    }

    final workersStream = _usersCollection.snapshots();
    final assignmentsStream = _taskAssignmentsCollection.snapshots();

    controller = StreamController<SupervisorDashboardStats>(
      onListen: () {
        loadInMemory();

        if (wardId.isNotEmpty) {
          _wardsCollection.doc(wardId).get().then((wDoc) {
            if (wDoc.exists && wDoc.data() != null) {
              wardName = wDoc.data()!['name'] ?? wardName;
              updateStats();
            }
          }).catchError((_) {});
        }

        workersSub = workersStream.listen((snap) {
          final allDocs = snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
          final uniqueMap = <String, UserModel>{};
          for (final w in latestWorkers) {
            uniqueMap[w.userId] = w;
          }
          for (final u in allDocs) {
            if (u.role == UserRole.worker) {
              uniqueMap[u.userId] = u;
            }
          }
          for (final u in [...AuthService().registeredUsers, ..._inMemoryUsers]) {
            if (u.role == UserRole.worker) {
              uniqueMap[u.userId] = u;
            }
          }
          latestWorkers = uniqueMap.values.toList();
          updateStats();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

        assignmentsSub = assignmentsStream.listen((snap) {
          final allDocs = snap.docs.map((d) => TaskAssignmentModel.fromMap(d.data(), d.id)).toList();
          final uniqueAssign = <String, TaskAssignmentModel>{};
          for (final a in latestAssignments) {
            uniqueAssign[a.assignmentId] = a;
          }
          for (final a in allDocs) {
            uniqueAssign[a.assignmentId] = a;
          }
          for (final a in _inMemoryAssignments) {
            uniqueAssign[a.assignmentId] = a;
          }
          latestAssignments = uniqueAssign.values.toList();
          updateStats();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

        memorySub = _inMemoryChangeNotifier.stream.listen((_) {
          final allMem = [...AuthService().registeredUsers, ..._inMemoryUsers];
          final uniqueMap = <String, UserModel>{};
          for (final w in latestWorkers) {
            uniqueMap[w.userId] = w;
          }
          for (final u in allMem) {
            if (u.role == UserRole.worker) {
              uniqueMap[u.userId] = u;
            }
          }
          latestWorkers = uniqueMap.values.toList();

          final uniqueAssign = <String, TaskAssignmentModel>{};
          for (final a in latestAssignments) {
            uniqueAssign[a.assignmentId] = a;
          }
          for (final a in _inMemoryAssignments) {
            uniqueAssign[a.assignmentId] = a;
          }
          latestAssignments = uniqueAssign.values.toList();
          updateStats();
        });
      },
      onCancel: () {
        workersSub?.cancel();
        assignmentsSub?.cancel();
        memorySub?.cancel();
      },
    );

    return controller.stream;
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
      attempts: 0,
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
    final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == workerId);
    if (authIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
        status: UserStatus.busy,
        activeAssignmentId: assignmentId,
      ));
    }
    _notifyInMemoryChange();

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

    await createNotification(
      recipientId: workerId,
      title: 'New task assigned',
      message: 'You have been assigned "${task.title}".',
      type: 'task_assigned',
      relatedId: assignmentId,
    );
    return assignment;
  }

  /// Verifies a completed task assignment in Firestore (PRD 6.5 & S03 & AC09)
  /// Marks assignment as Verified, sets parent task status to Closed, and frees worker to Available.
  Future<bool> verifyTaskAssignment({
    required String assignmentId,
    required String taskId,
    required String workerId,
  }) async {
    final now = DateTime.now();
    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    final effectiveTaskId = taskId.isNotEmpty
        ? taskId
        : (aIdx != -1 ? _inMemoryAssignments[aIdx].taskId : '');
    final effectiveWorkerId = workerId.isNotEmpty
        ? workerId
        : (aIdx != -1 ? _inMemoryAssignments[aIdx].workerId : '');

    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.verified,
        verifiedAt: now,
      );
    }

    final tIdx = _inMemoryTasks.indexWhere((t) => t.taskId == effectiveTaskId);
    if (tIdx != -1) {
      _inMemoryTasks[tIdx] = _inMemoryTasks[tIdx].copyWith(
        status: TaskStatus.closed,
      );
    }

    final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == effectiveWorkerId);
    if (uIdx != -1) {
      _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
        status: UserStatus.available,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      );
    }
    final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == effectiveWorkerId);
    if (authIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
        status: UserStatus.available,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      ));
    }
    _notifyInMemoryChange();

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.verified.displayName,
          'verifiedAt': now.toIso8601String(),
        });
        if (effectiveTaskId.isNotEmpty) {
          await _tasksCollection.doc(effectiveTaskId).update({
            'status': TaskStatus.closed.displayName,
          });
        }
        if (effectiveWorkerId.isNotEmpty) {
          await _usersCollection.doc(effectiveWorkerId).update({
            'status': UserStatus.available.displayName,
            'activeAssignmentId': null,
          });
        }
        if (effectiveWorkerId.isNotEmpty) {
          await createNotification(
            recipientId: effectiveWorkerId,
            title: 'Task verified',
            message: 'Your completed task has been verified successfully.',
            type: 'task_verified',
            relatedId: effectiveTaskId,
          );
        }
        return true;
      } catch (e) {
        debugPrint('Error verifying task assignment in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Automatically marks an unverified assignment as Auto Verified after 1 hour (PRD 6.5 & V03 & AC10)
  /// Marks assignment as Auto Verified, sets parent task status to Closed, and frees worker to Available.
  Future<bool> autoVerifyTaskAssignment({
    required String assignmentId,
    required String taskId,
    required String workerId,
  }) async {
    final now = DateTime.now();

    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    final effectiveTaskId = taskId.isNotEmpty
        ? taskId
        : (aIdx != -1 ? _inMemoryAssignments[aIdx].taskId : '');
    final effectiveWorkerId = workerId.isNotEmpty
        ? workerId
        : (aIdx != -1 ? _inMemoryAssignments[aIdx].workerId : '');

    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.autoVerified,
        verifiedAt: now,
      );
    }

    final tIdx = _inMemoryTasks.indexWhere((t) => t.taskId == effectiveTaskId);
    if (tIdx != -1) {
      _inMemoryTasks[tIdx] = _inMemoryTasks[tIdx].copyWith(
        status: TaskStatus.closed,
      );
    }

    final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == effectiveWorkerId);
    if (uIdx != -1) {
      _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
        status: UserStatus.available,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      );
    }
    final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == effectiveWorkerId);
    if (authIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
        status: UserStatus.available,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      ));
    }
    _notifyInMemoryChange();

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.autoVerified.displayName,
          'verifiedAt': now.toIso8601String(),
        });
        if (effectiveTaskId.isNotEmpty) {
          await _tasksCollection.doc(effectiveTaskId).update({
            'status': TaskStatus.closed.displayName,
          });
        }
        if (effectiveWorkerId.isNotEmpty) {
          await _usersCollection.doc(effectiveWorkerId).update({
            'status': UserStatus.available.displayName,
            'activeAssignmentId': null,
          });
        }
        return true;
      } catch (e) {
        debugPrint('Error auto-verifying task assignment in Firestore: $e');
        return false;
      }
    }
    return true;
  }


  /// Read-only view of in-memory tasks for test inspection
  List<TaskModel> get inMemoryTasks => List.unmodifiable(_inMemoryTasks);

  /// Read-only view of in-memory task assignments for test inspection
  List<TaskAssignmentModel> get inMemoryAssignments => List.unmodifiable(_inMemoryAssignments);

  /// Retrieves an assignment by ID
  Future<TaskAssignmentModel?> getAssignment(String assignmentId) async {
    final match = _inMemoryAssignments.where((a) => a.assignmentId == assignmentId);
    if (match.isNotEmpty) return match.first;
    if (isFirebaseAvailable) {
      try {
        final doc = await _taskAssignmentsCollection.doc(assignmentId).get();
        if (doc.exists && doc.data() != null) {
          return TaskAssignmentModel.fromMap(doc.data()!, doc.id);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Read-only view of in-memory users for test inspection
  List<UserModel> get inMemoryUsers => List.unmodifiable(_inMemoryUsers);

  /// Streams assignments pending verification for a specific ward
  Stream<List<TaskAssignmentModel>> streamPendingVerificationAssignments(String wardId) {
    if (isFirebaseAvailable) {
      if (wardId.isEmpty) {
        return _taskAssignmentsCollection
            .where('status', isEqualTo: AssignmentStatus.pendingVerification.displayName)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id)).toList();
        });
      }
      return _taskAssignmentsCollection
          .where('wardId', isEqualTo: wardId)
          .where('status', isEqualTo: AssignmentStatus.pendingVerification.displayName)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id)).toList();
      });
    }

    List<TaskAssignmentModel> getFiltered() {
      return _inMemoryAssignments
          .where((a) =>
              (wardId.isEmpty || a.wardId == wardId) &&
              a.status == AssignmentStatus.pendingVerification)
          .toList();
    }

    late StreamController<List<TaskAssignmentModel>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<TaskAssignmentModel>>(
      onListen: () {
        controller.add(getFiltered());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getFiltered());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Gets assignments pending verification for a specific ward
  Future<List<TaskAssignmentModel>> getPendingVerificationAssignments(String wardId) async {
    if (isFirebaseAvailable) {
      try {
        final query = wardId.isNotEmpty
            ? await _taskAssignmentsCollection
                .where('wardId', isEqualTo: wardId)
                .where('status', isEqualTo: AssignmentStatus.pendingVerification.displayName)
                .get()
            : await _taskAssignmentsCollection
                .where('status', isEqualTo: AssignmentStatus.pendingVerification.displayName)
                .get();
        return query.docs.map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id)).toList();
      } catch (e) {
        debugPrint('Error getting pending verification assignments: $e');
        return [];
      }
    }

    return _inMemoryAssignments
        .where((a) =>
            (wardId.isEmpty || a.wardId == wardId) &&
            a.status == AssignmentStatus.pendingVerification)
        .toList();
  }

  /// Rejects an assignment submitted for verification (PRD 6.6 & 6.7 & SU02 & AC14)
  /// - 1st or 2nd rejection: increments attempts, resets status to Pending (sent back to worker)
  /// - 3rd rejection: marks assignment Not Completed, sets attempts to 3, and instantly suspends the worker
  Future<bool> rejectTaskAssignment({
    required String assignmentId,
    required String taskId,
    required String workerId,
    required int currentAttempts,
  }) async {
    final newAttempts = currentAttempts + 1;
    final existingAssignment = await getAssignment(assignmentId);

    if (newAttempts >= 3) {
      // 3rd rejection: 3 failed attempts reached -> Suspend worker for 1 day & mark assignment Not Completed
      final suspendedUntil = DateTime.now().add(const Duration(days: 1));
      final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (aIdx != -1) {
        _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
          status: AssignmentStatus.notCompleted,
          attempts: 3,
        );
      }
      final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
      if (uIdx != -1) {
        _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
          status: UserStatus.suspended,
          suspensionReason: '3 Failed Verification Attempts (PRD SU02)',
          suspendedUntil: suspendedUntil,
          activeAssignmentId: null,
          clearActiveAssignment: true,
        );
      }
      final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == workerId);
      if (authIdx != -1) {
        AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
          status: UserStatus.suspended,
          suspensionReason: '3 Failed Verification Attempts (PRD SU02)',
          suspendedUntil: suspendedUntil,
          activeAssignmentId: null,
          clearActiveAssignment: true,
        ));
      }
      _notifyInMemoryChange();

      if (isFirebaseAvailable) {
        try {
          await _taskAssignmentsCollection.doc(assignmentId).update({
            'status': AssignmentStatus.notCompleted.displayName,
            'attempts': 3,
          });
          await _usersCollection.doc(workerId).update({
            'status': UserStatus.suspended.displayName,
            'suspensionReason': '3 Failed Verification Attempts (PRD SU02)',
            'suspendedUntil': suspendedUntil.toIso8601String(),
            'activeAssignmentId': null,
          });
          await _notifySuspension(
            workerId: workerId,
            wardId: existingAssignment?.wardId ?? '',
            reason: '3 Failed Verification Attempts (PRD SU02)',
            relatedId: assignmentId,
          );
          return true;
        } catch (e) {
          debugPrint('Error suspending worker on 3rd rejection: $e');
          return false;
        }
      }
      return true;
    } else {
      // 1st or 2nd rejection: send back to worker dashboard as Pending
      final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
      if (aIdx != -1) {
        _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
          status: AssignmentStatus.pending,
          attempts: newAttempts,
          clearCompletedAt: true,
        );
      }
      _notifyInMemoryChange();

      if (isFirebaseAvailable) {
        try {
          await _taskAssignmentsCollection.doc(assignmentId).update({
            'status': AssignmentStatus.pending.displayName,
            'attempts': newAttempts,
            'completedAt': null,
          });
          await createNotification(
            recipientId: workerId,
            title: 'Task needs correction',
            message: 'Your completed task was sent back for correction.',
            type: 'task_rejected',
            relatedId: assignmentId,
          );
          return true;
        } catch (e) {
          debugPrint('Error rejecting task assignment: $e');
          return false;
        }
      }
      return true;
    }
  }

  /// Handles a missed deadline (PRD SU01 & AC13)
  /// Immediately suspends the worker for 1 day and marks assignment as Not Completed.
  Future<bool> handleMissedDeadline({
    required String assignmentId,
    required String workerId,
    String? taskId,
  }) async {
    final suspendedUntil = DateTime.now().add(const Duration(days: 1));
    final existingAssignment = await getAssignment(assignmentId);
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
        suspensionReason: 'Missed Task Deadline (PRD SU01)',
        suspendedUntil: suspendedUntil,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      );
    }
    final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == workerId);
    if (authIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
        status: UserStatus.suspended,
        suspensionReason: 'Missed Task Deadline (PRD SU01)',
        suspendedUntil: suspendedUntil,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      ));
    }
    _notifyInMemoryChange();

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.notCompleted.displayName,
        });
        await _usersCollection.doc(workerId).update({
          'status': UserStatus.suspended.displayName,
          'suspensionReason': 'Missed Task Deadline (PRD SU01)',
          'suspendedUntil': suspendedUntil.toIso8601String(),
          'activeAssignmentId': null,
        });
        await _notifySuspension(
          workerId: workerId,
          wardId: existingAssignment?.wardId ?? '',
          reason: 'Missed Task Deadline (PRD SU01)',
          relatedId: assignmentId,
        );
        return true;
      } catch (e) {
        debugPrint('Error suspending worker on missed deadline in Firestore: $e');
        return false;
      }
    }
    return true;
  }

  /// Checks and transitions assignments past their deadline to Not Completed and suspends worker (PRD SU01 & AC13)
  Future<void> checkMissedDeadlines() async {
    final now = DateTime.now();

    for (int i = 0; i < _inMemoryAssignments.length; i++) {
      final a = _inMemoryAssignments[i];
      if (a.status != AssignmentStatus.verified &&
          a.status != AssignmentStatus.autoVerified &&
          a.status != AssignmentStatus.notCompleted) {
        if (a.deadline.isBefore(now)) {
          await handleMissedDeadline(
            assignmentId: a.assignmentId,
            workerId: a.workerId,
            taskId: a.taskId,
          );
        }
      }
    }
  }

  /// Reinstates a suspended worker (PRD A02)
  Future<bool> reinstateWorker(String workerId) async {
    final idx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
    if (idx != -1) {
      _inMemoryUsers[idx] = _inMemoryUsers[idx].copyWith(
        status: UserStatus.available,
        suspensionReason: null,
        clearSuspensionReason: true,
        suspendedUntil: null,
        clearSuspendedUntil: true,
        clearActiveAssignment: true,
      );
    }
    final authIdx = AuthService().registeredUsers.indexWhere((u) => u.userId == workerId);
    if (authIdx != -1) {
      AuthService().updateUser(AuthService().registeredUsers[authIdx].copyWith(
        status: UserStatus.available,
        suspensionReason: null,
        clearSuspensionReason: true,
        suspendedUntil: null,
        clearSuspendedUntil: true,
        clearActiveAssignment: true,
      ));
    }
    _notifyInMemoryChange();
    if (isFirebaseAvailable) {
      try {
        await _usersCollection.doc(workerId).update({
          'status': UserStatus.available.displayName,
          'suspensionReason': null,
          'suspendedUntil': null,
          'activeAssignmentId': null,
        });
        return true;
      } catch (e) {
        debugPrint('Error reinstating worker: $e');
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
      final suspendedUntil = DateTime.now().add(const Duration(days: 1));
      final uIdx = _inMemoryUsers.indexWhere((u) => u.userId == workerId);
      if (uIdx != -1) {
        _inMemoryUsers[uIdx] = _inMemoryUsers[uIdx].copyWith(
          status: UserStatus.suspended,
          suspensionReason: '3 Failed Verification Attempts (PRD SU02)',
          suspendedUntil: suspendedUntil,
          activeAssignmentId: null,
          clearActiveAssignment: true,
        );
      }
      if (isFirebaseAvailable) {
        try {
          await _taskAssignmentsCollection.doc(assignmentId).update({
            'status': AssignmentStatus.notCompleted.displayName,
          });
          await _usersCollection.doc(workerId).update({
            'status': UserStatus.suspended.displayName,
            'suspensionReason': '3 Failed Verification Attempts (PRD SU02)',
            'suspendedUntil': suspendedUntil.toIso8601String(),
            'activeAssignmentId': null,
          });
        } catch (_) {}
      }
      await _notifySuspension(
        workerId: workerId,
        wardId: wardId,
        reason: '3 Failed Verification Attempts (PRD SU02)',
        relatedId: assignmentId,
      );
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

    await createNotification(
      recipientId: workerId,
      title: 'Task reassigned',
      message: 'Your task was reassigned with feedback from your supervisor.',
      type: 'task_reassigned',
      relatedId: newAssignmentId,
    );
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

    final suspendedUntil = DateTime.now().add(const Duration(days: 1));
    final fIdx = _inMemoryUsers.indexWhere((u) => u.userId == failedWorkerId);
    if (fIdx != -1) {
      _inMemoryUsers[fIdx] = _inMemoryUsers[fIdx].copyWith(
        status: UserStatus.suspended,
        suspensionReason: '3 Failed Verification Attempts (PRD SU02)',
        suspendedUntil: suspendedUntil,
        activeAssignmentId: null,
        clearActiveAssignment: true,
      );
    }

    final newAssignmentId = 'assign_${now.millisecondsSinceEpoch}';
    final newAssignment = TaskAssignmentModel(
      assignmentId: newAssignmentId,
      taskId: taskId,
      workerId: newWorkerId,
      wardId: wardId,
      assignmentNumber: currentAssignmentNumber + 1,
      attempts: 0,
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
          'suspensionReason': '3 Failed Verification Attempts (PRD SU02)',
          'suspendedUntil': suspendedUntil.toIso8601String(),
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

    await _notifySuspension(
      workerId: failedWorkerId,
      wardId: wardId,
      reason: '3 Failed Verification Attempts (PRD SU02)',
      relatedId: oldAssignmentId,
    );
    await createNotification(
      recipientId: newWorkerId,
      title: 'Task reassigned',
      message: 'A new task has been assigned to you.',
      type: 'task_reassigned',
      relatedId: newAssignmentId,
    );
    return newAssignment;
  }

  /// Streams real-time workforce statistics for the Admin Dashboard from Firestore
  Stream<AdminDashboardStats> streamAdminDashboardStats() {
    AdminDashboardStats calculateFallbackStats() {
      final all = [...AuthService().registeredUsers, ..._inMemoryUsers];
      final unique = <String, UserModel>{};
      for (final u in all) {
        unique[u.userId] = u;
      }
      int supervisors = 0;
      int workers = 0;
      int pending = 0;
      for (final u in unique.values) {
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
      late StreamController<AdminDashboardStats> controller;
      StreamSubscription? memSub;
      controller = StreamController<AdminDashboardStats>(
        onListen: () {
          controller.add(calculateFallbackStats());
          memSub = _inMemoryChangeNotifier.stream.listen((_) {
            if (!controller.isClosed) {
              controller.add(calculateFallbackStats());
            }
          });
        },
        onCancel: () => memSub?.cancel(),
      );
      return controller.stream;
    }

    final controller = StreamController<AdminDashboardStats>.broadcast();
    StreamSubscription? usersSub;
    StreamSubscription? wardsSub;
    StreamSubscription? memSub;

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

      if (!isFirebaseAvailable) {
        // Merge any in-memory/auth users not yet in latestUsers (isolated for offline widget tests)
        final allMem = [...AuthService().registeredUsers, ..._inMemoryUsers];
        for (final u in allMem) {
          if (!seenUserIds.contains(u.userId)) {
            if (u.status == UserStatus.pending) {
              pending++;
            } else if (u.status != UserStatus.suspended) {
              if (u.role == UserRole.supervisor) supervisors++;
              if (u.role == UserRole.worker) workers++;
            }
          }
        }
      }

      int finalWards = latestWardsCount;
      if (!isFirebaseAvailable && finalWards == 0 && _inMemoryWards.isNotEmpty) {
        finalWards = _inMemoryWards.length;
      }

      controller.add(AdminDashboardStats(
        totalWards: finalWards,
        totalSupervisors: supervisors,
        totalWorkers: workers,
        pendingRegistrations: pending,
      ));
    }

    memSub = _inMemoryChangeNotifier.stream.listen((_) {
      recalculateAndEmit();
    });

    // Initial check on wards count (no auto-seeding for live application)
    Future.microtask(() async {
      try {
        final wSnap = await _wardsCollection.get();
        if (wSnap.docs.isNotEmpty) {
          latestWardsCount = wSnap.docs.length;
        } else {
          final wAltSnap = await firestore.collection('Wards').get();
          if (wAltSnap.docs.isNotEmpty) {
            latestWardsCount = wAltSnap.docs.length;
          }
        }
        recalculateAndEmit();
      } catch (e) {
        debugPrint('Wards initial check error: $e');
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
      memSub?.cancel();
    };

    return controller.stream;
  }

  // ==================== WORKER TASK OPERATIONS ====================

  /// Retrieves the active task assignment for a given worker from Firestore or in-memory
  Future<TaskAssignmentModel?> getActiveAssignmentForWorker(String workerId) async {
    // First check in-memory assignments (for tests and offline mode)
    final inMemoryMatch = _inMemoryAssignments.where((a) =>
        a.workerId == workerId &&
        (a.status == AssignmentStatus.pending ||
         a.status == AssignmentStatus.pendingVerification));
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
                a.status == AssignmentStatus.pending ||
                a.status == AssignmentStatus.pendingVerification)
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

  /// Real-time stream of the active task assignment for a given worker
  Stream<TaskAssignmentModel?> streamActiveAssignmentForWorker(String workerId) {
    if (isFirebaseAvailable) {
      return _taskAssignmentsCollection
          .where('workerId', isEqualTo: workerId)
          .snapshots()
          .map((snapshot) {
        final active = snapshot.docs
            .map((doc) => TaskAssignmentModel.fromMap(doc.data(), doc.id))
            .where((a) =>
                a.status == AssignmentStatus.pending ||
                a.status == AssignmentStatus.pendingVerification)
            .toList();
        return active.isNotEmpty ? active.last : null;
      });
    }

    TaskAssignmentModel? getActive() {
      final inMemoryMatch = _inMemoryAssignments.where((a) =>
          a.workerId == workerId &&
          (a.status == AssignmentStatus.pending ||
           a.status == AssignmentStatus.pendingVerification));
      return inMemoryMatch.isNotEmpty ? inMemoryMatch.last : null;
    }

    late StreamController<TaskAssignmentModel?> controller;
    StreamSubscription? sub;
    controller = StreamController<TaskAssignmentModel?>(
      onListen: () {
        controller.add(getActive());
        sub = _inMemoryChangeNotifier.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(getActive());
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }


  /// Marks an assignment as completed / pending verification by the worker (PRD 6.4 & C01)
  Future<bool> markAssignmentCompleted(String assignmentId) async {
    final now = DateTime.now();
    final assignment = await getAssignment(assignmentId);
    final aIdx = _inMemoryAssignments.indexWhere((a) => a.assignmentId == assignmentId);
    if (aIdx != -1) {
      _inMemoryAssignments[aIdx] = _inMemoryAssignments[aIdx].copyWith(
        status: AssignmentStatus.pendingVerification,
        completedAt: now,
      );
      _notifyInMemoryChange();
    }

    if (isFirebaseAvailable) {
      try {
        await _taskAssignmentsCollection.doc(assignmentId).update({
          'status': AssignmentStatus.pendingVerification.displayName,
          'completedAt': now.toIso8601String(),
        });
        final supervisorId =
            await _supervisorIdForWard(assignment?.wardId ?? '');
        if (supervisorId != null) {
          await createNotification(
            recipientId: supervisorId,
            title: 'Task awaiting verification',
            message: 'A worker completed a task that needs verification.',
            type: 'task_completed',
            relatedId: assignment?.taskId ?? assignmentId,
          );
        }
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