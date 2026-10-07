import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/services/auth_service.dart';

void main() {
  late AuthService authService;

  setUp(() {
    authService = AuthService();
    authService.clearUsers();
  });

  group('AuthService Validation Tests', () {
    test('Full name validation requires letters and spaces only', () {
      expect(AuthService.validateFullName(''), 'Full Name is required');
      expect(AuthService.validateFullName('   '), 'Full Name is required');
      expect(AuthService.validateFullName('A'), 'Full Name must be at least 2 characters long');
      // Rejects numbers
      expect(AuthService.validateFullName('John123'), 'Full Name can only contain letters and spaces');
      expect(AuthService.validateFullName('12345'), 'Full Name can only contain letters and spaces');
      // Rejects special characters
      expect(AuthService.validateFullName('John@Doe'), 'Full Name can only contain letters and spaces');
      expect(AuthService.validateFullName('Neha#Sharma'), 'Full Name can only contain letters and spaces');
      expect(AuthService.validateFullName('Alex_Smith'), 'Full Name can only contain letters and spaces');
      // Accepts valid string names
      expect(AuthService.validateFullName('John Doe'), isNull);
      expect(AuthService.validateFullName('Neha Sharma'), isNull);
      expect(AuthService.validateFullName('Alice'), isNull);
    });

    test('Worker Employee ID format validation', () {
      expect(
        AuthService.validateEmployeeId('', UserRole.worker),
        'Employee ID is required',
      );
      expect(
        AuthService.validateEmployeeId('SUP-001', UserRole.worker),
        'Worker ID must follow format WRK-001 (e.g., WRK-102)',
      );
      expect(
        AuthService.validateEmployeeId('WRK-12', UserRole.worker),
        'Worker ID must follow format WRK-001 (e.g., WRK-102)',
      );
      expect(
        AuthService.validateEmployeeId('WRK-1234', UserRole.worker),
        'Worker ID must follow format WRK-001 (e.g., WRK-102)',
      );
      expect(
        AuthService.validateEmployeeId('WRK-001', UserRole.worker),
        isNull,
      );
      expect(
        AuthService.validateEmployeeId('wrk-001', UserRole.worker),
        isNull,
      );
    });

    test('Supervisor Employee ID format validation', () {
      expect(
        AuthService.validateEmployeeId('', UserRole.supervisor),
        'Employee ID is required',
      );
      expect(
        AuthService.validateEmployeeId('WRK-001', UserRole.supervisor),
        'Supervisor ID must follow format SUP-001 (e.g., SUP-102)',
      );
      expect(
        AuthService.validateEmployeeId('SUP-12', UserRole.supervisor),
        'Supervisor ID must follow format SUP-001 (e.g., SUP-102)',
      );
      expect(
        AuthService.validateEmployeeId('SUP-001', UserRole.supervisor),
        isNull,
      );
      expect(
        AuthService.validateEmployeeId('sup-001', UserRole.supervisor),
        isNull,
      );
    });

    test('Email format validation', () {
      expect(AuthService.validateEmail(''), 'Email is required');
      expect(AuthService.validateEmail('invalid-email'), 'Please enter a valid email address');
      expect(AuthService.validateEmail('name@hospital'), 'Please enter a valid email address');
      expect(AuthService.validateEmail('name@hospital.org'), isNull);
    });

    test('Password and Confirm Password validation', () {
      expect(AuthService.validatePassword(''), 'Password is required');
      expect(AuthService.validatePassword('12345'), 'Password must be at least 6 characters long');
      expect(AuthService.validatePassword('password123'), isNull);

      expect(AuthService.validateConfirmPassword('', 'password123'), 'Confirm Password is required');
      expect(AuthService.validateConfirmPassword('different', 'password123'), 'Passwords do not match');
      expect(AuthService.validateConfirmPassword('password123', 'password123'), isNull);
    });
  });

  group('AuthService Registration Tests', () {
    test('Successfully registers a Worker with Pending status and null ward', () async {
      final result = await authService.registerUser(
        fullName: 'Ramesh Kumar',
        employeeId: 'WRK-101',
        email: 'ramesh@hospital.org',
        password: 'securePassword123',
        role: UserRole.worker,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.name, 'Ramesh Kumar');
      expect(result.user!.employeeId, 'WRK-101');
      expect(result.user!.email, 'ramesh@hospital.org');
      expect(result.user!.role, UserRole.worker);
      expect(result.user!.status, UserStatus.pending);
      expect(result.user!.wardId, isNull);
    });

    test('Successfully registers a Supervisor with Pending status and null ward', () async {
      final result = await authService.registerUser(
        fullName: 'Neha Sharma',
        employeeId: 'SUP-202',
        email: 'neha.sharma@hospital.org',
        password: 'securePassword123',
        role: UserRole.supervisor,
      );

      expect(result.isSuccess, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.name, 'Neha Sharma');
      expect(result.user!.employeeId, 'SUP-202');
      expect(result.user!.email, 'neha.sharma@hospital.org');
      expect(result.user!.role, UserRole.supervisor);
      expect(result.user!.status, UserStatus.pending);
      expect(result.user!.wardId, isNull);
    });

    test('Rejects duplicate email registration with exact error message', () async {
      final firstResult = await authService.registerUser(
        fullName: 'First User',
        employeeId: 'WRK-101',
        email: 'duplicate@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      expect(firstResult.isSuccess, isTrue);

      final secondResult = await authService.registerUser(
        fullName: 'Second User',
        employeeId: 'WRK-102',
        email: 'DUPLICATE@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      expect(secondResult.isSuccess, isFalse);
      expect(secondResult.errorMessage, 'An account with this email already exists.');
    });

    test('Rejects duplicate employee ID registration', () async {
      await authService.registerUser(
        fullName: 'First User',
        employeeId: 'WRK-101',
        email: 'first@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      final duplicateResult = await authService.registerUser(
        fullName: 'Second User',
        employeeId: 'wrk-101',
        email: 'second@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      expect(duplicateResult.isSuccess, isFalse);
      expect(duplicateResult.errorMessage, 'This Employee ID is already registered.');
    });

    test('Rejects registration when full name contains numbers or special characters', () async {
      final numberResult = await authService.registerUser(
        fullName: 'John123',
        employeeId: 'WRK-101',
        email: 'john@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );
      expect(numberResult.isSuccess, isFalse);
      expect(numberResult.errorMessage, 'Full Name can only contain letters and spaces');

      final symbolResult = await authService.registerUser(
        fullName: 'John@Doe',
        employeeId: 'WRK-101',
        email: 'john@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );
      expect(symbolResult.isSuccess, isFalse);
      expect(symbolResult.errorMessage, 'Full Name can only contain letters and spaces');
    });
  });

  group('UserModel & Firestore Mapping Tests', () {
    test('UserModel toJson and fromMap serialize properly', () {
      final user = UserModel(
        userId: 'user-123',
        name: 'Dr. Ramesh',
        employeeId: 'SUP-005',
        email: 'ramesh@hospital.org',
        role: UserRole.supervisor,
        status: UserStatus.pending,
        wardId: 'ward-01',
      );

      final json = user.toJson();
      expect(json['userId'], 'user-123');
      expect(json['name'], 'Dr. Ramesh');
      expect(json['role'], 'Supervisor');
      expect(json['status'], 'Pending');
      expect(json['wardId'], 'ward-01');

      final fromMapUser = UserModel.fromMap(json, 'user-123');
      expect(fromMapUser.userId, 'user-123');
      expect(fromMapUser.name, 'Dr. Ramesh');
      expect(fromMapUser.role, UserRole.supervisor);
      expect(fromMapUser.status, UserStatus.pending);
      expect(fromMapUser.wardId, 'ward-01');
    });

    test('UserModel copyWith works accurately', () {
      final user = UserModel(
        userId: 'user-1',
        name: 'Asha Singh',
        employeeId: 'WRK-101',
        email: 'asha@hospital.org',
        role: UserRole.worker,
        status: UserStatus.pending,
      );

      final availableUser = user.copyWith(
        status: UserStatus.available,
        wardId: 'Emergency Ward',
      );

      expect(availableUser.userId, 'user-1');
      expect(availableUser.status, UserStatus.available);
      expect(availableUser.wardId, 'Emergency Ward');
      expect(availableUser.role, UserRole.worker);
    });

    test('UserRole and UserStatus fromString parsing', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('supervisor'), UserRole.supervisor);
      expect(UserRole.fromString('Worker'), UserRole.worker);
      expect(UserRole.fromString('unknown'), UserRole.worker);

      expect(UserStatus.fromString('pending'), UserStatus.pending);
      expect(UserStatus.fromString('available'), UserStatus.available);
      expect(UserStatus.fromString('busy'), UserStatus.busy);
      expect(UserStatus.fromString('suspended'), UserStatus.suspended);
      expect(UserStatus.fromString('assigned'), UserStatus.assigned);
      expect(UserStatus.fromString(null), UserStatus.pending);
    });
  });
}
