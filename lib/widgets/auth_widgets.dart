import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    required this.controller,
    this.validator,
    this.onChanged,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          onChanged: widget.onChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: GoogleFonts.poppins(
              color: isDark ? Colors.black54 : Colors.grey[400],
              fontSize: 13,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: Colors.blue[600],
            ),
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.black54 : Colors.grey[400],
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.white : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final double width;
  final Color color;
  final Color textColor;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width = double.infinity,
    this.color = Colors.blue,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            disabledBackgroundColor: Colors.grey[400],
            elevation: 0,
            overlayColor: Colors.black.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double width;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.blue[600]!),
            overlayColor: Colors.blue.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.blue[600],
            ),
          ),
        ),
      );
}

class RoleSelector extends StatefulWidget {
  final String selectedRole;
  final Function(String) onRoleSelected;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  State<RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<RoleSelector> {
  String? _pressedRole;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Role',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressedRole = 'user'),
                  onTapUp: (_) {
                    setState(() => _pressedRole = null);
                    widget.onRoleSelected('user');
                  },
                  onTapCancel: () => setState(() => _pressedRole = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _pressedRole == 'user'
                          ? (widget.selectedRole == 'user'
                              ? Colors.blue[100]
                              : Colors.grey[200])
                          : (widget.selectedRole == 'user'
                              ? Colors.blue[50]
                              : Colors.grey[50]),
                      border: Border.all(
                        color: widget.selectedRole == 'user'
                            ? Colors.blue[600]!
                            : Colors.grey[300]!,
                        width: widget.selectedRole == 'user' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person,
                          size: 32,
                          color: widget.selectedRole == 'user'
                              ? Colors.blue[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'User',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.selectedRole == 'user'
                                ? Colors.blue[600]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressedRole = 'admin'),
                  onTapUp: (_) {
                    setState(() => _pressedRole = null);
                    widget.onRoleSelected('admin');
                  },
                  onTapCancel: () => setState(() => _pressedRole = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _pressedRole == 'admin'
                          ? (widget.selectedRole == 'admin'
                              ? Colors.orange[100]
                              : Colors.grey[200])
                          : (widget.selectedRole == 'admin'
                              ? Colors.orange[50]
                              : Colors.grey[50]),
                      border: Border.all(
                        color: widget.selectedRole == 'admin'
                            ? Colors.orange[600]!
                            : Colors.grey[300]!,
                        width: widget.selectedRole == 'admin' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 32,
                          color: widget.selectedRole == 'admin'
                              ? Colors.orange[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Admin',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.selectedRole == 'admin'
                                ? Colors.orange[600]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
