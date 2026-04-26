import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/content_provider.dart';

/// Display content for a given section with items, images, and description.
class SectionScreen extends StatelessWidget {
  final String title;

  const SectionScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final contentProvider = context.read<ContentProvider>();

    // Find the section ID from title
    final section = contentProvider.sections.firstWhere(
      (s) => s.title == title,
      orElse: () => contentProvider.sections.first,
    );

    // Get content for this section
    final contents = contentProvider.sectionContent
        .where((c) => c.sectionId == section.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
      ),
      body: contents.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No content available',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back soon for updates about "$title"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return SectionContentCard(content: content);
              },
            ),
    );
  }
}

/// Card widget for displaying section content with image, title, description, and bullet points
class SectionContentCard extends StatelessWidget {
  final dynamic content;

  const SectionContentCard({super.key, required this.content});

  bool _isBase64Image(String? url) {
    return url != null && url.startsWith('data:image');
  }

  Widget _buildImage(String? imageUrl) {
    final imageHeight = (content.imageDisplayHeight as double?) ?? 200;
    final imageAspectRatio = content.imageAspectRatio as double?;

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: imageHeight,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 50,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    // Handle base64 encoded images (web)
    if (_isBase64Image(imageUrl)) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        return _wrapImage(
          imageAspectRatio: imageAspectRatio,
          imageHeight: imageHeight,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        );
      } catch (e) {
        return _buildErrorImage();
      }
    }

    // Handle file paths (desktop)
    if (!kIsWeb && File(imageUrl).existsSync()) {
      return _wrapImage(
        imageAspectRatio: imageAspectRatio,
        imageHeight: imageHeight,
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    // Handle network URLs
    if (imageUrl.startsWith('http')) {
      return _wrapImage(
        imageAspectRatio: imageAspectRatio,
        imageHeight: imageHeight,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
        ),
      );
    }

    return _buildErrorImage();
  }

  Widget _buildErrorImage() {
    final imageHeight = (content.imageDisplayHeight as double?) ?? 200;
    final imageAspectRatio = content.imageAspectRatio as double?;

    return _wrapImage(
      imageAspectRatio: imageAspectRatio,
      imageHeight: imageHeight,
      child: Container(
        color: Colors.red[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 50,
                color: Colors.red[300],
              ),
              const SizedBox(height: 8),
              Text(
                'Image not available',
                style: GoogleFonts.poppins(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapImage({
    required Widget child,
    required double? imageAspectRatio,
    required double imageHeight,
  }) {
    final wrappedChild = imageAspectRatio != null
        ? AspectRatio(
            aspectRatio: imageAspectRatio,
            child: child,
          )
        : SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: child,
          );

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: wrappedChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (content.imageUrl != null && content.imageUrl.isNotEmpty)
            _buildImage(content.imageUrl)
          else
            Container(
              height: content.imageDisplayHeight,
              decoration: BoxDecoration(
                color: content.backgroundColor,
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 50,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  content.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  content.description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                if ((content.bulletPoints as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Bullet points
                  ...((content.bulletPoints as List<String>)
                      .map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.only(top: 6, right: 10),
                                decoration: BoxDecoration(
                                  color: content.backgroundColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  point,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
