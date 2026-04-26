import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../models/section_content_item.dart';
import '../models/section_item.dart';
import '../models/slide_item.dart';
import 'profile_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image/image.dart' as img;
import '../services/supabase_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with WidgetsBindingObserver {
  int _selectedTab = 0;
  String? selectedImagePath;
  Uint8List? selectedImageBytes;
  String? _selectedSectionFilter;
  int _totalUsers = 0;
  int _activeUsers = 0;
  bool _isLoadingStats = true;

  void addSlide() {
    _showSlideEditDialog(context, null);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboardStats();
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final profiles = await SupabaseService.instance.select(
        'profiles',
        columns: 'id,last_login',
      );
      final now = DateTime.now();
      final activeUsers = profiles.where((profile) {
        final lastLogin = profile['last_login'];
        if (lastLogin == null) return false;
        final parsed = DateTime.tryParse(lastLogin.toString());
        if (parsed == null) return false;
        return now.difference(parsed).inDays <= 30;
      }).length;

      if (!mounted) return;
      setState(() {
        _totalUsers = profiles.length;
        _activeUsers = activeUsers;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  void editSlide(String slideId, SlideItem slide) {
    _showSlideEditDialog(context, slide);
  }

  void removeSlide(String slideId) {
    context.read<ContentProvider>().removeSlide(slideId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slide removed successfully!')),
      );
    }
  }

  void _showSlideEditDialog(BuildContext context, SlideItem? existingSlide) {
    final titleController =
        TextEditingController(text: existingSlide?.title ?? '');
    final subtitleController =
        TextEditingController(text: existingSlide?.subtitle ?? '');
    final routeController =
        TextEditingController(text: existingSlide?.route ?? '');
    Color selectedColor = existingSlide?.backgroundColor ?? Colors.blueAccent;
    String? selectedImagePath;
    Uint8List? selectedImageBytes;

    // Load existing image if available
    if (existingSlide?.imageBase64 != null) {
      selectedImageBytes = base64Decode(existingSlide!.imageBase64!);
    }

    final colorOptions = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
      Colors.tealAccent,
      Colors.amber,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existingSlide == null ? 'Add Slide' : 'Edit Slide',
            style: GoogleFonts.poppins(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                Text(
                  'Title',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Slide title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Subtitle Field
                Text(
                  'Subtitle',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subtitleController,
                  decoration: InputDecoration(
                    hintText: 'Slide subtitle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Route Field
                Text(
                  'Route',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: routeController,
                  decoration: InputDecoration(
                    hintText: 'e.g., /section/health-tips',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Image Upload
                Text(
                  'Slide Image',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedImagePath != null || selectedImageBytes != null)
                  Container(
                    width: double.infinity,
                    height: 150,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: selectedImageBytes != null
                        ? Image.memory(
                            selectedImageBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(selectedImagePath!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform
                        .pickFiles(type: FileType.image);
                    if (result != null) {
                      Uint8List? pickedBytes;
                      String? pickedPath;

                      if (kIsWeb) {
                        pickedBytes = result.files.single.bytes;
                        pickedPath = result.files.single.name;
                      } else {
                        pickedPath = result.files.single.path;
                        if (pickedPath != null && pickedPath.isNotEmpty) {
                          pickedBytes = await File(pickedPath).readAsBytes();
                        }
                      }

                      if (pickedBytes == null || pickedBytes.isEmpty) {
                        return;
                      }

                      final croppedBytes = _cropSlideImageTo16By9(pickedBytes);
                      setState(() {
                        selectedImageBytes = croppedBytes;
                        selectedImagePath = pickedPath;
                      });
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('Upload Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Slide image is fixed to 16:9',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploaded images are automatically center-cropped to fit the banner.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                if (selectedImagePath != null || selectedImageBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedImagePath = null;
                          selectedImageBytes = null;
                        });
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Color Selector
                Text(
                  'Background Color',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colorOptions.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final contentProvider = context.read<ContentProvider>();
                String? imageBase64;

                // Encode image as base64 for web support
                if (selectedImageBytes != null) {
                  imageBase64 = base64Encode(selectedImageBytes!);
                }

                final newSlide = SlideItem(
                  id: existingSlide?.id ??
                      'slide_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleController.text,
                  subtitle: subtitleController.text,
                  backgroundColor: selectedColor,
                  route: routeController.text,
                  imagePath: null,
                  imageBase64: imageBase64,
                  imageWidth: 1600,
                  imageHeight: 900,
                );

                if (existingSlide == null) {
                  contentProvider.addSlide(newSlide);
                } else {
                  contentProvider.updateSlide(existingSlide.id, newSlide);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      existingSlide == null
                          ? 'Slide added successfully!'
                          : 'Slide updated successfully!',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
              ),
              child: Text(
                existingSlide == null ? 'Add' : 'Update',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar({
    required String? avatarUrl,
    required String userInitial,
  }) {
    final imageProvider = _resolveAvatarImageProvider(avatarUrl);
    if (imageProvider != null) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: imageProvider,
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.orange[100],
      child: Text(
        userInitial,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.orange[600],
        ),
      ),
    );
  }

  ImageProvider<Object>? _resolveAvatarImageProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }

    final dataBytes = _tryDecodeDataUri(avatarUrl);
    if (dataBytes != null) {
      return MemoryImage(dataBytes);
    }

    if (!kIsWeb &&
        (avatarUrl.startsWith('/') || avatarUrl.contains(r':\')) &&
        File(avatarUrl).existsSync()) {
      return FileImage(File(avatarUrl));
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

  Uint8List _cropSlideImageTo16By9(Uint8List bytes) {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      return bytes;
    }

    const targetRatio = 16 / 9;
    final sourceRatio = decodedImage.width / decodedImage.height;

    img.Image croppedImage;
    if (sourceRatio > targetRatio) {
      final cropWidth = (decodedImage.height * targetRatio).round();
      final offsetX = ((decodedImage.width - cropWidth) / 2).round();
      croppedImage = img.copyCrop(
        decodedImage,
        x: offsetX,
        y: 0,
        width: cropWidth,
        height: decodedImage.height,
      );
    } else if (sourceRatio < targetRatio) {
      final cropHeight = (decodedImage.width / targetRatio).round();
      final offsetY = ((decodedImage.height - cropHeight) / 2).round();
      croppedImage = img.copyCrop(
        decodedImage,
        x: 0,
        y: offsetY,
        width: decodedImage.width,
        height: cropHeight,
      );
    } else {
      croppedImage = decodedImage;
    }

    final resizedImage = img.copyResize(
      croppedImage,
      width: 1600,
      height: 900,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 90));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final displayName = (user?.fullName ?? '').trim();
    final userInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              color: Colors.orange[600],
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Admin Panel',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.grey[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome, ${user?.fullName}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                   GestureDetector(
                     onTap: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (context) => const ProfileScreen(),
                         ),
                       );
                     },
                     child: _buildHeaderAvatar(
                       avatarUrl: avatarUrl,
                       userInitial: userInitial,
                     ),
                   ),
                  ],
                ),
                const SizedBox(height: 32),

                // Dashboard Stats
                Text(
                  'System Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AdminStatCard(
                        title: 'Total Users',
                        value: _isLoadingStats ? '...' : _totalUsers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                        trend: _isLoadingStats
                            ? 'Loading users'
                            : _totalUsers == 1
                                ? '1 profile found'
                                : '$_totalUsers profiles found',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminStatCard(
                        title: 'Active Users',
                        value:
                            _isLoadingStats ? '...' : _activeUsers.toString(),
                        icon: Icons.person_outline,
                        color: Colors.green,
                        trend: _isLoadingStats
                            ? 'Checking activity'
                            : 'Logged in within 30 days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Consumer<ContentProvider>(
                        builder: (context, contentProvider, child) {
                          final contentCount =
                              contentProvider.sectionContent.length;
                          return _AdminStatCard(
                            title: 'Content Created',
                            value: contentCount.toString(),
                            icon: Icons.content_paste,
                            color: Colors.purple,
                            trend:
                                '${contentCount > 0 ? '+${contentCount ~/ 2}' : '0'} sections',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<ContentProvider>(
                        builder: (context, contentProvider, child) {
                          final unansweredCount =
                              contentProvider.getUnansweredQuestions().length;
                          return _AdminStatCard(
                            title: 'Unanswered Questions',
                            value: unansweredCount.toString(),
                            icon: Icons.help_outline,
                            color: Colors.orange,
                            trend: unansweredCount > 0
                                ? 'Awaiting response'
                                : 'All answered',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102944) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _TabButton(
                          label: 'Ads',
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        _TabButton(
                          label: 'Content',
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                        _TabButton(
                          label: 'Questions',
                          isSelected: _selectedTab == 2,
                          onTap: () => setState(() => _selectedTab = 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tab Content
                if (_selectedTab == 0) _buildAdsTab(),
                if (_selectedTab == 1) _buildContentManagementTab(),
                if (_selectedTab == 2) _buildQuestionsTab(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentManagementTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentProvider = context.watch<ContentProvider>();
    final allContents = contentProvider.sectionContent;
    final sections = contentProvider.sections;

    // Filter contents based on selected section
    final filteredContents = _selectedSectionFilter == null
        ? allContents
        : allContents
            .where((content) =>
                sections
                    .where((s) => s.id == content.sectionId)
                    .firstOrNull
                    ?.title ==
                _selectedSectionFilter)
            .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Section Content',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[800]
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[300]!, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isDark ? const Color(0xFF102944) : Colors.white,
                                ),
                                child: DropdownButton<String?>(
                                  value: _selectedSectionFilter,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF102944) : Colors.white,
                                  iconEnabledColor: isDark ? Colors.white70 : Colors.grey[700],
                                  underline: const SizedBox(),
                                  hint: Text(
                                    'All Sections',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedSectionFilter = newValue;
                                    });
                                  },
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'All Sections',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.grey[900],
                                        ),
                                      ),
                                    ),
                                    ...sections.map((section) {
                                      return DropdownMenuItem<String>(
                                        value: section.title,
                                        child: Text(
                                          section.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showAddContentDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Manage Section Content',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[800]
                          ),
                        ),
                        Row(
                          children: [
                            // Section Filter Dropdown
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                                color: isDark ? const Color(0xFF102944) : Colors.white,
                              ),
                              child: DropdownButton<String?>(
                                value: _selectedSectionFilter,
                                isExpanded: false,
                                dropdownColor: isDark ? const Color(0xFF102944) : Colors.white,
                                iconEnabledColor: isDark ? Colors.white70 : Colors.grey[700],
                                underline: const SizedBox(),
                                hint: Text(
                                  'All Sections',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedSectionFilter = newValue;
                                  });
                                },
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'All Sections',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  ...sections.map((section) {
                                    return DropdownMenuItem<String>(
                                      value: section.title,
                                      child: Text(
                                        section.title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.grey[900],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddContentDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Content'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          // Content list
          _buildContentList(filteredContents, sections, contentProvider),
        ],
      ),
    );
  }

  Widget _buildContentList(List<SectionContentItem> contents,
      List<SectionItem> sections, ContentProvider contentProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No content found',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: contents.map<Widget>((content) {
        final section = sections.firstWhere(
          (s) => s.id == content.sectionId,
          orElse: () => sections.first,
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF102944) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: content.backgroundColor.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            section.title,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: content.backgroundColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (content.bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${content.bulletPoints.length} bullet points',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: Colors.blue[600],
                        onPressed: () =>
                            _showEditContentDialog(context, content),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.red[600],
                        onPressed: () {
                          contentProvider.removeSectionContent(content.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Content deleted: ${content.title}',
                                style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                              ),
                              backgroundColor: Colors.red[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuestionsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentProvider = context.watch<ContentProvider>();
    final unansweredQuestions = contentProvider.getUnansweredQuestions();
    final answeredQuestions = contentProvider.getAnsweredQuestions();

    return Column(
      children: [
        // Unanswered Questions Section
        if (unansweredQuestions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${unansweredQuestions.length} unanswered question${unansweredQuestions.length > 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pending Questions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...unansweredQuestions.map((question) {
            return _buildQuestionCard(context, question, contentProvider);
          }),
          const SizedBox(height: 20),
        ],

        // Answered Questions Section
        if (answeredQuestions.isNotEmpty) ...[
          Text(
            'Answered Questions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...answeredQuestions.map(_buildAnsweredQuestionCard),
        ] else if (unansweredQuestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF102944) : Colors.grey[50],
                border: Border.all(
                  color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[200]!,
                ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 48,
                  color: isDark ? Colors.white54 : Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Text(
                  'No questions yet',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionCard(
      BuildContext context, dynamic question, ContentProvider contentProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController replyController = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102944) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF8C6322) : Colors.orange[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q: ${question.question}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asked by ${question.userName} • ${_formatDate(question.askedAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13263C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[300]!,
              ),
            ),
            child: Text(
              question.adminIntakeSummary,
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Reply Input
          TextField(
            controller: replyController,
            maxLines: 3,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
            decoration: InputDecoration(
              hintText: 'Type your reply here...',
              filled: true,
              fillColor: isDark ? const Color(0xFF13263C) : Colors.white,
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2F4E6B) : Colors.grey,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2F4E6B) : Colors.grey,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.teal, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Reply and Delete Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Delete Button
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(
                        'Delete Question',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to delete this unanswered question? This action cannot be undone, and the unanswered count will be reduced by 1.',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            contentProvider.deleteUserQuestion(question.id);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unanswered question deleted and count reduced by 1',
                                  style: GoogleFonts.poppins(
                                    color:
                                        isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                                backgroundColor: Colors.red[600],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[600]!),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Post Reply Button
              ElevatedButton(
                onPressed: () {
                  if (replyController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter a reply',
                          style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                        ),
                        backgroundColor: Colors.orange[600],
                      ),
                    );
                    return;
                  }

                  contentProvider.replyToQuestion(
                    question.id,
                    replyController.text.trim(),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Reply posted and added to Q&A section!',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      backgroundColor: Colors.green[600],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Post Reply',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnsweredQuestionCard(dynamic question) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserName = (authProvider.currentUser?.fullName ?? '').trim();
    final askerName = (question.userName ?? '').trim();
    final isAskedByCurrentUser = currentUserName.isNotEmpty &&
        askerName.isNotEmpty &&
        currentUserName.toLowerCase() == askerName.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102944) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2F6B56) : Colors.green[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q: ${question.question}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Asked by ${question.userName}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13263C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[300]!,
              ),
            ),
            child: Text(
              question.adminIntakeSummary,
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13263C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  question.reply ?? '',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Replied on ${_formatDate(question.repliedAt ?? DateTime.now())}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // "Asked by you" badge
              if (isAskedByCurrentUser)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Asked by you',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Delete Button for Answered Question
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(
                        'Delete Answered Question',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to delete this answered question? The associated Q&A content will also be removed. This action cannot be undone.',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context
                                .read<ContentProvider>()
                                .deleteUserQuestion(question.id);
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Answered question and its Q&A content deleted',
                                  style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                                ),
                                backgroundColor: Colors.red[600],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[600]!),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAddContentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ContentEditDialog(
        onSave: (content) {
          context.read<ContentProvider>().addSectionContent(content);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Content added: ${content.title}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green[600],
            ),
          );
        },
      ),
    );
  }

  void _showEditContentDialog(
      BuildContext context, SectionContentItem content) {
    showDialog(
      context: context,
      builder: (context) => _ContentEditDialog(
        initialContent: content,
        onSave: (updatedContent) {
          context
              .read<ContentProvider>()
              .updateSectionContent(content.id, updatedContent);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Content updated: ${updatedContent.title}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.blue[600],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentProvider = context.watch<ContentProvider>();
    final slidesList = contentProvider.slides;

    return Column(
      children: [
        Text(
          'Slides Management',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        if (slidesList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2F4E6B) : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.image_not_supported,
                      size: 48, color: isDark ? Colors.white54 : Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No slides added yet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slidesList.length,
            itemBuilder: (context, index) {
              final slide = slidesList[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: slide.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: slide.imageBase64 != null &&
                              slide.imageBase64!.isNotEmpty
                          ? Image.memory(
                              base64Decode(slide.imageBase64!),
                              fit: BoxFit.cover,
                            )
                          : (!kIsWeb &&
                                  slide.imagePath != null &&
                                  slide.imagePath!.isNotEmpty &&
                                  File(slide.imagePath!).existsSync())
                              ? Image.file(
                                  File(slide.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                    ),
                  ),
                  title: Text(
                    slide.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    slide.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => editSlide(slide.id, slide),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => removeSlide(slide.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: addSlide,
          icon: const Icon(Icons.add),
          label: const Text('Add Slide'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Dialog for editing/adding section content
class _ContentEditDialog extends StatefulWidget {
  final SectionContentItem? initialContent;
  final Function(SectionContentItem) onSave;

  const _ContentEditDialog({
    this.initialContent,
    required this.onSave,
  });

  @override
  State<_ContentEditDialog> createState() => _ContentEditDialogState();
}

class _ContentEditDialogState extends State<_ContentEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _bulletPointsController;
  String? _selectedSectionId;
  Color _selectedColor = Colors.blue;
  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  double? _selectedImageAspectRatio;
  double _imageDisplayHeight = 200;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialContent?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialContent?.description ?? '',
    );
    _bulletPointsController = TextEditingController(
      text: widget.initialContent?.bulletPoints.join('\n') ?? '',
    );
    _selectedSectionId = widget.initialContent?.sectionId;
    _selectedColor = widget.initialContent?.backgroundColor ?? Colors.blue;
    _selectedImageAspectRatio = widget.initialContent?.imageAspectRatio;
    _imageDisplayHeight = widget.initialContent?.imageDisplayHeight ?? 200;

    // Load existing image if available
    if (widget.initialContent?.imageUrl != null) {
      final imageUrl = widget.initialContent!.imageUrl!;
      _selectedImagePath = imageUrl;

      // If it's a base64 image, extract the bytes
      if (imageUrl.startsWith('data:image')) {
        try {
          final base64String = imageUrl.split(',').last;
          _selectedImageBytes = base64Decode(base64String);
          _selectedImageAspectRatio =
              widget.initialContent?.imageAspectRatio ??
                  _inferImageAspectRatio(_selectedImageBytes);
        } catch (e) {
          // If decoding fails, keep it as path for error handling
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _bulletPointsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      setState(() {
        _selectedImagePath = file.path ?? file.name;
        _selectedImageBytes = bytes;
        _selectedImageAspectRatio = _inferImageAspectRatio(bytes);
      });
    }
  }

  Future<void> _cropImage() async {
    final imageBytes = _selectedImageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      return;
    }

    final cropResult = await showDialog<_ContentImageCropResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ContentImageCropDialog(
        imageBytes: imageBytes,
        initialAspectRatio:
            _selectedImageAspectRatio ?? _inferImageAspectRatio(imageBytes),
      ),
    );

    if (cropResult == null || cropResult.bytes.isEmpty) {
      return;
    }

    setState(() {
      _selectedImageBytes = cropResult.bytes;
      _selectedImageAspectRatio = cropResult.aspectRatio;
    });
  }

  double? _inferImageAspectRatio(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null || decodedImage.height == 0) {
      return null;
    }

    return decodedImage.width / decodedImage.height;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentProvider = context.read<ContentProvider>();
    final List<SectionItem> sections = contentProvider.sections;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF102944) : Colors.white,
      title: Text(
        widget.initialContent != null ? 'Edit Content' : 'Add New Content',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.grey[900],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section selector
            Text(
              'Section',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              dropdownColor: isDark ? const Color(0xFF123B67) : Colors.white,
              isExpanded: true,
              value: _selectedSectionId,
              hint: Text('Select a section', style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[600])),
              items: sections
                  .map(
                    (section) => DropdownMenuItem(
                      value: section.id,
                      child: Text(section.title, style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.grey[900])),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedSectionId = value);
              },
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Title',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.grey[900]),
              decoration: InputDecoration(
                filled: isDark,
                fillColor: isDark ? const Color(0xFF123B67) : null,
                hintText: 'Content title',
                hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Description',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.grey[900]),
              decoration: InputDecoration(
                filled: isDark,
                fillColor: isDark ? const Color(0xFF123B67) : null,
                hintText: 'Brief description',
                hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Bullet Points
            Text(
              'Bullet Points (one per line)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bulletPointsController,
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.grey[900]),
              decoration: InputDecoration(
                filled: isDark,
                fillColor: isDark ? const Color(0xFF123B67) : null,
                hintText: 'Enter bullet points separated by new lines',
                hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Color Picker
            Text(
              'Box Color',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Colors.blue,
                Colors.green,
                Colors.red,
                Colors.purple,
                Colors.amber,
                Colors.teal,
              ]
                  .map(
                    (color) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? Colors.black
                                : Colors.grey[300]!,
                            width: _selectedColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Image Upload
            Text(
              'Content Image (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImagePath != null ? 'Change Image' : 'Upload Image',
                  style: GoogleFonts.poppins(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                  color: isDark ? const Color(0xFF123B67) : Colors.grey[100],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _selectedImageAspectRatio != null
                      ? AspectRatio(
                          aspectRatio: _selectedImageAspectRatio!,
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : SizedBox(
                          height: _imageDisplayHeight,
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cropImage,
                      icon: const Icon(Icons.crop),
                      label: const Text('Crop Image'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Image Size',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[700],
                ),
              ),
              Slider(
                value: _imageDisplayHeight,
                min: 120,
                max: 320,
                divisions: 10,
                label: '${_imageDisplayHeight.round()} px',
                onChanged: (value) {
                  setState(() {
                    _imageDisplayHeight = value;
                  });
                },
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Preview: this image will be shown to users after you save.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedImagePath = null;
                      _selectedImageBytes = null;
                      _selectedImageAspectRatio = null;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Remove Image'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty ||
                _descriptionController.text.isEmpty ||
                _selectedSectionId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please fill all required fields',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.red[600],
                ),
              );
              return;
            }

            final bulletPoints = _bulletPointsController.text
                .split('\n')
                .where((point) => point.trim().isNotEmpty)
                .toList();

            // Prepare image URL (always use base64 for cross-platform compatibility)
            String? imageUrl;
            if (_selectedImageBytes != null &&
                _selectedImageBytes!.isNotEmpty) {
              // Detect image format from file name or use generic format
              String mimeType = 'image/png'; // default
              if ((_selectedImagePath?.contains('.jpg') ?? false) ||
                  (_selectedImagePath?.contains('.jpeg') ?? false)) {
                mimeType = 'image/jpeg';
              } else if (_selectedImagePath?.contains('.gif') ?? false) {
                mimeType = 'image/gif';
              } else if (_selectedImagePath?.contains('.webp') ?? false) {
                mimeType = 'image/webp';
              }
              imageUrl =
                  'data:$mimeType;base64,${base64Encode(_selectedImageBytes!)}';
            }

            final content = widget.initialContent != null
                ? widget.initialContent!.copyWith(
                    title: _titleController.text,
                    description: _descriptionController.text,
                    backgroundColor: _selectedColor,
                    bulletPoints: bulletPoints,
                    imageUrl: imageUrl ?? widget.initialContent!.imageUrl,
                    imageAspectRatio: _selectedImageAspectRatio,
                    imageDisplayHeight: _imageDisplayHeight,
                  )
                : SectionContentItem(
                    id: 'content_${DateTime.now().millisecondsSinceEpoch}',
                    sectionId: _selectedSectionId!,
                    title: _titleController.text,
                    description: _descriptionController.text,
                    backgroundColor: _selectedColor,
                    bulletPoints: bulletPoints,
                    imageUrl: imageUrl,
                    imageAspectRatio: _selectedImageAspectRatio,
                    imageDisplayHeight: _imageDisplayHeight,
                  );

            widget.onSave(content);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Save',
            style: GoogleFonts.poppins(),
          ),
        ),
      ],
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trend,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _ContentImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double? initialAspectRatio;

  const _ContentImageCropDialog({
    required this.imageBytes,
    this.initialAspectRatio,
  });

  @override
  State<_ContentImageCropDialog> createState() => _ContentImageCropDialogState();
}

class _ContentImageCropDialogState extends State<_ContentImageCropDialog> {
  final CropController _cropController = CropController();
  bool _isCropping = false;
  double? _selectedAspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    _selectedAspectRatio = widget.initialAspectRatio ?? 16 / 9;
  }

  void _setAspectRatio(double? ratio) {
    setState(() {
      _selectedAspectRatio = ratio;
    });
    _cropController.aspectRatio = ratio;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crop Content Image',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag and zoom to choose the part of the image you want to show.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AspectRatioChip(
                  label: '16:9',
                  isSelected: _selectedAspectRatio == 16 / 9,
                  onTap: () => _setAspectRatio(16 / 9),
                ),
                _AspectRatioChip(
                  label: '1:1',
                  isSelected: _selectedAspectRatio == 1,
                  onTap: () => _setAspectRatio(1),
                ),
                _AspectRatioChip(
                  label: '4:5',
                  isSelected: _selectedAspectRatio == 4 / 5,
                  onTap: () => _setAspectRatio(4 / 5),
                ),
                _AspectRatioChip(
                  label: '3:4',
                  isSelected: _selectedAspectRatio == 3 / 4,
                  onTap: () => _setAspectRatio(3 / 4),
                ),
                _AspectRatioChip(
                  label: 'Free',
                  isSelected: _selectedAspectRatio == null,
                  onTap: () => _setAspectRatio(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 380,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: (result) {
                    if (!mounted) return;

                    switch (result) {
                      case CropSuccess():
                        Navigator.of(context).pop(
                          _ContentImageCropResult(
                            bytes: result.croppedImage,
                            aspectRatio: _selectedAspectRatio ??
                                _inferAspectRatio(result.croppedImage),
                          ),
                        );
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
                  interactive: true,
                  fixCropRect: false,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.9,
                    aspectRatio: _selectedAspectRatio ?? 16 / 9,
                  ),
                  baseColor: Colors.grey.shade900,
                  maskColor: Colors.black.withValues(alpha: 0.5),
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
                    style: GoogleFonts.poppins(),
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
                          'Apply Crop',
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

  double? _inferAspectRatio(Uint8List bytes) {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null || decodedImage.height == 0) {
      return null;
    }

    return decodedImage.width / decodedImage.height;
  }
}

class _ContentImageCropResult {
  final Uint8List bytes;
  final double? aspectRatio;

  const _ContentImageCropResult({
    required this.bytes,
    required this.aspectRatio,
  });
}

class _AspectRatioChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AspectRatioChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: isMobile ? 100 : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected                 ? (isDark ? const Color(0xFF1D3A5A) : Colors.white)                 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 11 : 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected                   ? (isDark ? Colors.white : Colors.grey[900])                   : (Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }
}


































