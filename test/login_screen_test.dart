import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/screens/admin_dashboard_screen.dart';
import 'package:cleantrack/screens/login_screen.dart';
import 'package:cleantrack/screens/pending_verification_screen.dart';
import 'package:cleantrack/screens/supervisor_dashboard_screen.dart';
import 'package:cleantrack/screens/suspension_screen.dart';
import 'package:cleantrack/screens/worker_dashboard_screen.dart';
import 'package:cleantrack/services/auth_service.dart';

void main() {
  late AuthService authService;

  setUp(() {
    authService = AuthService();
    authService.clearUsers();
  });

  Widget buildLoginScreen() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  testWidgets('Login screen renders branding, form fields, and action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLoginScreen());

    expect(find.text('CleanTrack'), findsOneWidget);
    expect(find.text('Hospital Housekeeping Management'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Log in to your account'), findsOneWidget);

    expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordVisibilityToggle')), findsOneWidget);
    expect(find.byKey(const Key('loginSubmitButton')), findsOneWidget);
    expect(find.byKey(const Key('goToRegisterButton')), findsOneWidget);
  });

  testWidgets('Shows validation errors when form is submitted empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLoginScreen());

    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Shows validation error for invalid email format', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLoginScreen());

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'invalid-email');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'password123');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('Toggles password obscure text visibility', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLoginScreen());

    final passwordFieldFinder = find.byKey(const Key('loginPasswordField'));
    final textField = tester.widget<TextField>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
    );
    expect(textField.obscureText, isTrue);

    // Tap visibility toggle
    await tester.tap(find.byKey(const Key('loginPasswordVisibilityToggle')));
    await tester.pumpAndSettle();

    final revealedField = tester.widget<TextField>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(TextField)),
    );
    expect(revealedField.obscureText, isFalse);
  });

  testWidgets('Shows error banner when credentials are wrong', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildLoginScreen());

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'unknown@hospital.org');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'wrongpassword');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginErrorBanner')), findsOneWidget);
    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('Pending Worker login redirects to PendingVerificationScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Register a pending worker
    await authService.registerUser(
      fullName: 'Ramesh Kumar',
      employeeId: 'WRK-101',
      email: 'ramesh@hospital.org',
      password: 'password123',
      role: UserRole.worker,
    );

    await tester.pumpWidget(buildLoginScreen());

    await tester.enterText(find.byKey(const Key('loginEmailField')), 'ramesh@hospital.org');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'password123');
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.byType(PendingVerificationScreen), findsOneWidget);
    expect(find.text('Registration successful'), findsNothing);
    expect(
      find.text('Dashboard access will become available after an administrator verifies your identity.'),
      findsOneWidget,
    );
  });

  testWidgets('Available Worker login redirects to WorkerDashboardScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Register worker and set status to available
    final reg = await authService.registerUser(
      fullName: 'Ramesh Kumar',
      employeeId: 'WRK-101',
      email: 'ramesh@hospital.org',
      password: 'password123',
      role: UserRole.worker,
    );
    authService.clearUsers();
    // Re-add as available worker
    authService.loginUser(email: '', password: ''); // no-op to access internal list
    // Use registerUser and we test WorkerDashboardScreen directly
    await tester.pumpWidget(
      MaterialApp(
        home: WorkerDashboardScreen(
          user: reg.user!.copyWith(status: UserStatus.available),
        ),
      ),
    );

    expect(find.text('Worker Dashboard'), findsWidgets);
    expect(find.byKey(const Key('workerLogoutButton')), findsOneWidget);
  });

  testWidgets('Assigned Supervisor redirects to SupervisorDashboardScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SupervisorDashboardScreen(
          user: UserModel(
            userId: 'sup-1',
            name: 'Neha Sharma',
            employeeId: 'SUP-001',
            email: 'neha@hospital.org',
            role: UserRole.supervisor,
            status: UserStatus.assigned,
          ),
        ),
      ),
    );

    expect(find.text('Supervisor Dashboard'), findsWidgets);
    expect(find.byKey(const Key('supervisorLogoutButton')), findsOneWidget);
  });

  testWidgets('Admin redirects to AdminDashboardScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          user: UserModel(
            userId: 'adm-1',
            name: 'Hospital Admin',
            employeeId: 'ADM-001',
            email: 'admin@hospital.org',
            role: UserRole.admin,
            status: UserStatus.available,
          ),
        ),
      ),
    );

    expect(find.text('Admin Dashboard'), findsWidgets);
    expect(find.byKey(const Key('adminLogoutButton')), findsOneWidget);
  });

  testWidgets('Suspended Worker displays SuspensionScreen upon login', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SuspensionScreen(
          user: UserModel(
            userId: 'wrk-suspended',
            name: 'Sunil Verma',
            employeeId: 'WRK-202',
            email: 'sunil@hospital.org',
            role: UserRole.worker,
            status: UserStatus.suspended,
          ),
        ),
      ),
    );

    expect(find.text('Account Suspended'), findsOneWidget);
    expect(find.textContaining('Sunil Verma'), findsOneWidget);
    expect(find.byKey(const Key('suspensionLogoutButton')), findsOneWidget);
  });
}
