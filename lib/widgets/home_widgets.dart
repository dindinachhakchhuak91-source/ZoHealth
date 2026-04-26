import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../providers/content_provider.dart';

/// A simple carousel that displays the slides from [ContentProvider].  A
/// row of dots below the page view indicates the current position.
class AdsCarousel extends StatefulWidget {
  final Function(String)? onSlideTapped;

  const AdsCarousel({super.key, this.onSlideTapped});

  @override
  State<AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<AdsCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late Timer _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_controller.hasClients) {
        final slides = context.read<ContentProvider>().slides;
        final nextPage = (_currentPage + 1) % slides.length;
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _goToPreviousSlide() {
    final slides = context.read<ContentProvider>().slides;
    final previousPage = (_currentPage - 1 + slides.length) % slides.length;
    _controller.animateToPage(
      previousPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextSlide() {
    final slides = context.read<ContentProvider>().slides;
    final nextPage = (_currentPage + 1) % slides.length;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _autoSlideTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = context.watch<ContentProvider>().slides;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              // Carousel
              PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return GestureDetector(
                    onTap: () {
                      widget.onSlideTapped?.call(slide.title);
                    },
                    child: Container(
                      margin: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                      child: (slide.imagePath != null ||
                              slide.imageBase64 != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  // Image background - fills entire area
                                  if (kIsWeb && slide.imageBase64 != null)
                                    Image.memory(
                                      base64Decode(slide.imageBase64!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  else if (slide.imagePath != null)
                                    Image.file(
                                      File(slide.imagePath!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  else if (slide.imageBase64 != null)
                                    Image.memory(
                                      base64Decode(slide.imageBase64!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  // Dark overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  // Text overlay
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          slide.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          slide.subtitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: slide.backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      slide.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slide.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              // Left Arrow Button (Overlay)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _goToPreviousSlide,
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.white,
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              // Right Arrow Button (Overlay)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _goToNextSlide,
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.white,
                    iconSize: 32,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(slides.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 12 : 8,
              height: _currentPage == index ? 12 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.blue : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Horizontal row of section shortcuts displayed as pills/chips with icon and text.
/// Tapping a tile calls [onSectionTapped] with the section title.  Icons and titles come from
/// [ContentProvider] so that they can be dynamically changed later by the
/// administrator.
class SectionMenu extends StatefulWidget {
  final Function(String)? onSectionTapped;
  final String? selectedSection;

  const SectionMenu({
    super.key,
    this.onSectionTapped,
    this.selectedSection,
  });

  @override
  State<SectionMenu> createState() => _SectionMenuState();
}

class _SectionMenuState extends State<SectionMenu> {
  String? _pressedSection;

  @override
  Widget build(BuildContext context) {
    final sections = context.watch<ContentProvider>().sections;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 60,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              ...sections.map((section) {
                final isPressed = _pressedSection == section.title;
                final isSelected = widget.selectedSection == section.title;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isPressed ? 0.93 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutBack,
                    child: GestureDetector(
                      onTapDown: (_) {
                        setState(() => _pressedSection = section.title);
                      },
                      onTapUp: (_) {
                        setState(() => _pressedSection = null);
                      },
                      onTapCancel: () {
                        setState(() => _pressedSection = null);
                      },
                      onTap: () {
                        widget.onSectionTapped?.call(section.title);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isPressed || isSelected
                              ? (isDark
                                  ? const Color(0xFF2A3A4E)
                                  : const Color.fromARGB(255, 159, 159, 159))
                              : (isDark ? const Color(0xFF162231) : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF32465E) : Colors.grey[300]!,
                            width: 1,
                          ),
                          boxShadow: isPressed
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              section.icon,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.blueGrey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              section.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable content box for each section with fixed and expanded states.
/// The box shows a preview of the content with a "See More" button in the bottom right corner.
/// Clicking it expands to show full content.
class ExpandableContentBox extends StatefulWidget {
  final String title;
  final String description;
  final List<String> bulletPoints;
  final Color backgroundColor;
  final String? imageUrl;
  final double? imageAspectRatio;
  final double imageDisplayHeight;

  const ExpandableContentBox({
    super.key,
    required this.title,
    required this.description,
    this.bulletPoints = const [],
    this.backgroundColor = Colors.blue,
    this.imageUrl,
    this.imageAspectRatio,
    this.imageDisplayHeight = 200,
  });

  @override
  State<ExpandableContentBox> createState() => _ExpandableContentBoxState();
}

class _ExpandableContentBoxState extends State<ExpandableContentBox> {
  bool _isExpanded = false;
  final GlobalKey _cardKey = GlobalKey();

  void _toggleExpanded() {
    final shouldExpand = !_isExpanded;
    setState(() => _isExpanded = shouldExpand);

    if (!shouldExpand) return;

    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || !context.mounted) return;
      final cardContext = _cardKey.currentContext;
      if (cardContext == null) return;

      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _toggleExpanded,
          child: Container(
            key: _cardKey,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162231) : const Color(0xFFFCFCFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2A3A4E) : Colors.grey[200]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                    _buildImageFrame(widget.imageUrl!),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isExpanded ? 'Tap to collapse' : 'Tap to expand',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.bulletPoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...widget.bulletPoints.map((point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6, right: 8),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: widget.backgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to build image widget handling base64, file paths, and network URLs
  Widget _buildImageWidget(String imageUrl) {
    try {
      // Handle base64 encoded images (web and desktop)
      if (imageUrl.startsWith('data:image')) {
        try {
          // Extract base64 string after the comma
          final parts = imageUrl.split(',');
          if (parts.length < 2) {
            return _buildErrorImage('Invalid base64 format');
          }
          final base64String = parts.last;
          debugPrint('Decoding base64 image, length: ${base64String.length}');
          final bytes = base64Decode(base64String);
          debugPrint('Decoded image bytes, size: ${bytes.length}');
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text(
                          'Image failed to load',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        } catch (e) {
          return _buildErrorImage('Invalid base64 data: ${e.toString()}');
        }
      }

      // Handle file paths (desktop)
      if (!kIsWeb) {
        final file = File(imageUrl);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildErrorImage('File not accessible'),
            ),
          );
        }
      }

      // Handle network URLs
      if (imageUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildErrorImage('Network error'),
          ),
        );
      }

      return _buildErrorImage('Unknown image format');
    } catch (e) {
      return _buildErrorImage('Error loading image');
    }
  }

  Widget _buildImageFrame(String imageUrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final resolvedHeight = isDesktop
        ? widget.imageDisplayHeight.clamp(90.0, 130.0).toDouble()
        : widget.imageDisplayHeight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A3A4E)
              : Colors.grey[300]!,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: resolvedHeight,
          child: _buildImageWidget(imageUrl),
        ),
      ),
    );
  }

  /// Helper to build error state image widget
  Widget _buildErrorImage(String error) {
    return Container(
      color: Colors.red[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.red[300], size: 40),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}






