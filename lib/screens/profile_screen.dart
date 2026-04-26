import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  late bool _isEditingProfile;
  late bool _isChangingPassword;

  Uint8List? _pickedImageBytes;
  String? _pickedImagePath;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeControllers();
      }
    });
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _isEditingProfile = false;
    _isChangingPassword = false;
    _pickedImageBytes = null;
    _pickedImagePath = null;
  }

  Future<bool> _confirmLogout() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF162231) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Log out?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : const Color(0xFF486581),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Yes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    return shouldLogout ?? false;
  }

  Future<void> _pickImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      setState(() {
        _isUploadingImage = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single;
      final selectedBytes = selectedFile.bytes;
      final croppedBytes = await _showCropDialog(
        imageBytes: selectedBytes,
      );
      if (!mounted || croppedBytes == null || croppedBytes.isEmpty) {
        return;
      }

      final optimizedBytes = _optimizeAvatarBytes(croppedBytes);
      final success = await authProvider.updateProfileAvatar(optimizedBytes);


      if (!mounted) return;

      if (success) {
        setState(() {
          _pickedImageBytes = optimizedBytes;
          _pickedImagePath = null;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content:
                Text(authProvider.errorMessage ?? 'Failed to update photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _showAvatarOptions() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final hasAvatar = _resolveAvatarImageProvider(user.avatarUrl) != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF102944) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a new photo or remove the current one.',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  hasAvatar ? 'Change photo' : 'Upload photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              if (hasAvatar)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Remove photo',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeImage();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeImage() async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await authProvider.removeProfileAvatar();
    if (!mounted) return;

    if (success) {
      setState(() {
        _pickedImageBytes = null;
        _pickedImagePath = null;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to remove photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List?> _showCropDialog({
    required Uint8List? imageBytes,
  }) {
    if (imageBytes == null || imageBytes.isEmpty) {
      return Future.value(null);
    }

    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProfileImageCropDialog(
        imageBytes: imageBytes,
      ),
    );
  }

  void _initializeControllers() {
    final user = context.read<AuthProvider>().currentUser;
    _nameController.text = user?.fullName ?? '';
    _emailController.text = user?.email ?? '';
  }

  Widget _buildAvatar(AppUser? user) {
    final displayName = (user?.fullName ?? '').trim();
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final imageProvider = _resolveAvatarImageProvider(user?.avatarUrl);

    if (imageProvider != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: imageProvider,
      );
    }

    return CircleAvatar(
      radius: 50,
      backgroundColor:
          user?.isAdmin ?? false ? Colors.orange[100] : Colors.blue[100],
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 40,
          fontWeight: FontWeight.w600,
          color: user?.isAdmin ?? false ? Colors.orange[600] : Colors.blue[600],
        ),
      ),
    );
  }

  ImageProvider<Object>? _resolveAvatarImageProvider(String? avatarUrl) {
    if (_pickedImageBytes != null) {
      return MemoryImage(_pickedImageBytes!);
    }

    if (!kIsWeb && _pickedImagePath != null && _pickedImagePath!.isNotEmpty) {
      final file = File(_pickedImagePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    final dataBytes = _tryDecodeDataUri(avatarUrl);
    if (dataBytes != null) {
      return MemoryImage(dataBytes);
    }

    if (!kIsWeb && _isLocalFilePath(avatarUrl)) {
      final avatarFile = File(avatarUrl);
      if (avatarFile.existsSync()) {
        return FileImage(avatarFile);
      }
      return null;
    }

    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }

    return null;
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

  Uint8List _optimizeAvatarBytes(Uint8List bytes) {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      return bytes;
    }

    final resizedImage = decodedImage.width > 512 || decodedImage.height > 512
        ? img.copyResize(
            decodedImage,
            width: decodedImage.width >= decodedImage.height ? 512 : null,
            height: decodedImage.height > decodedImage.width ? 512 : null,
            interpolation: img.Interpolation.cubic,
          )
        : decodedImage;

    return Uint8List.fromList(img.encodePng(resizedImage));
  }

  bool _isLocalFilePath(String path) =>
      path.startsWith('/') || path.contains(r':\');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleUpdateProfile(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    final success = await authProvider.updateProfile(
      fullName: name,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isEditingProfile = false);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleChangePassword(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_newPasswordController.text != _confirmPasswordController.text) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final newPassword = _newPasswordController.text;

    final success = await authProvider.changePassword(
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isChangingPassword = false);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Change password failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final avatar = _buildAvatar(user);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Profile Avatar with upload
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        avatar,
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: GestureDetector(
                            onTap:
                                _isUploadingImage ? null : _showAvatarOptions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF123B67) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: _isUploadingImage
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.camera_alt,
                                      size: 22,
                                      color: isDark ? Colors.white : null,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: user?.isAdmin ?? false
                            ? Colors.orange[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (user?.isAdmin ?? false ? 'Admin' : 'User')
                            .toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: user?.isAdmin ?? false
                              ? Colors.orange[600]
                              : Colors.blue[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Profile Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF102944) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Personal Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.grey[900],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() =>
                                      _isEditingProfile = !_isEditingProfile);
                                },
                                child: Text(
                                  _isEditingProfile ? 'Cancel' : 'Edit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!_isEditingProfile)
                            Column(
                              children: [
                                _ProfileInfoTile(
                                  label: 'Full Name',
                                  value: user?.fullName ?? 'N/A',
                                ),
                                const SizedBox(height: 12),
                                _ProfileInfoTile(
                                  label: 'Email',
                                  value: user?.email ?? 'N/A',
                                ),
                                const SizedBox(height: 12),
                                _ProfileInfoTile(
                                  label: 'Member Since',
                                  value: user?.createdAt
                                          .toString()
                                          .split(' ')[0] ??
                                      'N/A',
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                CustomTextField(
                                  label: 'Full Name',
                                  hintText: 'Enter your full name',
                                  icon: Icons.person_outline,
                                  controller: _nameController,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _handleUpdateProfile(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Save Changes',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Security Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF102944) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Security',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.grey[900],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isChangingPassword =
                                      !_isChangingPassword);
                                  _currentPasswordController.clear();
                                  _newPasswordController.clear();
                                  _confirmPasswordController.clear();
                                },
                                child: Text(
                                  _isChangingPassword
                                      ? 'Cancel'
                                      : 'Change Password',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!_isChangingPassword)
                            Column(
                              children: [
                                const _SecurityInfoTile(
                                  label: 'Password',
                                  value: '••••••••',
                                ),
                                const SizedBox(height: 12),
                                _SecurityInfoTile(
                                  label: 'Last Login',
                                  value: user?.lastLogin
                                          ?.toString()
                                          .split('.')[0] ??
                                      'N/A',
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                CustomTextField(
                                  label: 'Current Password',
                                  hintText: 'Enter current password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _currentPasswordController,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'New Password',
                                  hintText: 'Enter new password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _newPasswordController,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Confirm Password',
                                  hintText: 'Confirm new password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  controller: _confirmPasswordController,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _handleChangePassword(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Update Password',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (user?.isAdmin ?? false)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  final authProvider =
                                      context.read<AuthProvider>();
                                  final navigator = Navigator.of(context);
                                  final shouldLogout = await _confirmLogout();
                                  if (!mounted) return;
                                  if (!shouldLogout) return;
                                  await authProvider.signOut();
                                  if (!mounted) return;
                                  navigator.popUntil((route) => route.isFirst);
                                },
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Sign Out',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            side: BorderSide(color: Colors.red[200]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (user?.isAdmin ?? false) const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
      ],
    );
  }
}

class _SecurityInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _SecurityInfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
      ],
    );
  }
}
class _ProfileImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const _ProfileImageCropDialog({
    required this.imageBytes,
  });

  @override
  State<_ProfileImageCropDialog> createState() =>
      _ProfileImageCropDialogState();
}

class _ProfileImageCropDialogState extends State<_ProfileImageCropDialog> {
  final CropController _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF102944) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust Profile Photo',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              'Drag and zoom until the photo fits the circle nicely.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: (result) {
                    if (!mounted) return;

                    switch (result) {
                      case CropSuccess():
                        Navigator.of(context).pop(result.croppedImage);
                      case CropFailure():
                        setState(() {
                          _isCropping = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to crop image: ${result.cause}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                    }
                  },
                  withCircleUi: true,
                  interactive: true,
                  fixCropRect: true,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.9,
                    aspectRatio: 1,
                  ),
                  baseColor: Colors.grey.shade900,
                  maskColor: Colors.black.withValues(alpha: 0.55),
                  progressIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isCropping ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isCropping
                      ? null
                      : () {
                          setState(() {
                            _isCropping = true;
                          });
                          _cropController.crop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCropping
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Save Photo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



