import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignup(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      authProvider.clearError();

      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: UserRole.user,
      );

      if (!mounted) return;

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please sign in.'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Signup failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSocialSignup({
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
          content: Text(authProvider.errorMessage ?? '$providerName sign-up failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Continue with $providerName in the browser to finish creating your account.'),
      ),
    );
  }

  Widget _socialTile({
    required String symbol,
    required Color color,
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
                      fontSize: symbol == 'f' ? 27 : 26,
                      fontWeight: FontWeight.w700,
                      color: color,
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
                ? const [Color(0xFF071526), Color(0xFF0D2743), Color(0xFF0A1E34)]
                : const [Color(0xFFFFF6ED), Color(0xFFFFF0DC), Color(0xFFFFFAF2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF123B67),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2A5D8C)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Container(
                          height: 74,
                          width: 74,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF97316).withValues(alpha: 0.34),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join our community and get started',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : const Color(0xFF7C4C18),
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
                          color: isDark ? const Color(0xFF294B6C) : const Color(0xFFFFD7B0),
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
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  icon: Icons.person_outline,
                                  controller: _nameController,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Name is required';
                                    if (value!.length < 3) return 'Name must be at least 3 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
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
                                  hintText: 'Create a strong password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _passwordController,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Password is required';
                                    if (value!.length < 6) return 'Password must be at least 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                CustomTextField(
                                  label: 'Confirm Password',
                                  hintText: 'Confirm your password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _confirmPasswordController,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Confirm password is required';
                                    if (value != _passwordController.text) return 'Passwords do not match';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) => PrimaryButton(
                              label: 'Create Account',
                              isLoading: authProvider.isLoading,
                              onPressed: () => _handleSignup(context),
                              color: const Color(0xFFE7771A),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF2F4E6B) : const Color(0xFFFFD7B0),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or register with',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF8B5E34),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF2F4E6B) : const Color(0xFFFFD7B0),
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
                                  symbol: 'G',
                                  color: const Color(0xFF1A73E8),
                                  isLoading: authProvider.isLoading,
                                  onTap: () => _handleSocialSignup(
                                    context: context,
                                    providerName: 'Google',
                                    action: authProvider.signInWithGoogle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                _socialTile(
                                  symbol: 'f',
                                  color: const Color(0xFF1877F2),
                                  isLoading: authProvider.isLoading,
                                  onTap: () => _handleSocialSignup(
                                    context: context,
                                    providerName: 'Facebook',
                                    action: authProvider.signInWithFacebook,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'By signing up, you agree to our Terms of Service and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : const Color(0xFF9C6B3C),
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF7C4C18),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Text(
                                  'Sign In',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
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
