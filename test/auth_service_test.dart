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
    test('Full name validation requires at least 2 characters', () {
      expect(AuthService.validateFullName(''), 'Full Name is required');
      expect(AuthService.validateFullName('   '), 'Full Name is required');
      expect(AuthService.validateFullName('A'), 'Full Name must be at least 2 characters long');
      expect(AuthService.validateFullName('John Doe'), isNull);
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
      expect(result.user!.fullName, 'Ramesh Kumar');
      expect(result.user!.employeeId, 'WRK-101');
      expect(result.user!.email, 'ramesh@hospital.org');
      expect(result.user!.role, UserRole.worker);
      expect(result.user!.status, UserStatus.pending);
      expect(result.user!.ward, isNull);
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
      expect(result.user!.fullName, 'Neha Sharma');
      expect(result.user!.employeeId, 'SUP-202');
      expect(result.user!.email, 'neha.sharma@hospital.org');
      expect(result.user!.role, UserRole.supervisor);
      expect(result.user!.status, UserStatus.pending);
      expect(result.user!.ward, isNull);
    });

    test('Rejects duplicate email registration', () async {
      await authService.registerUser(
        fullName: 'First User',
        employeeId: 'WRK-101',
        email: 'duplicate@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      final duplicateResult = await authService.registerUser(
        fullName: 'Second User',
        employeeId: 'WRK-102',
        email: 'DUPLICATE@hospital.org',
        password: 'password123',
        role: UserRole.worker,
      );

      expect(duplicateResult.isSuccess, isFalse);
      expect(duplicateResult.errorMessage, 'An account with this email already exists.');
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
  });
}
