import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleantrack/screens/pending_registrations_screen.dart';
import 'package:cleantrack/models/user_model.dart';
import 'package:cleantrack/models/ward_model.dart';
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
    expect(find.text('RK'), findsOneWidget);
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

  testWidgets('User cards display ward dropdown with default Select Ward text', (WidgetTester tester) async {
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

    // Initial dropdown shows default hint "Select Ward" without pre-selecting a ward
    expect(find.text('Select Ward'), findsWidgets);
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

    // Open dropdown and select ICU 1
    await tester.tap(find.byKey(const Key('wardDropdown_sup-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ICU 1').last);
    await tester.pumpAndSettle();

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
    // Seed a ward with an assigned supervisor
    final supWard = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-existing',
    );
    FirestoreService().seedWard(supWard);

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

    // Open dropdown and select ICU 1 (which has an assigned supervisor)
    await tester.tap(find.byKey(const Key('wardDropdown_wrk-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ICU 1').last);
    await tester.pumpAndSettle();

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

  testWidgets('Dropdown for supervisor ONLY displays wards not assigned to any supervisor', (WidgetTester tester) async {
    // Seed Ward ICU 1 with an existing supervisor
    final assignedWard = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-existing',
    );
    FirestoreService().seedWard(assignedWard);

    // Seed pending supervisor
    final sup = UserModel(
      userId: 'sup-2',
      name: 'Priya Verma',
      employeeId: 'SUP-020',
      email: 'priya@hospital.org',
      role: UserRole.supervisor,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(sup);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Verify default hint text 'Select Ward' is shown initially without opening dropdown
    expect(find.text('Select Ward'), findsWidgets);

    // Open dropdown
    await tester.tap(find.byKey(const Key('wardDropdown_sup-2')));
    await tester.pumpAndSettle();

    // ICU 1 must NOT appear anywhere in the dropdown menu items
    expect(find.text('ICU 1'), findsNothing);
    // Other unassigned wards must be present
    expect(find.text('ICU 2'), findsWidgets);
    expect(find.text('Minor OT'), findsWidgets);

    // Dismiss dropdown
    await tester.tap(find.text('ICU 2').last);
    await tester.pumpAndSettle();
  });

  testWidgets('Dropdown for worker ONLY includes wards that have an assigned supervisor', (WidgetTester tester) async {
    // Seed Ward ICU 1 with an existing supervisor
    final assignedWard = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-existing',
    );
    FirestoreService().seedWard(assignedWard);
    // Other wards (ICU 2, Minor OT, etc.) have NO supervisor

    // Seed pending worker
    final wrk = UserModel(
      userId: 'wrk-2',
      name: 'Sunil Sen',
      employeeId: 'WRK-202',
      email: 'sunil@hospital.org',
      role: UserRole.worker,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(wrk);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Switch to Worker tab
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    // Default hint is 'Select Ward'
    expect(find.text('Select Ward'), findsWidgets);
    expect(find.byKey(const Key('wardDropdown_wrk-2')), findsOneWidget);

    // Open dropdown
    await tester.tap(find.byKey(const Key('wardDropdown_wrk-2')));
    await tester.pumpAndSettle();

    // For worker, ICU 1 IS available because it has a supervisor
    expect(find.text('ICU 1'), findsWidgets);
    // Unassigned wards like ICU 2 must NOT appear for worker
    expect(find.text('ICU 2'), findsNothing);
  });

  testWidgets('Dropdown for worker displays worker counts already assigned to wards aligned at end', (WidgetTester tester) async {
    // Seed ICU 1 (with supervisor and 2 workers)
    final w1 = UserModel(
      userId: 'wrk-active-1',
      name: 'Amit Kumar',
      employeeId: 'WRK-001',
      email: 'amit@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu_1',
      wardName: 'ICU 1',
      status: UserStatus.available,
    );
    final w2 = UserModel(
      userId: 'wrk-active-2',
      name: 'Sunita Devi',
      employeeId: 'WRK-002',
      email: 'sunita@hospital.org',
      role: UserRole.worker,
      wardId: 'ward_icu_1',
      wardName: 'ICU 1',
      status: UserStatus.available,
    );
    FirestoreService().seedWorker(w1);
    FirestoreService().seedWorker(w2);
    final ward1 = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-1',
    );
    // Seed OT 1 with supervisor but 0 workers
    final ward2 = WardModel(
      wardId: 'ward_ot_1',
      name: 'OT 1',
      supervisorId: 'sup-2',
    );
    FirestoreService().seedWard(ward1);
    FirestoreService().seedWard(ward2);

    // Seed pending worker
    final pendingWrk = UserModel(
      userId: 'wrk-new',
      name: 'Manish Singh',
      employeeId: 'WRK-099',
      email: 'manish@hospital.org',
      role: UserRole.worker,
      status: UserStatus.pending,
    );
    FirestoreService().seedWorker(pendingWrk);

    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Switch to Worker tab
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    // Open dropdown
    await tester.tap(find.byKey(const Key('wardDropdown_wrk-new')));
    await tester.pumpAndSettle();

    // The dropdown displays "2 Workers" for ICU 1 and "0 Workers" for OT 1
    expect(find.text('2 Workers'), findsWidgets);
    expect(find.text('0 Workers'), findsWidgets);
  });

  testWidgets('No hardcoded demo pending users are automatically seeded on launch', (WidgetTester tester) async {
    // Launch screen without manual seeding
    await tester.pumpWidget(createPendingScreen(seed: false));
    await tester.pumpAndSettle();

    // Empty state should be visible for supervisor tab
    expect(find.text('No Supervisors Pending Activation'), findsOneWidget);
    expect(find.text('Neha Sharma'), findsNothing);

    // Switch to worker tab
    await tester.tap(find.byKey(const Key('roleToggleWorker')));
    await tester.pumpAndSettle();

    // Empty state should be visible for worker tab
    expect(find.text('No Workers Pending Activation'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsNothing);
    expect(find.text('Vikram Patel'), findsNothing);
  });

  testWidgets('Backend rejects direct assignUserToWard assigning a second supervisor to an already assigned ward', (WidgetTester tester) async {
    // Ward ICU 1 already has supervisor sup-1
    final ward = WardModel(
      wardId: 'ward_icu_1',
      name: 'ICU 1',
      supervisorId: 'sup-1',
    );
    FirestoreService().seedWard(ward);

    // Attempt direct backend call assigning second supervisor sup-2 to ward_icu_1
    final result = await FirestoreService().assignUserToWard(
      userId: 'sup-2',
      wardId: 'ward_icu_1',
      role: UserRole.supervisor,
    );

    // Backend must reject the attempt
    expect(result, isFalse);

    // Ward supervisor must remain sup-1
    final verifiedWard = await FirestoreService().getWard('ward_icu_1');
    expect(verifiedWard?.supervisorId, 'sup-1');
  });

  testWidgets('Backend rejects direct assignUserToWard assigning a worker to an unassigned ward without a supervisor', (WidgetTester tester) async {
    // Ward ICU 2 has NO supervisor
    final unassignedWard = WardModel(
      wardId: 'ward_icu_2',
      name: 'ICU 2',
      supervisorId: null,
    );
    FirestoreService().seedWard(unassignedWard);

    // Attempt direct backend call assigning worker wrk-1 to unassigned ward_icu_2
    final result = await FirestoreService().assignUserToWard(
      userId: 'wrk-1',
      wardId: 'ward_icu_2',
      role: UserRole.worker,
    );

    // Backend must reject the attempt
    expect(result, isFalse);
  });
}

