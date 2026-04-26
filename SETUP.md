# Setup Guide

## Step 1: Supabase Configuration

### Create Supabase Project
1. Visit [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in or create account
4. Create a new project:
   - Name: "multirole-login" (or your choice)
   - Password: Create a strong password
   - Region: Select closest to you
5. Wait for project initialization (2-3 minutes)

### Get Credentials
1. In Supabase dashboard, go to **Settings > API**
2. Copy:
   - **Project URL** - looks like `https://xxxxx.supabase.co`
   - **anon public** key - long string starting with `eyJ...`

### Create Database Tables

1. In Supabase, click **SQL Editor** on the left
2. Click **New Query**
3. Copy and paste the SQL schema below
4. Click **Run**

```sql
-- Create profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Allow users to read their own profile
CREATE POLICY "Users can read own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Allow new user registration to insert profile
CREATE POLICY "Enable insert for auth users only" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Create a trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (new.id, new.email, '', 'user');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

## Step 2: Update App Configuration

1. Open `lib/main.dart`
2. Find the `main()` function
3. Replace the Supabase credentials:

```dart
await Supabase.initialize(
  url: 'YOUR_PROJECT_URL',    // Paste your Project URL here
  anonKey: 'YOUR_ANON_KEY',    // Paste your anon key here
);
```

Example:
```dart
await Supabase.initialize(
  url: 'https://abcdefghijk.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
);
```

## Step 3: Install Dependencies

```bash
cd "d:\Project\pp\new flutter"
flutter pub get
```

## Step 4: Run the App

### On Android
```bash
flutter run -d android
```

### On iOS
```bash
flutter run -d ios
```

### On Web
```bash
flutter run -d chrome
```

### Generic (auto-detects device)
```bash
flutter run
```

## Step 5: Create Test Accounts

You can create accounts through the app's signup screen, or:

1. Go to Supabase Dashboard
2. Click **Authentication** on the left
3. Click **Users** tab
4. Click **Add user**
5. Enter email, password, and click **Create user**

### Create Admin User

1. Create user via signup with role "Admin" OR
2. In Supabase SQL Editor, run:

```sql
UPDATE profiles SET role = 'admin' WHERE email = 'your-email@example.com';
```

## Step 6: Test the App

1. **Test Signup:**
   - Click "Create Account"
   - Select role (User or Admin)
   - Fill in details
   - Click "Create Account"

2. **Test Login:**
   - Use created account credentials
   - Verify correct dashboard loads:
     - Admin → Admin Dashboard
     - User → User Dashboard

3. **Test Features:**
   - Profile update
   - Password change
   - Logout
   - Login again

## Troubleshooting

### "Failed to initialize Supabase"
- Check credentials in `main.dart` are correct
- Ensure your Supabase project is active
- Check internet connection

### "Signup fails with validation error"
- Ensure database table was created correctly
- Check Supabase RLS policies are enabled
- Try disabling RLS temporarily to test

### "Login fails but signup works"
- Verify user exists in Supabase Auth
- Check profile table has corresponding row
- Check RLS policies allow SELECT

### "Can't reach Supabase"
- Verify your network connection
- Check firewall settings
- Ensure Supabase project status is "Healthy"
- Try new incognito window to clear cache

## Environment Variables (Optional)

For security, you can use environment variables:

1. Create `.env` file in project root
2. Add:
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
```

3. Add `flutter_dotenv` to `pubspec.yaml`
4. Update `main.dart`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  // ...
}
```

## Next Steps

1. Customize branding (colors, logos, fonts)
2. Add email verification
3. Implement 2FA
4. Add social login (Google, Apple)
5. Set up push notifications
6. Add offline support
7. Create user analytics

---

**Need Help?**
- Flutter Docs: https://flutter.dev
- Supabase Docs: https://supabase.com/docs
- Check Error Logs: `flutter run`
