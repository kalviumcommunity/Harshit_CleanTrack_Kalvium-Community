enum UserRole {
  worker,
  supervisor;

  String get displayName {
    switch (this) {
      case UserRole.worker:
        return 'Worker';
      case UserRole.supervisor:
        return 'Supervisor';
    }
  }

  String get idPrefix {
    switch (this) {
      case UserRole.worker:
        return 'WRK';
      case UserRole.supervisor:
        return 'SUP';
    }
  }

  String get exampleId {
    switch (this) {
      case UserRole.worker:
        return 'WRK-001';
      case UserRole.supervisor:
        return 'SUP-001';
    }
  }

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.worker;
    switch (role.toLowerCase()) {
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
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case UserStatus.pending:
        return 'Pending';
      case UserStatus.approved:
        return 'Approved';
      case UserStatus.rejected:
        return 'Rejected';
    }
  }

  static UserStatus fromString(String? status) {
    if (status == null) return UserStatus.pending;
    switch (status.toLowerCase()) {
      case 'approved':
        return UserStatus.approved;
      case 'rejected':
        return UserStatus.rejected;
      case 'pending':
      default:
        return UserStatus.pending;
    }
  }
}

class UserModel {
  final String id;
  final String fullName;
  final String employeeId;
  final String email;
  final String password;
  final UserRole role;
  final UserStatus status;
  final String? ward;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.employeeId,
    required this.email,
    required this.password,
    required this.role,
    this.status = UserStatus.pending,
    this.ward,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'employeeId': employeeId,
      'email': email,
      'role': role.displayName,
      'status': status.displayName,
      'ward': ward,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName'] ?? '',
      employeeId: map['employeeId'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.fromString(map['role']),
      status: UserStatus.fromString(map['status']),
      ward: map['ward'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? employeeId,
    String? email,
    String? password,
    UserRole? role,
    UserStatus? status,
    String? ward,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      status: status ?? this.status,
      ward: ward ?? this.ward,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
