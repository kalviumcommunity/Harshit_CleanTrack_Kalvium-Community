import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/pending_registrations_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/services/firestore_service.dart';
import 'package:cleantrack/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdmin = UserModel(
    userId: 'admin-001',
    name: 'Rajesh Kumar',
    employeeId: 'ADM-001',
    email: 'rajesh@cleantrack.org',
    role: UserRole.admin,
    status: UserStatus.available,
  );

  Widget createPendingScreen({UserModel? admin, bool seed = false}) {
    return MaterialApp(
      home: PendingRegistrationsScreen(
        adminUser: admin ?? testAdmin,
        seedInitialData: seed,
      ),
    );
  }

  setUp(() {
    FirestoreService().clearAllData();
    AuthService().clearUsers();
  });

  testWidgets('Renders Awaiting Activation AppBar, back button, notifications and admin avatar', (WidgetTester tester) async {
    await tester.pumpWidget(createPendingScreen());
    await tester.pumpAndSettle();

    expect(find.text('Awaiting Activation'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byKey(const Key('awaitingActivationBackButton')), findsOneWidget);
    expect(find.byKey(const Key('awaitingActivationNotificationButton')), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('Renders role toggle pills for Supervisor and Worker with initial Supervisor selected', (WidgetTester tester) async {
    await tester.pumpWidget(createPendingScreen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('roleToggleSupervisor')), findsOneWidget);
    expect(find.byKey(const Key('roleToggleWorker')), findsOneWidget);
    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);

    // Initial state: Supervisor selected, Worker unselected
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('Shows empty state when no pending users exist', (WidgetTester tester) async {
    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    expect(find.text('No Supervisors Pending Activation'), findsOneWidget);
    expect(find.text('All registered supervisors have been assigned to hospital wards.'), findsOneWidget);

    // Switch to Worker
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    expect(find.text('No Workers Pending Activation'), findsOneWidget);
    expect(find.text('All registered workers have been assigned to hospital wards.'), findsOneWidget);
  });

  testWidgets('Filters pending personnel by role toggle (Supervisor vs Worker)', (WidgetTester tester) async {
    final sup = UserModel(
      userId: 'sup-1',
      name: 'Neha Sharma',
      employeeId: 'SUP-012',
      email: 'neha@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );
    final wrk = UserModel(
      userId: 'wrk-1',
      name: 'Ravi Kumar',
      employeeId: 'WRK-125',
      email: 'ravi@hospital.org',
      role: UserRole.worker,
      status: UserStatus.pending,
    );

    FirestoreService().seedWorker(sup);
    FirestoreService().seedWorker(wrk);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // In Supervisor tab: Neha is visible, Ravi is not
    expect(find.text('Neha Sharma'), findsOneWidget);
    expect(find.text('ID: SUP-012'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);
    expect(find.text('ID: WRK-125'), findsNothing);

    // Switch to Worker tab
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    // In Worker tab: Ravi is visible, Neha is not
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('ID: WRK-125'), findsOneWidget);
    expect(find.text('Neha Sharma'), findsNothing);
  });

  testWidgets('User cards display ward dropdown and default ward', (WidgetTester tester) async {
    final sup = UserModel(
      userId: 'sup-1',
      name: 'Neha Sharma',
      employeeId: 'SUP-012',
      email: 'neha@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(sup);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    expect(find.text('Select Ward'), findsWidgets);
    expect(find.textContaining('ICU 1'), findsOneWidget);
    expect(find.byKey(const Key('assignWardButton_sup-1')), findsOneWidget);
    expect(find.text('ASSIGN WARD'), findsOneWidget);
  });

  testWidgets('Tapping ASSIGN WARD assigns supervisor to ward, activates to Assigned status, links supervisor to ward, and removes from pending list', (WidgetTester tester) async {
    final sup = UserModel(
      userId: 'sup-1',
      name: 'Neha Sharma',
      employeeId: 'SUP-012',
      email: 'neha@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(sup);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    expect(find.text('Neha Sharma'), findsOneWidget);

    // Tap ASSIGN WARD
    await tester.tap(find.byKey(const Key('assignWardButton_sup-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Success snackbar feedback
    expect(find.textContaining('Supervisor Neha Sharma assigned to'), findsOneWidget);

    // Removed from pending list, now empty state
    expect(find.text('Neha Sharma'), findsNothing);
    expect(find.text('No Supervisors Pending Activation'), findsOneWidget);

    // Verify supervisor status updated to Assigned
    final updatedSup = await FirestoreService().getUserProfile('sup-1');
    expect(updatedSup?.status, UserStatus.assigned);
    expect(updatedSup?.wardId, 'ward_icu_1');

    // Verify ward is linked to supervisor
    final ward = await FirestoreService().getWard('ward_icu_1');
    expect(ward?.supervisorId, 'sup-1');
  });

  testWidgets('Tapping ASSIGN WARD assigns worker to ward, activates to Available status, and removes from pending list', (WidgetTester tester) async {
    final wrk = UserModel(
      userId: 'wrk-1',
      name: 'Ravi Kumar',
      employeeId: 'WRK-125',
      email: 'ravi@hospital.org',
      role: UserRole.worker,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(wrk);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Switch to Worker
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);

    // Tap ASSIGN WARD
    await tester.tap(find.byKey(const Key('assignWardButton_wrk-1')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Success snackbar feedback
    expect(find.textContaining('Worker Ravi Kumar assigned to'), findsOneWidget);

    // Removed from pending list
    expect(find.text('Ravi Kumar'), findsNothing);
    expect(find.text('No Workers Pending Activation'), findsOneWidget);

    // Verify worker status updated to Available
    final updatedWrk = await FirestoreService().getUserProfile('wrk-1');
    expect(updatedWrk?.status, UserStatus.available);
    expect(updatedWrk?.wardId, 'ward_icu_1');
  });

  testWidgets('Tapping notification button opens Admin Notifications dialog', (WidgetTester tester) async {
    await tester.pumpWidget(createPendingScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('awaitingActivationNotificationButton')));
    await tester.pumpAndSettle();

    expect(find.text('Admin Notifications'), findsOneWidget);
    expect(find.text('Pending Registrations'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Admin Notifications'), findsNothing);
  });

  testWidgets('Tapping admin avatar opens PopupMenu with admin details and LOG OUT option', (WidgetTester tester) async {
    await tester.pumpWidget(createPendingScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adminLogoutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Rajesh Kumar'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);
  });

  testWidgets('Tapping REJECT shows confirmation dialog, and canceling retains the user', (WidgetTester tester) async {
    final sup = UserModel(
      userId: 'sup-1',
      name: 'Neha Sharma',
      employeeId: 'SUP-012',
      email: 'neha@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(sup);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    expect(find.text('Neha Sharma'), findsOneWidget);
    expect(find.byKey(const Key('rejectUserButton_sup-1')), findsOneWidget);

    // Tap REJECT
    await tester.tap(find.byKey(const Key('rejectUserButton_sup-1')));
    await tester.pumpAndSettle();

    expect(find.text('Reject Registration'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to reject Supervisor Neha Sharma'), findsOneWidget);

    // Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // User is still there
    expect(find.text('Neha Sharma'), findsOneWidget);
  });

  testWidgets('Tapping REJECT and confirming deletes user from database and UI', (WidgetTester tester) async {
    final wrk = UserModel(
      userId: 'wrk-1',
      name: 'Ravi Kumar',
      employeeId: 'WRK-125',
      email: 'ravi@hospital.org',
      role: UserRole.worker,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(wrk);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Switch to Worker
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    expect(find.text('Ravi Kumar'), findsOneWidget);

    // Tap REJECT
    await tester.tap(find.byKey(const Key('rejectUserButton_wrk-1')));
    await tester.pumpAndSettle();

    // Tap Reject & Delete in dialog
    await tester.tap(find.byKey(const Key('confirmRejectDialogButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Feedback shown
    expect(find.textContaining('Registration for Worker Ravi Kumar was rejected and removed.'), findsOneWidget);

    // Removed from UI
    expect(find.text('Ravi Kumar'), findsNothing);
    expect(find.text('No Workers Pending Activation'), findsOneWidget);

    // Verify deleted in database
    final deletedUser = await FirestoreService().getUserProfile('wrk-1');
    expect(deletedUser, isNull);
  });
}
