import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  supervisor,
  worker;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.worker:
        return 'Worker';
    }
  }

  String get idPrefix {
    switch (this) {
      case UserRole.admin:
        return 'ADM';
      case UserRole.supervisor:
        return 'SUP';
      case UserRole.worker:
        return 'WRK';
    }
  }

  String get exampleId {
    switch (this) {
      case UserRole.admin:
        return 'ADM-001';
      case UserRole.supervisor:
        return 'SUP-001';
      case UserRole.worker:
        return 'WRK-001';
    }
  }

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.worker;
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'worker':
      default:
        return UserRole.worker;
    }
  }
}

enum UserStatus {
  pending,
  available,
  busy,
  suspended,
  assigned;

  String get displayName {
    switch (this) {
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.available:
        return 'Available';
      case UserStatus.busy:
        return 'Busy';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.assigned:
        return 'Assigned';
    }
  }

  static UserStatus fromString(String? status) {
    if (status == null) return UserStatus.pending;
    switch (status.toLowerCase()) {
      case 'available':
        return UserStatus.available;
      case 'busy':
        return UserStatus.busy;
      case 'suspended':
        return UserStatus.suspended;
      case 'assigned':
        return UserStatus.assigned;
      case 'pending':
      default:
        return UserStatus.pending;
    }
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

class UserModel {
  final String userId;
  final String name;
  final String employeeId;
  final String email;
  final UserRole role;
  final DocumentReference? wardRef;
  final String? wardId;
  final UserStatus status;
  final String? activeAssignmentId;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.role,
    this.wardRef,
    this.wardId,
    this.status = UserStatus.pending,
    this.activeAssignmentId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'fullName': name,
      'displayName': name,
      'employeeId': employeeId,
      'email': email,
      'role': role.displayName,
      'wardRef': wardRef,
      'wardId': wardId,
      'status': status.displayName,
      'activeAssignmentId': activeAssignmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    final extractedName = (map['name'] as String?)?.trim() ??
        (map['fullName'] as String?)?.trim() ??
        (map['displayName'] as String?)?.trim() ??
        '';

    return UserModel(
      userId: id,
      name: extractedName,
      employeeId: map['employeeId'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.fromString(map['role']),
      wardRef: map['wardRef'] is DocumentReference ? map['wardRef'] as DocumentReference : null,
      wardId: map['wardId'],
      status: UserStatus.fromString(map['status']),
      activeAssignmentId: map['activeAssignmentId'],
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  UserModel copyWith({
    String? userId,
    String? name,
    String? employeeId,
    String? email,
    UserRole? role,
    DocumentReference? wardRef,
    String? wardId,
    UserStatus? status,
    String? activeAssignmentId,
    DateTime? createdAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      role: role ?? this.role,
      wardRef: wardRef ?? this.wardRef,
      wardId: wardId ?? this.wardId,
      status: status ?? this.status,
      activeAssignmentId: activeAssignmentId ?? this.activeAssignmentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
