import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'child_growth_tracker_screen.dart';
import 'micronutrition_tracker_screen.dart';

class GrowthMicronutritionScreen extends StatelessWidget {
  const GrowthMicronutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1563A7);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Growth & Micronutrients',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF091525), Color(0xFF0F2339)]
                : const [Color(0xFFF3F8FE), Color(0xFFEAF2FB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 132 + bottomInset),
          children: [
            _SectionCard(
              accent: accent,
              isDark: isDark,
              icon: Icons.trending_up,
              title: 'Growth',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChildGrowthTrackerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _SectionCard(
              accent: accent,
              isDark: isDark,
              icon: Icons.health_and_safety_outlined,
              title: 'Micronutrients',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MicronutritionTrackerScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color accent;
  final bool isDark;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SectionCard({
    required this.accent,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF122740), Color(0xFF0E1F34)]
                  : const [Color(0xFFDCEBFA), Color(0xFFD0E3F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF2A4566) : const Color(0xFF95BCE1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white24
                        : accent.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? Colors.white70 : accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


