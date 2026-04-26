import 'package:flutter/material.dart';

List<String> _parseBulletPoints(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

Color _parseBackgroundColor(dynamic value) {
  final colorValue = int.tryParse(value?.toString() ?? '');
  if (colorValue == null) {
    return Colors.blue;
  }
  return Color(colorValue);
}

/// Represents content displayed in the expandable box under each section.
class SectionContentItem {
  final String id;
  final String sectionId; // Links to a SectionItem
  final String title;
  final String description;
  final String? imageUrl;
  final double? imageAspectRatio;
  final double imageDisplayHeight;
  final List<String> bulletPoints; // Additional details
  final Color backgroundColor;

  SectionContentItem({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.imageAspectRatio,
    this.imageDisplayHeight = 200,
    this.bulletPoints = const [],
    this.backgroundColor = Colors.blue,
  });

  factory SectionContentItem.fromJson(Map<String, dynamic> json) =>
      SectionContentItem(
        id: json['id']?.toString() ?? '',
        sectionId: json['section_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        imageUrl: json['image_url']?.toString(),
        imageAspectRatio:
            double.tryParse(json['image_aspect_ratio']?.toString() ?? ''),
        imageDisplayHeight:
            double.tryParse(json['image_display_height']?.toString() ?? '') ??
                200,
        bulletPoints: _parseBulletPoints(json['bullet_points']),
        backgroundColor: _parseBackgroundColor(json['background_color']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'section_id': sectionId,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'image_aspect_ratio': imageAspectRatio,
        'image_display_height': imageDisplayHeight,
        'bullet_points': bulletPoints,
        'background_color': backgroundColor.toARGB32().toString(),
      };

  SectionContentItem copyWith({
    String? id,
    String? sectionId,
    String? title,
    String? description,
    String? imageUrl,
    double? imageAspectRatio,
    double? imageDisplayHeight,
    List<String>? bulletPoints,
    Color? backgroundColor,
  }) =>
      SectionContentItem(
        id: id ?? this.id,
        sectionId: sectionId ?? this.sectionId,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
        imageDisplayHeight: imageDisplayHeight ?? this.imageDisplayHeight,
        bulletPoints: bulletPoints ?? this.bulletPoints,
        backgroundColor: backgroundColor ?? this.backgroundColor,
      );
}
