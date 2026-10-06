import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

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

class LoginResult {
  final bool isSuccess;
  final String? errorMessage;
  final UserModel? user;

  const LoginResult.success(this.user)
      : isSuccess = true,
        errorMessage = null;

  const LoginResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _firebaseAuth;
  final FirestoreService _firestoreService = FirestoreService();

  FirebaseAuth get auth => _firebaseAuth ?? FirebaseAuth.instance;

  // Visible for testing / dependency injection
  void setDependencies({FirebaseAuth? auth}) {
    _firebaseAuth = auth;
  }

  final List<UserModel> _registeredUsers = [];

  List<UserModel> get registeredUsers => List.unmodifiable(_registeredUsers);

  void clearUsers() {
    _registeredUsers.clear();
  }

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
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

  /// Registers a new user with Firebase Authentication and stores metadata in Firestore
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

    // Local pre-checks for fast client validation & test environments
    final isEmailDuplicate = _registeredUsers.any(
      (user) => user.email.toLowerCase() == cleanEmail,
    );
    if (isEmailDuplicate) {
      return const RegisterResult.failure(
        'An account with this email already exists.',
      );
    }

    final isIdDuplicate = _registeredUsers.any(
      (user) => user.employeeId.toUpperCase() == cleanEmployeeId,
    );
    if (isIdDuplicate) {
      return const RegisterResult.failure(
        'This Employee ID is already registered.',
      );
    }

    if (isFirebaseAvailable) {
      try {
        // 1. Create User in Firebase Auth
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );

        final firebaseUser = userCredential.user;
        if (firebaseUser == null) {
          return const RegisterResult.failure('Failed to create account.');
        }

        // 2. Update display name in Firebase Auth
        await firebaseUser.updateDisplayName(cleanFullName);

        // 3. Create UserModel
        final newUser = UserModel(
          id: firebaseUser.uid,
          fullName: cleanFullName,
          employeeId: cleanEmployeeId,
          email: cleanEmail,
          password: password,
          role: role,
          status: UserStatus.pending,
          ward: null,
        );

        // 4. Store user profile and status in Firestore via FirestoreService
        await _firestoreService.saveUserProfile(newUser);

        _registeredUsers.add(newUser);
        return RegisterResult.success(newUser);
      } on FirebaseAuthException catch (e) {
        return RegisterResult.failure(_handleFirebaseAuthError(e));
      } catch (e) {
        return RegisterResult.failure('An unexpected error occurred: ${e.toString()}');
      }
    } else {
      // In-memory fallback (used in unit/widget tests or offline development)
      final newUser = UserModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fullName: cleanFullName,
        employeeId: cleanEmployeeId,
        email: cleanEmail,
        password: password,
        role: role,
        status: UserStatus.pending,
        ward: null,
      );

      _registeredUsers.add(newUser);
      return RegisterResult.success(newUser);
    }
  }

  /// Logs in a user with Firebase Authentication
  Future<LoginResult> loginUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (isFirebaseAvailable) {
      try {
        final userCredential = await auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );

        final firebaseUser = userCredential.user;
        if (firebaseUser == null) {
          return const LoginResult.failure('Failed to authenticate.');
        }

        // Fetch user data from Firestore
        final userProfile = await _firestoreService.getUserProfile(firebaseUser.uid);
        if (userProfile != null) {
          return LoginResult.success(userProfile);
        }

        // Fallback user if Firestore document is not yet configured
        final user = UserModel(
          id: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? '',
          employeeId: '',
          email: cleanEmail,
          password: '',
          role: UserRole.supervisor,
          status: UserStatus.pending,
        );
        return LoginResult.success(user);
      } on FirebaseAuthException catch (e) {
        return LoginResult.failure(_handleFirebaseAuthError(e));
      } catch (e) {
        return LoginResult.failure('Login failed: ${e.toString()}');
      }
    } else {
      // In-memory fallback
      final match = _registeredUsers.where(
        (u) => u.email.toLowerCase() == cleanEmail && u.password == password,
      );
      if (match.isNotEmpty) {
        return LoginResult.success(match.first);
      }
      return const LoginResult.failure('Invalid email or password.');
    }
  }

  /// Signs out the currently authenticated user
  Future<void> signOut() async {
    if (isFirebaseAvailable) {
      await auth.signOut();
    }
  }

  /// User friendly error messages from Firebase auth codes
  String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled in Firebase.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network connection error. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
