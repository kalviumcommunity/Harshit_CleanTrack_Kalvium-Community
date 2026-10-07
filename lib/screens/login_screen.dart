import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import 'admin_dashboard_screen.dart';
import 'pending_verification_screen.dart';
import 'register_screen.dart';
import 'supervisor_dashboard_screen.dart';
import 'suspension_screen.dart';
import 'worker_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.loginUser(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (!result.isSuccess || result.user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = result.errorMessage ?? 'Invalid email or password.';
        });
        return;
      }

      final user = result.user!;
      Widget destination;

      // PRD Redirection Flow
      if (user.role == UserRole.admin) {
        destination = AdminDashboardScreen(user: user);
      } else if (user.role == UserRole.supervisor) {
        if (user.status == UserStatus.pending) {
          destination = const PendingVerificationScreen();
        } else {
          destination = SupervisorDashboardScreen(user: user);
        }
      } else {
        // Worker Role
        if (user.status == UserStatus.suspended) {
          destination = SuspensionScreen(user: user);
        } else if (user.status == UserStatus.pending) {
          destination = const PendingVerificationScreen();
        } else {
          destination = WorkerDashboardScreen(user: user);
        }
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF0F172A),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

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
                  // App Branding Header
                  const AppLogo(
                    size: 64,
                    iconSize: 36,
                  ),
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

                  // Login Card Container
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
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Title
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Log in to your account',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Top Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              key: const Key('loginErrorBanner'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Email Field
                          _buildFieldLabel('Email'),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const Key('loginEmailField'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              hintText: 'name@hospital.org',
                              prefixIcon: const Icon(
                                Icons.mail_outline,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ),
                            validator: AuthService.validateEmail,
                          ),
                          const SizedBox(height: 18),

                          // Password Field
                          _buildFieldLabel('Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const Key('loginPasswordField'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF94A3B8),
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                key: const Key('loginPasswordVisibilityToggle'),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 26),

                          // Login Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              key: const Key('loginSubmitButton'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'LOGIN',
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
                  ),
                  const SizedBox(height: 28),

                  // Bottom Navigation Link to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        key: const Key('goToRegisterButton'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'REGISTER',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
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
