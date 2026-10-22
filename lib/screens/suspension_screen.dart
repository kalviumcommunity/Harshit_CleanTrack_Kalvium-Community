import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';

class SuspensionScreen extends StatefulWidget {
  final UserModel? user;
  final String? suspensionReason;
  final VoidCallback? onSuspensionRevoked;

  const SuspensionScreen({
    super.key,
    this.user,
    this.suspensionReason,
    this.onSuspensionRevoked,
  });

  @override
  State<SuspensionScreen> createState() => _SuspensionScreenState();
}

class _SuspensionScreenState extends State<SuspensionScreen> {
  Timer? _autoRevokeTimer;
  bool _hasRevoked = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoRevoke();
  }

  @override
  void dispose() {
    _autoRevokeTimer?.cancel();
    super.dispose();
  }

  DateTime _getEffectiveUntil() {
    return widget.user?.suspendedUntil ?? DateTime.now().add(const Duration(days: 1));
  }

  void _scheduleAutoRevoke() {
    _autoRevokeTimer?.cancel();
    final until = _getEffectiveUntil();
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      _handleAutoRevoke();
    } else {
      _autoRevokeTimer = Timer(remaining, () {
        if (mounted) {
          _handleAutoRevoke();
        }
      });
    }
  }

  Future<void> _handleAutoRevoke() async {
    if (_hasRevoked) return;
    _hasRevoked = true;
    final workerId = widget.user?.userId;
    if (workerId != null && workerId.isNotEmpty) {
      await FirestoreService().reinstateWorker(workerId);
    }
    if (mounted && widget.onSuspensionRevoked != null) {
      widget.onSuspensionRevoked!();
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$month ${dt.day}, ${dt.year} at $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUntil = _getEffectiveUntil();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  const AppLogo(size: 64, iconSize: 36),
                  const SizedBox(height: 16),
                  const Text(
                    'CleanTrack',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hospital Housekeeping Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Suspension Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block,
                            color: Colors.red.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Account Suspended',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.user?.name.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.user!.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 24),

                        // When will the worker get dashboard access back (Key: suspensionDurationBox)
                        Container(
                          key: const Key('suspensionDurationBox'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Access will be restored on:\n${_formatDateTime(effectiveUntil)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('suspensionLogoutButton'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () async {
                              await AuthService().signOut();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              'BACK TO LOGIN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
