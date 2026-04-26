import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/food_info_service.dart';

class FoodDetailScreen extends StatelessWidget {
  final String foodName;

  const FoodDetailScreen({
    super.key,
    required this.foodName,
  });

  @override
  Widget build(BuildContext context) {
    final food = FoodInfoService.getFood(foodName);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          food.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    food.accent,
                    food.accent.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      food.icon,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    food.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    food.serving,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DetailCard(
              title: 'Description',
              child: Text(
                food.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Nutrition Values',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: food.nutrition.entries
                    .map(
                      (entry) => Container(
                        width: 150,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.value,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF102A43),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Why It Helps',
              child: Column(
                children: food.benefits
                    .map(
                      (benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 10),
                              height: 8,
                              width: 8,
                              decoration: BoxDecoration(
                                color: food.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                benefit,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
