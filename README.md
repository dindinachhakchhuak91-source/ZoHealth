# MultiRole Login System - Flutter

A complete Flutter application featuring a multi-role login system with Admin and User roles, built with Supabase backend and modern UI/UX design.

## 🎯 Features

### Authentication
- **Email/Password Authentication** - Secure login and signup
- **Multi-Role System** - Admin and User roles with different dashboards
- **Session Management** - Automatic session handling with Supabase
- **Profile Management** - Update profile and change password
- **Password Validation** - Strong security requirements

### Admin Dashboard
- **System Overview** - View total users, active users, tasks, and revenue metrics
- **User Management** - Manage and monitor user accounts
- **Reports** - Access daily activity, performance, and engagement reports
- **Settings** - Configure permissions and system settings

### User Dashboard
- **Activity Tracking** - View tasks, completion rate, and pending items
- **Quick Actions** - Easy access to common tasks
- **Profile Management** - Update personal information
- **Responsive Design** - Works seamlessly on all screen sizes

### UI/UX Design
- **Beautiful Modern Interface** - Clean, professional design using Material Design 3
- **Custom Components** - Reusable widgets for authentication
- **Smooth Animations** - Fluid transitions and interactions
- **Dark Mode Ready** - Foundation for easy dark mode implementation
- **Google Fonts** - Premium typography throughout the app

## 📋 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── user_model.dart      # User data model and enums
├── services/
│   └── auth_service.dart    # Supabase authentication service
├── providers/
│   └── auth_provider.dart   # State management with Provider
├── screens/
│   ├── login_screen.dart    # Login UI
│   ├── signup_screen.dart   # Signup UI with role selection
│   ├── user_dashboard.dart  # User dashboard
│   ├── admin_dashboard.dart # Admin dashboard
│   └── profile_screen.dart  # Profile management
└── widgets/
    └── auth_widgets.dart    # Reusable authentication components
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.0 or higher
- Dart 3.0 or higher
- Supabase account (free tier available)
- VS Code or Android Studio

### 1. Clone or Setup Project

```bash
cd "d:\Project\pp\new flutter"
flutter pub get
```

### 2. Setup Supabase

1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Get your **Project URL** and **Anonymous Key**
4. Create the following database tables:

#### Profiles Table Schema
```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  full_name TEXT NOT NULL,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE,
  UNIQUE(email)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for users to read their own profile
CREATE POLICY "Users can read own profile"
  ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Create policy for users to update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id);
```

### 3. Update Supabase Credentials

In `lib/main.dart`, replace the placeholders:

```dart
await Supabase.initialize(
  url: 'YOUR_PROJECT_URL',  // Replace with your Supabase URL
  anonKey: 'YOUR_ANON_KEY',  // Replace with your Anonymous Key
);
```

### 4. Run the App

```bash
flutter run
```

## 🔐 Default Test Accounts

You can create test accounts in Supabase Auth:

**Admin Account:**
- Email: `admin@example.com`
- Password: `Admin123!`
- Role: Admin

**User Account:**
- Email: `user@example.com`
- Password: `User123!`
- Role: User

## 🎨 UI Components

### Custom Widgets
- **CustomTextField** - Styled text input with validation and password visibility toggle
- **PrimaryButton** - Main action buttons with loading state
- **SecondaryButton** - Secondary action buttons
- **RoleSelector** - Interactive role selection component

### Design System
- **Color Scheme** - Blue for primary actions, Orange for admin, Green for success
- **Typography** - Google Fonts (Poppins) for modern look
- **Spacing** - Consistent padding and margins throughout
- **Icons** - Material Icons and custom SVGs
- **Shadows & Borders** - Subtle effects for better hierarchy

## 📱 Responsive Design

The app is fully responsive and optimized for:
- Mobile phones (portrait and landscape)
- Tablets
- Desktop (web version)

## 🔄 State Management

Uses **Provider** package for:
- Authentication state management
- User data caching
- Loading states
- Error handling

## 🛠️ Dependencies

- **supabase_flutter** - Backend and authentication
- **provider** - State management
- **google_fonts** - Typography
- **cached_network_image** - Image caching
- **shared_preferences** - Local storage
- **ionicons** - Icon library

## 📖 API Reference

### AuthProvider Methods

```dart
// Sign up new user
Future<bool> signUp({
  required String email,
  required String password,
  required String fullName,
  required UserRole role,
})

// Sign in existing user
Future<bool> signIn({
  required String email,
  required String password,
})

// Sign out
Future<void> signOut()

// Update profile
Future<bool> updateProfile({
  required String fullName,
  String? avatarUrl,
})

// Change password
Future<bool> changePassword({
  required String newPassword,
})
```

## 🔒 Security Features

- ✅ Password validation and strength checking
- ✅ Row-level security in Supabase
- ✅ Automatic session handling
- ✅ Secure token storage
- ✅ Email verification ready
- ✅ Protected routes based on role

## 🚀 Future Enhancements

- Email verification
- Two-factor authentication (2FA)
- Social login (Google, Apple)
- Dark mode theme
- Push notifications
- Offline support with local sync
- User activity logs
- Advanced analytics

## 📝 License

This project is open source and available under the MIT License.

## 📞 Support

For issues or questions:
1. Check Supabase documentation: https://supabase.com/docs
2. Check Flutter documentation: https://flutter.dev/docs
3. Review the code comments and examples

---

**Happy Coding! 🎉**

Built with ❤️ using Flutter and Supabase
