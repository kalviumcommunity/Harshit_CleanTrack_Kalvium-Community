import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';

class PendingVerificationScreen extends StatelessWidget {
  final bool isNewlyRegistered;

  const PendingVerificationScreen({
    super.key,
    this.isNewlyRegistered = false,
  });

  @override
  Widget build(BuildContext context) {
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
                  // Logo Emblem
                  const AppLogo(
                    size: 64,
                    iconSize: 36,
                  ),
                  const SizedBox(height: 16),

                  // Brand Title
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

                  // Brand Subtitle
                  const Text(
                    'Hospital Housekeeping Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Success / Verification Status Card (Exact match to design)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 38,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isNewlyRegistered) ...[
                          const Text(
                            'Registration successful',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Dashboard access will become available after an administrator verifies your identity.',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('backToLoginButton'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
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
