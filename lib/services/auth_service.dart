import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        _authStateController.add(AuthState(session: session != null));
      });
    } catch (_) {}
  }

  final SupabaseService _sb = SupabaseService.instance;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  static const String _avatarBucket = 'avatars';
  static const String _mobileRedirectUrl =
      'io.supabase.multirolelogin://login-callback/';

  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final res = await _sb.signUp(
      email,
      password,
      data: {
        'full_name': fullName,
        'role': role == UserRole.admin ? 'admin' : 'user',
      },
    );

    if (res.user != null) {
      await _syncProfile(
        user: res.user!,
        fullName: fullName,
        role: role,
        markLastLogin: res.session != null,
      );
    }

    if (res.user != null && res.session != null) {
      final profile = await _fetchProfile(res.user!.id);
      return profile ?? _fallbackAppUser(res.user!, fullName: fullName, role: role);
    }

    return res.user == null
        ? null
        : _fallbackAppUser(res.user!, fullName: fullName, role: role);
  }

  Future<AppUser?> signIn({required String email, required String password}) async {
    final res = await _sb.signIn(email, password);
    if (res.session != null && res.user != null) {
      final userId = res.user!.id;
      AppUser? profile;
      try {
        await _syncProfile(
          user: res.user!,
          fullName: _profileNameFor(res.user!),
          role: _roleFromMetadata(res.user!),
          markLastLogin: true,
        );
        profile = await _fetchProfile(userId);
      } catch (_) {}
      return profile ?? _fallbackAppUser(res.user!);
    }
    return null;
  }

  Future<void> signInWithGoogle() async {
    await signInWithOAuth(provider: OAuthProvider.google);
  }

  Future<void> signInWithFacebook() async {
    await signInWithOAuth(provider: OAuthProvider.facebook);
  }

  Future<void> signInWithOAuth({required OAuthProvider provider}) async {
    final launched = await _sb.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : _mobileRedirectUrl,
    );

    if (!launched) {
      throw Exception('Unable to start ${_providerLabel(provider)} sign-in.');
    }
  }

  Future<void> signOut() async {
    await _sb.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await _sb.resetPassword(email);
  }

  Future<AppUser?> getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    AppUser? profile;
    try {
      await _syncProfile(
        user: user,
        fullName: _profileNameFor(user),
        role: _roleFromMetadata(user),
        markLastLogin: true,
      );
      profile = await _fetchProfile(user.id);
    } catch (_) {}

    return profile ?? _fallbackAppUser(user);
  }

  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    final values = <String, dynamic>{'full_name': fullName};
    if (avatarUrl != null) {
      values['avatar_url'] = avatarUrl;
    }
    await _sb.update('profiles', values, 'id', userId);
  }

  Future<String> uploadProfileAvatar({
    required String userId,
    required Uint8List bytes,
    String fileExtension = 'png',
  }) async {
    final normalizedExtension = fileExtension.toLowerCase().replaceAll('.', '');
    final path = 'profiles/$userId/avatar.$normalizedExtension';
    final currentProfile = await _fetchProfile(userId);
    final previousPath = _extractStoragePath(
      currentProfile?.avatarUrl,
      bucket: _avatarBucket,
    );

    if (previousPath != null && previousPath != path) {
      try {
        await _sb.removeFromBucket(bucket: _avatarBucket, path: previousPath);
      } catch (_) {}
    }

    final publicUrl = await _sb.uploadToBucket(
      bucket: _avatarBucket,
      path: path,
      bytes: bytes,
      contentType: _contentTypeForExtension(normalizedExtension),
    );

    await _sb.update(
      'profiles',
      {'avatar_url': publicUrl},
      'id',
      userId,
    );

    return publicUrl;
  }

  Future<void> removeProfileAvatar({required String userId}) async {
    final currentProfile = await _fetchProfile(userId);
    final storagePath = _extractStoragePath(
      currentProfile?.avatarUrl,
      bucket: _avatarBucket,
    );

    if (storagePath != null) {
      try {
        await _sb.removeFromBucket(bucket: _avatarBucket, path: storagePath);
      } catch (_) {}
    }

    await _sb.update(
      'profiles',
      {'avatar_url': null},
      'id',
      userId,
    );
  }

  Future<void> changePassword({required String newPassword}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
    } catch (_) {
      throw Exception('Unable to change password via client; use reset password flow');
    }
  }

  Stream<AuthState> get authStateChanges => _authStateController.stream;

  Future<void> _syncProfile({
    required User user,
    String? fullName,
    UserRole role = UserRole.user,
    bool markLastLogin = false,
  }) async {
    final existingProfile = await _fetchProfile(user.id);
    final now = DateTime.now().toIso8601String();
    final values = <String, dynamic>{
      'id': user.id,
      'email': user.email ?? '',
      'full_name': (fullName ?? existingProfile?.fullName ?? '').trim(),
      'role': ((existingProfile?.role ?? role) == UserRole.admin) ? 'admin' : 'user',
      'created_at': existingProfile?.createdAt.toIso8601String() ?? now,
      'avatar_url': existingProfile?.avatarUrl,
    };

    if (markLastLogin) {
      values['last_login'] = now;
    } else if (existingProfile?.lastLogin != null) {
      values['last_login'] = existingProfile!.lastLogin!.toIso8601String();
    }

    await _sb.upsert('profiles', values);
  }

  Future<AppUser?> _fetchProfile(String userId) async {
    final result = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (result == null) return null;
    final Map<String, dynamic> data = Map<String, dynamic>.from(result as Map);
    return AppUser.fromJson(data);
  }

  AppUser _fallbackAppUser(
    User user, {
    String? fullName,
    UserRole? role,
  }) {
    final metadataFullName = _profileNameFor(user);
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      fullName: (fullName ?? metadataFullName ?? '').trim(),
      avatarUrl: user.userMetadata?['avatar_url']?.toString(),
      role: role ?? _roleFromMetadata(user),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      lastLogin: null,
    );
  }

  UserRole _roleFromMetadata(User user) {
    return user.userMetadata?['role']?.toString() == 'admin'
        ? UserRole.admin
        : UserRole.user;
  }

  String? _profileNameFor(User user) {
    final metadata = user.userMetadata;
    return metadata?['full_name']?.toString() ??
        metadata?['name']?.toString() ??
        metadata?['display_name']?.toString();
  }

  String _providerLabel(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return 'Google';
      case OAuthProvider.facebook:
        return 'Facebook';
      default:
        return provider.name;
    }
  }

  String? _extractStoragePath(String? publicUrl, {required String bucket}) {
    if (publicUrl == null || publicUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(publicUrl);
    if (uri == null) {
      return null;
    }

    final publicIndex = uri.pathSegments.indexOf('public');
    if (publicIndex == -1 || publicIndex + 1 >= uri.pathSegments.length) {
      return null;
    }

    if (uri.pathSegments[publicIndex + 1] != bucket) {
      return null;
    }

    final path = uri.pathSegments.skip(publicIndex + 2).join('/');
    return path.isEmpty ? null : path;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }
}

class AuthState {
  final bool session;

  AuthState({required this.session});
}



