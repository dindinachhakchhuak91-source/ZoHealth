import 'package:flutter/material.dart';

/// Represents an entry in the row of quick‑access sections beneath the
/// carousel.  The admin will eventually be able to change the list, but
/// for the purposes of the dashboard we simply expose a static list.
class SectionItem {
  final String id;
  final String title;
  final IconData icon;
  final String route;

  SectionItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.route,
  });
}
