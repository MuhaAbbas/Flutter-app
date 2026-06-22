import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? bottom;
  final double bottomHeight;
  final bool showBack;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.bottomHeight = 0,
    this.showBack = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(56 + bottomHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSecondary, size: 18),
                  )
                else
                  const SizedBox(width: 20),
                Expanded(
                  child: Text(title, style: GoogleFonts.poppins(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                if (actions != null) ...actions!,
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (bottom != null) bottom!,
          const Divider(height: 1, color: AppTheme.divider),
        ],
      ),
    );
  }
}
