import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

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

  /// Saves or updates a user profile in the Firestore 'users' collection
  Future<bool> saveUserProfile(UserModel user) async {
    if (!isFirebaseAvailable) return true;
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

  /// Fetches a user profile document from Firestore by user ID (Firebase UID)
  Future<UserModel?> getUserProfile(String uid) async {
    if (!isFirebaseAvailable) return null;
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

  /// Fetches a user profile document from Firestore by user email
  Future<UserModel?> getUserByEmail(String email) async {
    if (!isFirebaseAvailable) return null;
    try {
      final query = await _usersCollection
          .where('email', isEqualTo: email.trim().toLowerCase())
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

  /// Real-time stream of a user's profile (useful for watching status changes from Pending -> Approved)
  Stream<UserModel?> streamUserProfile(String uid) {
    if (!isFirebaseAvailable) {
      return const Stream.empty();
    }
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  /// Updates the verification status of a staff member (e.g. pending -> approved / rejected)
  Future<bool> updateStatus(String uid, UserStatus status) async {
    if (!isFirebaseAvailable) return true;
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

  /// Assigns a hospital ward to a worker or supervisor (and optionally updates their status)
  Future<bool> assignWard(String uid, String wardId, {UserStatus? newStatus}) async {
    if (!isFirebaseAvailable) return true;
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

  /// Checks if an Employee ID is already registered in the Firestore database
  Future<bool> isEmployeeIdRegistered(String employeeId) async {
    if (!isFirebaseAvailable) return false;
    try {
      final query = await _usersCollection
          .where('employeeId', isEqualTo: employeeId.trim().toUpperCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking employee ID uniqueness in Firestore: $e');
      return false;
    }
  }

  /// Retrieves all users matching a particular status (e.g. Pending for Admin approval dashboard)
  Future<List<UserModel>> getUsersByStatus(UserStatus status) async {
    if (!isFirebaseAvailable) return [];
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

  /// Streams real-time workforce statistics for the Admin Dashboard
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
        totalWards: 0,
        totalSupervisors: supervisors,
        totalWorkers: workers,
        pendingRegistrations: pending,
      );
    }

    if (!isFirebaseAvailable) {
      yield getFallbackStats();
      return;
    }

    // Immediately yield current in-memory stats while Firestore connects
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

        // Also merge any in-memory registered users that may not have synced
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

