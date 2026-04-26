import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      authProvider.clearError();

      final success = await authProvider.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (!success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSocialLogin({
    required BuildContext context,
    required String providerName,
    required Future<bool> Function() action,
  }) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    authProvider.clearError();
    final success = await action();

    if (!mounted) return;

    if (!success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? '$providerName sign-in failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Continue with $providerName in the browser to finish signing in.'),
      ),
    );
  }

  Widget _socialTile({
    required String label,
    required String symbol,
    required Color symbolColor,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF102944) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF33597A) : const Color(0xFFD7E3F0),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    symbol,
                    style: GoogleFonts.poppins(
                      fontSize: label == 'Facebook' ? 27 : 26,
                      fontWeight: FontWeight.w700,
                      color: symbolColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF061425), Color(0xFF0D2743), Color(0xFF0A1E34)]
                : const [Color(0xFFF0F7FF), Color(0xFFE4F0FF), Color(0xFFF7FAFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          height: 92,
                          width: 92,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C7D6).withValues(alpha: 0.28),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/icon/carepulse_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome Back',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF102A43),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your health journey',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : const Color(0xFF486581),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF294B6C) : const Color(0xFFD5E3F2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                CustomTextField(
                                  label: 'Email Address',
                                  hintText: 'Enter your email',
                                  icon: Icons.email_outlined,
                                  controller: _emailController,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Email is required';
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                CustomTextField(
                                  label: 'Password',
                                  hintText: 'Enter your password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _passwordController,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Password is required';
                                    if (value!.length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () async {
                                      final authProvider = context.read<AuthProvider>();
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      final emailController = TextEditingController(
                                        text: _emailController.text.trim(),
                                      );
                                      final result = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Reset Password'),
                                          content: TextField(
                                            controller: emailController,
                                            decoration: const InputDecoration(labelText: 'Email'),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('Send'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (result == true) {
                                        final email = emailController.text.trim();
                                        final success = await authProvider.resetPassword(email: email);
                                        if (!mounted) return;
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Password reset sent to $email'
                                                  : (authProvider.errorMessage ?? 'Failed to send reset'),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF38BDF8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) => PrimaryButton(
                              label: 'Log In',
                              isLoading: authProvider.isLoading,
                              onPressed: () => _handleLogin(context),
                              color: const Color(0xFF1D6FB8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF486581),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                                  );
                                },
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF38BDF8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF2F4E6B) : const Color(0xFFD2E2F0),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF627D98),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF2F4E6B) : const Color(0xFFD2E2F0),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _socialTile(
                                  label: 'Google',
                                  symbol: 'G',
                                  symbolColor: const Color(0xFF1A73E8),
                                  isLoading: authProvider.isLoading,
                                  onTap: () => _handleSocialLogin(
                                    context: context,
                                    providerName: 'Google',
                                    action: authProvider.signInWithGoogle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                _socialTile(
                                  label: 'Facebook',
                                  symbol: 'f',
                                  symbolColor: const Color(0xFF1877F2),
                                  isLoading: authProvider.isLoading,
                                  onTap: () => _handleSocialLogin(
                                    context: context,
                                    providerName: 'Facebook',
                                    action: authProvider.signInWithFacebook,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

