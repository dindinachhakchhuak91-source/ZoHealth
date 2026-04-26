import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/user_question.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../models/slide_item.dart';
import '../widgets/home_widgets.dart';
import 'nutrition_calculator_screen.dart';
import 'nutrition_tracker_screen.dart';
import 'user_settings_screen.dart';
import 'growth_micronutrition_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final ValueNotifier<String?> _selectedSectionTitle = ValueNotifier<String?>('Health Tips');
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _recentFoodController = TextEditingController();
  String? _selectedGender;
  String? _selectedEatingWindow;
  bool _showOtherUserQuestions = false;
  int _currentTabIndex = 0;
  final PageController _mobileAdsController = PageController();
  final PageController _desktopAdsController =
      PageController(viewportFraction: 0.82);
  Timer? _adsTimer;
  int _currentAdIndex = 0;

  static const List<String> _genderOptions = [
    'Female',
    'Male',
    'Other',
    'Prefer not to say',
  ];

  static const List<String> _eatingWindowOptions = [
    'Within the last hour',
    '1-3 hours ago',
    '3-6 hours ago',
    '6-12 hours ago',
    '12-24 hours ago',
    'More than 1 day ago',
  ];

  @override
  void initState() {
    super.initState();
    _startAdsAutoSlide();
  }

  @override
  void dispose() {
    _adsTimer?.cancel();
    _mobileAdsController.dispose();
    _desktopAdsController.dispose();
    _selectedSectionTitle.dispose();
    _questionController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _recentFoodController.dispose();
    super.dispose();
  }

  void _startAdsAutoSlide() {
    _adsTimer?.cancel();
    _adsTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      final contentProvider = context.read<ContentProvider>();
      final itemCount = contentProvider.slides.isNotEmpty
          ? contentProvider.slides.length
          : contentProvider.ads.length;

      if (itemCount <= 1) {
        return;
      }

      final nextPage = (_currentAdIndex + 1) % itemCount;
      final controller = _activeAdsController();
      if (!controller.hasClients) {
        return;
      }

      controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  PageController _activeAdsController() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    return logicalWidth >= 900 ? _desktopAdsController : _mobileAdsController;
  }

  Future<bool> _confirmLogout(BuildContext context) async {
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
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
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
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    return shouldLogout ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pages = [
      _buildHomePage(context),
      const NutritionCalculatorScreen(showAppBar: false),
      NutritionTrackerScreen(
        showAppBar: false,
        isActive: _currentTabIndex == 2,
      ),
      const GrowthMicronutritionScreen(),
      const UserSettingsScreen(showAppBar: false),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SafeArea(
          top: false,
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162231) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 56,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / 5;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: itemWidth * _currentTabIndex,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: itemWidth,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x331563A7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0x551563A7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            label: 'Home',
                            icon: Icons.home_rounded,
                            selected: _currentTabIndex == 0,
                            onTap: () => setState(() => _currentTabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'Calculator',
                            icon: Icons.restaurant_menu_rounded,
                            selected: _currentTabIndex == 1,
                            onTap: () => setState(() => _currentTabIndex = 1),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'Tracker',
                            icon: Icons.monitor_heart_outlined,
                            selected: _currentTabIndex == 2,
                            onTap: () => setState(() => _currentTabIndex = 2),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'Growth',
                            icon: Icons.trending_up,
                            selected: _currentTabIndex == 3,
                            onTap: () => setState(() => _currentTabIndex = 3),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            label: 'Settings',
                            icon: Icons.settings_outlined,
                            selected: _currentTabIndex == 4,
                            onTap: () => setState(() => _currentTabIndex = 4),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context, user?.fullName ?? 'User'),
            const SizedBox(height: 20),
            _buildAdsSection(context),
            const SizedBox(height: 20),
            ValueListenableBuilder<String?>(
              valueListenable: _selectedSectionTitle,
              builder: (context, selectedSectionTitle, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionChipsCard(selectedSectionTitle),
                    const SizedBox(height: 20),
                    if (selectedSectionTitle != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(selectedSectionTitle),
                            const SizedBox(height: 12),
                            _buildSectionContent(context, selectedSectionTitle),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, String userName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      decoration: BoxDecoration(
        color: const Color(0x261563A7),
        borderRadius: BorderRadius.circular(0),
        border: Border.all(
          color: const Color(0x331563A7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.blueGrey[600],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  userName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final shouldLogout = await _confirmLogout(context);
              if (!mounted) return;
              if (!shouldLogout) return;
              await authProvider.signOut();
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(
              Icons.logout_rounded,
              size: 18,
              color: Color.fromARGB(255, 22, 99, 167),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsSection(BuildContext context) {
    final contentProvider = context.watch<ContentProvider>();
    if (!contentProvider.isInitialized) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final adsController =
        isDesktop ? _desktopAdsController : _mobileAdsController;

    Widget buildBanner(Widget child) {
      if (!isDesktop) {
        return child;
      }

      return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: screenWidth.clamp(0, 1120).toDouble(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: _currentAdIndex == 0 ? 18 : 8,
              right: _currentAdIndex == 0 ? 8 : 18,
            ),
            child: child,
          ),
        ),
      );
    }

    if (contentProvider.slides.isNotEmpty) {
      final slides = contentProvider.slides;
      return Column(
        children: [
          buildBanner(
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView.builder(
                itemCount: slides.length,
                controller: adsController,
                padEnds: !isDesktop,
                clipBehavior: Clip.none,
                onPageChanged: (index) {
                  setState(() => _currentAdIndex = index);
                },
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return _DashboardAdCard(
                    title: slide.title,
                    description: slide.subtitle,
                    slide: slide,
                    horizontalMargin: isDesktop ? 10 : 12,
                  );
              },
            ),
            ),
          ),
          const SizedBox(height: 12),
          _buildAdsIndicator(slides.length),
        ],
      );
    }

    final ads = contentProvider.ads;
    if (ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        buildBanner(
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              itemCount: ads.length,
              controller: adsController,
              padEnds: !isDesktop,
              clipBehavior: Clip.none,
              onPageChanged: (index) {
                setState(() => _currentAdIndex = index);
              },
              itemBuilder: (context, index) {
                final ad = ads[index];
                return _DashboardAdCard(
                  title: ad['title'] ?? 'Health update',
                  description: ad['description'] ?? '',
                  horizontalMargin: isDesktop ? 10 : 12,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAdsIndicator(ads.length),
      ],
    );
  }

  Widget _buildAdsIndicator(int itemCount) {
    if (itemCount <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final isActive = index == _currentAdIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color.fromARGB(255, 22, 99, 167)
                : const Color(0x331563A7),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildSectionChipsCard(String? selectedSectionTitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 10),
          SectionMenu(
            selectedSection: selectedSectionTitle,
            onSectionTapped: (title) {
              if (_selectedSectionTitle.value != title) {
                _selectedSectionTitle.value = title;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String selectedSectionTitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            selectedSectionTitle,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context, String selectedSectionTitle) {
    final contentProvider = context.watch<ContentProvider>();
    final sections = contentProvider.sections;

    String? selectedSectionId;
    try {
      selectedSectionId = sections
          .firstWhere((section) => section.title == selectedSectionTitle)
          .id;
    } catch (_) {
      selectedSectionId = null;
    }

    if (selectedSectionId == null) {
      return _buildEmptyCard('Section not found.');
    }

    final rawContentList =
        contentProvider.getContentListForSection(selectedSectionId);
    final isQaSection = selectedSectionTitle == 'Q&A';
    final otherUserQuestions = isQaSection
        ? rawContentList
            .where((content) => content.id.startsWith('content_qa_user_'))
            .toList()
        : const [];
    final contentList = isQaSection
        ? rawContentList
            .where((content) => !content.id.startsWith('content_qa_user_'))
            .toList()
        : rawContentList;

    if (contentList.isEmpty && !isQaSection) {
      return _buildEmptyCard('No content available for this section yet.');
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1200;
    final List<Widget> contentWidgets = contentList
        .map<Widget>(
          (content) => ExpandableContentBox(
            title: content.title,
            description: content.description,
            bulletPoints: content.bulletPoints,
            backgroundColor: content.backgroundColor,
            imageUrl: content.imageUrl,
            imageAspectRatio: content.imageAspectRatio,
            imageDisplayHeight: content.imageDisplayHeight,
          ),
        )
        .toList();

    if (isQaSection) {
      if (otherUserQuestions.isNotEmpty) {
        contentWidgets.add(
          _buildOtherUserQuestionsButton(context),
        );
      }

      if (_showOtherUserQuestions) {
        contentWidgets.addAll(
          otherUserQuestions.map<Widget>(
            (content) => ExpandableContentBox(
              title: content.title,
              description: content.description,
              bulletPoints: content.bulletPoints,
              backgroundColor: content.backgroundColor,
              imageUrl: content.imageUrl,
              imageAspectRatio: content.imageAspectRatio,
              imageDisplayHeight: content.imageDisplayHeight,
            ),
          ),
        );
      }

      contentWidgets.add(
        _buildQuestionInputForm(context),
      );
    }

    if (!isDesktop) {
      return Column(
        children: contentWidgets
            .map(
              (widget) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: widget,
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: contentWidgets
              .map(
                (widget) => SizedBox(
                  width: itemWidth,
                  child: widget,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildOtherUserQuestionsButton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _showOtherUserQuestions = !_showOtherUserQuestions;
          });
        },
        icon: Icon(
          _showOtherUserQuestions
              ? Icons.visibility_off_outlined
              : Icons.people_alt_outlined,
          size: 18,
        ),
        label: Text(
          _showOtherUserQuestions
              ? 'Hide Other User\'s Question'
              : 'Other User\'s Question',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : const Color(0xFF1563A7),
          backgroundColor:
              isDark ? const Color(0xFF162231) : const Color(0xFFF4F9FF),
          side: BorderSide(
            color: isDark ? const Color(0xFF2A3A4E) : const Color(0xFFB7D4F2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.blueGrey[600],
        ),
      ),
    );
  }

  Widget _buildQuestionInputForm(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Have a question?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Type your question here...',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F1722) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(
                  color: Color.fromARGB(255, 22, 99, 167),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF102A43)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: _buildQuestionFieldDecoration(
              isDark,
              'Select gender',
            ),
            dropdownColor: isDark ? const Color(0xFF162231) : Colors.white,
            items: _genderOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: _buildQuestionFieldDecoration(
                    isDark,
                    'Age',
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _buildQuestionFieldDecoration(
                    isDark,
                    'Height (cm)',
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF102A43),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _buildQuestionFieldDecoration(
              isDark,
              'Weight (kg)',
            ),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF102A43)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedEatingWindow,
            decoration: _buildQuestionFieldDecoration(
              isDark,
              'When did you last eat?',
            ),
            dropdownColor: isDark ? const Color(0xFF162231) : Colors.white,
            items: _eatingWindowOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedEatingWindow = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recentFoodController,
            maxLines: 2,
            decoration: _buildQuestionFieldDecoration(
              isDark,
              'What did you eat?',
            ),
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF102A43)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () {
                final age = int.tryParse(_ageController.text.trim());
                final heightCm = double.tryParse(_heightController.text.trim());
                final weightKg = double.tryParse(_weightController.text.trim());

                if (_questionController.text.trim().isEmpty ||
                    _selectedGender == null ||
                    age == null ||
                    age <= 0 ||
                    heightCm == null ||
                    heightCm <= 0 ||
                    weightKg == null ||
                    weightKg <= 0 ||
                    _selectedEatingWindow == null ||
                    _recentFoodController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please complete all required Q&A fields',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.orange[600],
                    ),
                  );
                  return;
                }

                final contentProvider = context.read<ContentProvider>();
                final question = UserQuestion(
                  id: 'q_${DateTime.now().millisecondsSinceEpoch}',
                  question: _questionController.text.trim(),
                  userName: user?.fullName ?? 'Anonymous',
                  gender: _selectedGender!,
                  age: age,
                  heightCm: heightCm,
                  weightKg: weightKg,
                  recentEatingWindow: _selectedEatingWindow!,
                  recentFood: _recentFoodController.text.trim(),
                  askedAt: DateTime.now(),
                );

                contentProvider.addUserQuestion(question);
                _questionController.clear();
                _ageController.clear();
                _heightController.clear();
                _weightController.clear();
                _recentFoodController.clear();
                setState(() {
                  _selectedGender = null;
                  _selectedEatingWindow = null;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Question submitted! Our experts will reply soon.',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green[600],
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 22, 99, 167),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Ask Question',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildQuestionFieldDecoration(bool isDark, String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F1722) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[300]!,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(
          color: Color.fromARGB(255, 22, 99, 167),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.all(14),
    );
  }
}

class _DashboardAdCard extends StatelessWidget {
  final String title;
  final String description;
  final SlideItem? slide;
  final double horizontalMargin;

  const _DashboardAdCard({
    required this.title,
    required this.description,
    this.slide,
    this.horizontalMargin = 12,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = _buildImage();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      decoration: BoxDecoration(
        gradient: slide == null
            ? const LinearGradient(
                colors: [
                  Color.fromARGB(255, 22, 99, 167),
                  Color(0xFF4A90D9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: slide?.backgroundColor,
        borderRadius: BorderRadius.zero,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageWidget != null) imageWidget,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0E2A47).withValues(alpha: 0.18),
                    const Color(0xFF1563A7).withValues(alpha: 0.42),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Featured update',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildImage() {
    if (slide == null) {
      return null;
    }

    if (kIsWeb && slide!.imageBase64 != null && slide!.imageBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(slide!.imageBase64!),
        fit: BoxFit.cover,
      );
    }

    if (slide!.imageBase64 != null && slide!.imageBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(slide!.imageBase64!),
        fit: BoxFit.cover,
      );
    }

    if (!kIsWeb &&
        slide!.imagePath != null &&
        slide!.imagePath!.isNotEmpty &&
        File(slide!.imagePath!).existsSync()) {
      return Image.file(
        File(slide!.imagePath!),
        fit: BoxFit.cover,
      );
    }

    return null;
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected
              ? const Color.fromARGB(255, 22, 99, 167)
              : Colors.blueGrey[400],
        ),
      ),
    );
  }
}


















