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

class UserModel {
  final String id;
  final String fullName;
  final String employeeId;
  final String email;
  final String password;
  final UserRole role;
  final UserStatus status;
  final String? wardId;
  final String? activeAssignmentId;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.employeeId,
    required this.email,
    required this.password,
    required this.role,
    this.status = UserStatus.pending,
    String? wardId,
    String? ward,
    this.activeAssignmentId,
    DateTime? createdAt,
  })  : wardId = wardId ?? ward,
        createdAt = createdAt ?? DateTime.now();

  String get name => fullName;
  String? get ward => wardId;

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'id': id,
      'name': fullName,
      'fullName': fullName,
      'employeeId': employeeId,
      'email': email,
      'role': role.displayName,
      'status': status.displayName,
      'wardId': wardId,
      'ward': wardId,
      'activeAssignmentId': activeAssignmentId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['name'] ?? map['fullName'] ?? '',
      employeeId: map['employeeId'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      role: UserRole.fromString(map['role']),
      status: UserStatus.fromString(map['status']),
      wardId: map['wardId'] ?? map['ward'],
      activeAssignmentId: map['activeAssignmentId'],
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
    String? wardId,
    String? ward,
    String? activeAssignmentId,
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
      wardId: wardId ?? ward ?? this.wardId,
      activeAssignmentId: activeAssignmentId ?? this.activeAssignmentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
