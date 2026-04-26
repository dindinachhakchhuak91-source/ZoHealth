import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'about_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  final bool showAppBar;

  const UserSettingsScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  late final TextEditingController _nameController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _nameController.text =
          context.read<AuthProvider>().currentUser?.fullName ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    final success = await authProvider.updateProfile(fullName: name);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Username updated' : authProvider.errorMessage ?? 'Update failed',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SafeArea(
      top: !widget.showAppBar,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.showAppBar)
              Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (!widget.showAppBar) const SizedBox(height: 16),
            _SettingsSection(
              title: 'Profile',
              subtitle: 'Update your display name and basic preferences.',
              initiallyExpanded: true,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _saveName,
                    child: Text(
                      authProvider.isLoading ? 'Saving...' : 'Save Username',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Appearance',
              subtitle: 'Choose how the app should look.',
              children: [
                SwitchListTile(
                  value: themeProvider.themeMode == ThemeMode.dark ||
                      (themeProvider.themeMode == ThemeMode.system && isDark),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Dark mode',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Switch between light and dark theme.',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onChanged: (value) {
                    themeProvider.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'More Settings',
              subtitle: 'Reserved for future user options and app preferences.',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    'About',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Developer and contact details',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AboutScreen(),
                      ),
                    );
                  },
                ),
                const _FutureTile(
                  title: 'Notifications',
                  subtitle: 'Coming soon',
                ),
                const _FutureTile(
                  title: 'Privacy controls',
                  subtitle: 'Coming soon',
                ),
                const _FutureTile(
                  title: 'Language and region',
                  subtitle: 'Coming soon',
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: content,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _FutureTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FutureTile({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.tune),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
      );
}


