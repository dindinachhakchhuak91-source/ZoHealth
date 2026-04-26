# Supabase setup (step-by-step)

This guide shows how to connect this Flutter app to Supabase and enable the features you asked for:
- permanent deletes for content (admin + user views)
- permanent storage of ad images until admin deletes them
- working "forgot password" email flow

Prerequisites
- A Supabase account (https://app.supabase.com)
- SMTP configured for your Supabase project (for password reset emails)

1) Create a Supabase project
- Create a new project and copy the Project URL and anon/public API key.

2) Configure environment in your Flutter app
- In development, you can keep values in a file or use runtime env. Example (store in code for now):

  - SUPABASE_URL = your-project-url
  - SUPABASE_ANON_KEY = your-anon-key

3) Initialize Supabase in `main.dart`

  - Call SupabaseService.instance.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY) early (before runApp).

Example:

```dart
import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  runApp(MyApp());
}
```

4) Create database tables (SQL)

Run these in the Supabase SQL editor to create minimal tables used by the app:

```sql
-- Users profile table (store extra fields)
create table if not exists users (
  id uuid primary key,
  email text,
  full_name text,
  avatar_url text,
  role text default 'user',
  created_at timestamptz default now(),
  last_login timestamptz
);

-- Slides
create table if not exists slides (
  id text primary key,
  title text,
  subtitle text,
  image_url text,
  created_at timestamptz default now()
);

-- Section content
create table if not exists section_content (
  id text primary key,
  section_id text,
  title text,
  description text,
  bullet_points jsonb,
  background_color text,
  created_at timestamptz default now()
);

-- Ads metadata (images stored in storage bucket)
create table if not exists ads (
  id text primary key,
  title text,
  description text,
  image_path text,
  image_url text,
  created_at timestamptz default now()
);
```

5) Storage bucket
- Create a bucket named `ads` (or another name) in the Supabase Storage UI.
- Set bucket public if you want public image URLs. If private, you'll need signed URLs.

6) Email / SMTP for password reset
- In Supabase Project Settings → Auth → SMTP, configure SMTP so Supabase can send password reset emails.
- In Auth settings, allow email signups and enable "Reset password" templates.

7) Row Level Security (RLS) & Policies
- For production, enable RLS and add policies that allow:
  - Public read on `slides`, `section_content`, `ads` (or via a view)
  - Authenticated users can read their `users` profile
  - Admin role can insert/update/delete content (create policies that check `auth.role` or a custom claim)

8) App changes (how things work now)
- Authentication: `AuthService` now uses Supabase for signup, signin, signout, and password reset.
- Password reset: call `AuthService.resetPassword(email: '...')` — Supabase sends reset link to the user's email.
- Slides / content: `ContentProvider` functions should call Supabase database endpoints. (See code comments in provider.)
- Ads images: upload images with `SupabaseService.uploadToBucket(bucket: 'ads', path: 'ads/yourfile.jpg', bytes: bytes)`; the returned public URL is stored in `ads.image_url`.
- Deleting content: delete the DB row (e.g., `DELETE FROM slides WHERE id=...`) and if it has a storage file path, call `SupabaseService.removeFromBucket(bucket: 'ads', path: 'ads/yourfile.jpg')` to remove the file.

9) Example: upload an ad image and create ad row

```dart
// bytes from picked image
final publicUrl = await SupabaseService.instance.uploadToBucket(
  bucket: 'ads',
  path: 'ads/${DateTime.now().millisecondsSinceEpoch}.jpg',
  bytes: fileBytes,
  upsert: false,
);

await SupabaseService.instance.insert('ads', {
  'id': 'ad_${DateTime.now().millisecondsSinceEpoch}',
  'title': 'My Ad',
  'description': 'desc',
  'image_path': 'ads/12345.jpg',
  'image_url': publicUrl,
});
```

10) Example: delete ad permanently (admin action)

```dart
// remove DB row
await SupabaseService.instance.delete('ads', 'id', adId);
// remove storage file
await SupabaseService.instance.removeFromBucket(bucket: 'ads', path: imagePath);
```

11) Local testing notes
- Run `flutter pub get` (supabase_flutter is already in `pubspec.yaml`).
- Make sure `main.dart` calls the Supabase initialize method before `runApp`.

12) Next steps you might want me to do for you
- Migrate `ContentProvider` to fetch and mutate data from Supabase (I can implement CRUD methods).
- Wire the ad upload UI to call `SupabaseService.uploadToBucket` and store the URL in `ads` table.
- Add admin-only UI and minimal RLS policies.

If you want, I can implement the ContentProvider migrations and wire the ad upload + delete flows next.
