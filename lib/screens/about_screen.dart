import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : const Color(0xFF102A43);
    final portfolioUrl = Uri.parse(
      'https://dindinachhakchhuak91-source.github.io/Portfolio/',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Developer',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dindina',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Contact',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'dindinachhakchhuak91@gmail.com',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Website',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => launchUrl(
                portfolioUrl,
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                portfolioUrl.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF1563A7),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
