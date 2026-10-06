import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/register_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
import 'package:cleantrack/screens/pending_verification_screen.dart';
import 'package:cleantrack/services/auth_service.dart';
import 'package:cleantrack/models/user_model.dart';

void main() {
  setUp(() {
    AuthService().clearUsers();
  });

  testWidgets('Register screen renders all key elements and texts', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    // Header Branding
    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('Hospital Housekeeping Management'), findsOneWidget);

    // Form Header & Info Box
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Register your staff account'), findsOneWidget);
    expect(find.textContaining('Account status remains'), findsOneWidget);

    // Fields
    expect(find.byKey(const Key('fullNameField')), findsOneWidget);
    expect(find.byKey(const Key('employeeIdField')), findsOneWidget);
    expect(find.byKey(const Key('emailField')), findsOneWidget);
    expect(find.byKey(const Key('passwordField')), findsOneWidget);
    expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);

    // Role options
    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);

    // Register Button & Login Link
    expect(find.byKey(const Key('registerButton')), findsOneWidget);
    expect(find.byKey(const Key('loginLink')), findsOneWidget);
  });

  testWidgets('Validates required fields when submitted empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    // Tap REGISTER button without filling fields
    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Full Name is required'), findsOneWidget);
    expect(find.text('Employee ID is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm Password is required'), findsOneWidget);
  });

  testWidgets('Validates password mismatch', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    await tester.enterText(find.byKey(const Key('fullNameField')), 'Neha Sharma');
    await tester.enterText(find.byKey(const Key('employeeIdField')), 'SUP-001');
    await tester.enterText(find.byKey(const Key('emailField')), 'neha@hospital.org');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'different123');

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('Validates Supervisor Employee ID format', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    // Select Supervisor (default) and enter invalid ID
    await tester.enterText(find.byKey(const Key('fullNameField')), 'Neha Sharma');
    await tester.enterText(find.byKey(const Key('employeeIdField')), 'WRK-001');
    await tester.enterText(find.byKey(const Key('emailField')), 'neha@hospital.org');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Supervisor ID must follow format SUP-001 (e.g., SUP-102)'), findsOneWidget);
  });

  testWidgets('Validates Worker Employee ID format when role switched to Worker', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    // Switch role to Worker
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();

    // Enter Supervisor ID under Worker role
    await tester.enterText(find.byKey(const Key('fullNameField')), 'Ramesh Patel');
    await tester.enterText(find.byKey(const Key('employeeIdField')), 'SUP-001');
    await tester.enterText(find.byKey(const Key('emailField')), 'ramesh@hospital.org');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Worker ID must follow format WRK-001 (e.g., WRK-102)'), findsOneWidget);
  });

  testWidgets('Successfully registers Worker and navigates to Registration successful screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    // Switch to Worker
    await tester.tap(find.text('Worker'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('fullNameField')), 'Ramesh Patel');
    await tester.enterText(find.byKey(const Key('employeeIdField')), 'WRK-105');
    await tester.enterText(find.byKey(const Key('emailField')), 'ramesh.patel@hospital.org');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    // Verify Direct Navigation to Success / Verification Screen
    expect(find.text('Registration successful'), findsOneWidget);
    expect(
      find.text('Dashboard access will become available after an administrator verifies your identity.'),
      findsOneWidget,
    );

    // Verify user in service has Pending status and no ward
    final users = AuthService().registeredUsers;
    expect(users.length, 1);
    expect(users.first.status, UserStatus.pending);
    expect(users.first.ward, isNull);
    expect(users.first.role, UserRole.worker);
  });

  testWidgets('Successfully registers Supervisor and navigates to Registration successful screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    await tester.enterText(find.byKey(const Key('fullNameField')), 'Dr. Ananya Roy');
    await tester.enterText(find.byKey(const Key('employeeIdField')), 'SUP-301');
    await tester.enterText(find.byKey(const Key('emailField')), 'ananya.roy@hospital.org');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.enterText(find.byKey(const Key('confirmPasswordField')), 'password123');

    await tester.tap(find.byKey(const Key('registerButton')));
    await tester.pumpAndSettle();

    expect(find.text('Registration successful'), findsOneWidget);
    expect(
      find.text('Dashboard access will become available after an administrator verifies your identity.'),
      findsOneWidget,
    );

    final users = AuthService().registeredUsers;
    expect(users.length, 1);
    expect(users.first.role, UserRole.supervisor);
    expect(users.first.status, UserStatus.pending);
  });

  testWidgets('Navigation from RegisterScreen to LoginScreen via LOGIN link', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RegisterScreen(),
      ),
    );

    await tester.tap(find.byKey(const Key('loginLink')));
    await tester.pumpAndSettle();

    // Login screen displays the Login page heading and register action
    expect(find.text('Login page'), findsOneWidget);
    expect(find.byKey(const Key('goToRegisterButton')), findsOneWidget);
  });

  testWidgets('LoginScreen displays correctly and navigates to RegisterScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Login page'), findsOneWidget);
    expect(find.byKey(const Key('goToRegisterButton')), findsOneWidget);

    // Tap to go to register
    await tester.tap(find.byKey(const Key('goToRegisterButton')));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('PendingVerificationScreen displays verification message correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PendingVerificationScreen(),
      ),
    );

    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('Hospital Housekeeping Management'), findsOneWidget);
    expect(find.text('Registration successful'), findsOneWidget);
    expect(
      find.text('Dashboard access will become available after an administrator verifies your identity.'),
      findsOneWidget,
    );
  });
}
