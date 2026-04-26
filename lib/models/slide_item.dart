import 'package:flutter/material.dart';

/// A simple model representing one of the banner/advertisement slides that
/// sits on top of the user dashboard.  When the user taps the slide the app
/// will navigate to the associated [route].
Color _parseSlideColor(dynamic value) {
  final colorValue = int.tryParse(value?.toString() ?? '');
  if (colorValue == null) {
    return Colors.blueAccent;
  }
  return Color(colorValue);
}

class SlideItem {
  final String id;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final String route;
  final String? imagePath; // Optional image path for native platforms
  final String? imageBase64; // Optional base64 encoded image for web
  final double imageWidth; // Image width in pixels
  final double imageHeight; // Image height in pixels

  SlideItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.route,
    this.imagePath,
    this.imageBase64,
    this.imageWidth = 800,
    this.imageHeight = 400,
  });

  factory SlideItem.fromJson(Map<String, dynamic> json) => SlideItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        backgroundColor: _parseSlideColor(json['background_color']),
        route: json['route']?.toString() ?? '',
        imagePath: json['image_path']?.toString(),
        imageBase64: json['image_base64']?.toString(),
        imageWidth: double.tryParse(json['image_width']?.toString() ?? '') ??
            800,
        imageHeight: double.tryParse(json['image_height']?.toString() ?? '') ??
            400,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'background_color': backgroundColor.toARGB32().toString(),
        'route': route,
        'image_path': imagePath,
        'image_base64': imageBase64,
        'image_width': imageWidth,
        'image_height': imageHeight,
      };
}
