import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'MultiRole Login';
  static const String appVersion = '1.0.0';

  // API
  static const String supabaseUrl = 'https://YOUR_SUPABASE_URL.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Validation
  static const int minPasswordLength = 6;
  static const int minNameLength = 3;
  static const String emailRegex = r'^[^@]+@[^@]+\.[^@]+';

  // Timeout Durations
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration snackbarDuration = Duration(seconds: 3);

  // Asset Paths
  static const String logoPath = 'assets/logo.png';

  // Size Constants
  static const double borderRadius = 12.0;
  static const double defaultPadding = 24.0;
  static const double defaultSpacing = 16.0;

  // Animation Durations
  static const Duration animationDuration = Duration(milliseconds: 300);
}

class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryOrange = Color(0xFFF97316);
  static const Color primaryGreen = Color(0xFF10B981);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF6B7280);

  // Background Colors
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color bgDark = Color(0xFF1F2937);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFB923C);
  static const Color info = Color(0xFF3B82F6);
}

class AppStrings {
  // Auth Strings
  static const String welcomeBack = 'Welcome Back';
  static const String signInMessage = 'Sign in to your account to continue';
  static const String createAccount = 'Create Account';
  static const String joinCommunity = 'Join our community and get started';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String alreadyHaveAccount = 'Already have an account? ';

  // Form Labels
  static const String email = 'Email Address';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String selectRole = 'Select Role';

  // Buttons
  static const String signIn = 'Sign In';
  static const String signUp = 'Create Account';
  static const String signOut = 'Sign Out';
  static const String save = 'Save';
  static const String cancel = 'Cancel';

  // Error Messages
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Enter a valid email';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String nameTooShort = 'Name must be at least 3 characters';

  // Success Messages
  static const String signUpSuccess =
      'Account created successfully! Please sign in.';
  static const String profileUpdated = 'Profile updated successfully';
  static const String passwordChanged = 'Password changed successfully';
}
