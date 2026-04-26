import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/content_provider.dart';
import 'providers/theme_provider.dart';
import 'config/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'services/supabase_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase (set anon key in lib/config/supabase_config.dart)
  try {
    await SupabaseService.instance.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    // Initialization failure is non-fatal for now — app can still run with mocked flows.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ContentProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) => MaterialApp(
            title: 'CarePulse',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Not authenticated - show login screen
          if (!authProvider.isAuthenticated) {
            return const LoginScreen();
          }

          // Authenticated - check role and show appropriate dashboard
          if (authProvider.isAdmin) {
            return const AdminDashboard();
          } else {
            return const UserDashboard();
          }
        },
      );
}




