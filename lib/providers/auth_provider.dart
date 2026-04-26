import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _initializeAuth();
    _restoreExistingSession();
  }
  final AuthService _authService = AuthService();
  static const String _avatarPreferencePrefix = 'profile_avatar_path_';

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  void _initializeAuth() {
    _authService.authStateChanges.listen((state) {
      if (state.session) {
        _loadCurrentUser(markInitializingComplete: true);
      } else {
        _currentUser = null;
        _isInitializing = false;
        notifyListeners();
      }
    });
  }

  Future<void> _restoreExistingSession() async {
    _isInitializing = true;
    notifyListeners();
    await _loadCurrentUser(markInitializingComplete: true);
  }

  Future<void> _loadCurrentUser({bool markInitializingComplete = false}) async {
    try {
      final user = await _authService.getCurrentUser();
      _currentUser = await _applyLegacyStoredAvatar(user);
      if (markInitializingComplete) {
        _isInitializing = false;
      }
      notifyListeners();
    } catch (e) {
      _currentUser = null;
      if (markInitializingComplete) {
        _isInitializing = false;
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final user = await _authService.signIn(email: email, password: password);
      if (user == null) {
        throw Exception('Profile could not be loaded for this account.');
      }

      _currentUser = await _applyLegacyStoredAvatar(user);
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    return _startSocialAuth(_authService.signInWithGoogle);
  }

  Future<bool> signInWithFacebook() async {
    return _startSocialAuth(_authService.signInWithFacebook);
  }

  Future<bool> _startSocialAuth(Future<void> Function() action) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await action();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();

      _currentUser = null;
      _isLoading = false;
      _isInitializing = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.updateUserProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

      _currentUser = _currentUser!.copyWith(
        fullName: fullName,
        avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({required String newPassword}) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.changePassword(newPassword: newPassword);

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.resetPassword(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> updateProfileAvatar(Uint8List avatarBytes) async {
    try {
      final user = _currentUser;
      if (user == null) {
        _errorMessage = 'No authenticated user found.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      notifyListeners();

      final avatarUrl = await _authService.uploadProfileAvatar(
        userId: user.id,
        bytes: avatarBytes,
        fileExtension: 'png',
      );

      final prefs = await SharedPreferences.getInstance();
      final legacyKey = _avatarStorageKey(user.id);
      if (prefs.containsKey(legacyKey)) {
        await prefs.remove(legacyKey);
      }

      _currentUser = user.copyWith(avatarUrl: avatarUrl);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeProfileAvatar() async {
    try {
      final user = _currentUser;
      if (user == null) {
        _errorMessage = 'No authenticated user found.';
        notifyListeners();
        return false;
      }

      _isLoading = true;
      notifyListeners();

      await _authService.removeProfileAvatar(userId: user.id);

      final prefs = await SharedPreferences.getInstance();
      final legacyKey = _avatarStorageKey(user.id);
      if (prefs.containsKey(legacyKey)) {
        await prefs.remove(legacyKey);
      }

      _currentUser = user.copyWith(avatarUrl: null);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<AppUser?> _applyLegacyStoredAvatar(AppUser? user) async {
    if (user == null) return null;
    if ((user.avatarUrl ?? '').isNotEmpty) {
      return user;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_avatarStorageKey(user.id));
    if (storedValue == null || storedValue.isEmpty) {
      return user;
    }

    if (_isLocalFilePath(storedValue) && !kIsWeb) {
      final file = File(storedValue);
      if (!file.existsSync()) {
        await prefs.remove(_avatarStorageKey(user.id));
        return user;
      }

      try {
        final uploadedUrl = await _authService.uploadProfileAvatar(
          userId: user.id,
          bytes: await file.readAsBytes(),
          fileExtension: _fileExtensionForPath(storedValue),
        );
        await prefs.remove(_avatarStorageKey(user.id));
        return user.copyWith(avatarUrl: uploadedUrl);
      } catch (_) {
        return user;
      }
    }

    final legacyBytes = _tryDecodeDataUri(storedValue);
    if (legacyBytes != null) {
      try {
        final uploadedUrl = await _authService.uploadProfileAvatar(
          userId: user.id,
          bytes: legacyBytes,
          fileExtension: 'png',
        );
        await prefs.remove(_avatarStorageKey(user.id));
        return user.copyWith(avatarUrl: uploadedUrl);
      } catch (_) {
        return user.copyWith(avatarUrl: storedValue);
      }
    }

    return user;
  }

  Uint8List? _tryDecodeDataUri(String value) {
    if (!value.startsWith('data:image')) {
      return null;
    }

    final separatorIndex = value.indexOf(',');
    if (separatorIndex == -1) {
      return null;
    }

    try {
      return base64Decode(value.substring(separatorIndex + 1));
    } catch (_) {
      return null;
    }
  }

  String _fileExtensionForPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'png';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _avatarStorageKey(String userId) => '$_avatarPreferencePrefix$userId';

  bool _isLocalFilePath(String value) =>
      value.startsWith('/') || value.contains(r':\');
}
