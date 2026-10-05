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
}
