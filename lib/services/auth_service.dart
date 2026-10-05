import '../models/user_model.dart';

class RegisterResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? user;

  const RegisterResult.success(this.user)
      : isSuccess = true,
        errorMessage = null;

  const RegisterResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final List<UserModel> _registeredUsers = [];

  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  void clearUsers() {
    _registeredUsers.clear();
  }

  /// Validates an employee ID against the selected role.
  /// Worker: WRK-001 format (e.g. WRK- followed by 3 digits)
  /// Supervisor: SUP-001 format (e.g. SUP- followed by 3 digits)
  static String? validateEmployeeId(String? value, UserRole role) {
    if (value == null || value.trim().isEmpty) {
      return 'Employee ID is required';
    }

    final trimmed = value.trim().toUpperCase();
    final workerPattern = RegExp(r'^WRK-\d{3}$');
    final supervisorPattern = RegExp(r'^SUP-\d{3}$');

    if (role == UserRole.worker) {
      if (!workerPattern.hasMatch(trimmed)) {
        return 'Worker ID must follow format WRK-001 (e.g., WRK-102)';
      }
    } else if (role == UserRole.supervisor) {
      if (!supervisorPattern.hasMatch(trimmed)) {
        return 'Supervisor ID must follow format SUP-001 (e.g., SUP-102)';
      }
    }

    return null;
  }

  /// Validates email address format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailPattern.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates full name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full Name is required';
    }
    if (value.trim().length < 2) {
      return 'Full Name must be at least 2 characters long';
    }
    return null;
  }

  /// Validates password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  /// Validates confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm Password is required';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Registers a new user
  Future<RegisterResult> registerUser({
    required String fullName,
    required String employeeId,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanEmployeeId = employeeId.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();

    // Check duplicate email
    final isEmailDuplicate = _registeredUsers.any(
      (user) => user.email.toLowerCase() == cleanEmail,
    );
    if (isEmailDuplicate) {
      return const RegisterResult.failure(
        'An account with this email already exists.',
      );
    }

    // Check duplicate employee ID
    final isIdDuplicate = _registeredUsers.any(
      (user) => user.employeeId.toUpperCase() == cleanEmployeeId,
    );
    if (isIdDuplicate) {
      return const RegisterResult.failure(
        'This Employee ID is already registered.',
      );
    }

    // Create new user with Pending status and no ward
    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: cleanFullName,
      employeeId: cleanEmployeeId,
      email: cleanEmail,
      password: password,
      role: role,
      status: UserStatus.pending,
      ward: null, // Ward is not assigned during registration
    );

    _registeredUsers.add(newUser);
    return RegisterResult.success(newUser);
  }
}
