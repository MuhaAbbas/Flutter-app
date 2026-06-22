import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> tabs;
  final TabController controller;
  final bool? isScrollable;

  const CustomTabBar({super.key, required this.tabs, required this.controller, this.isScrollable});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final scrollable = isScrollable ?? tabs.length > 4;
    return Container(
      color: AppTheme.surface,
      height: 44,
      child: TabBar(
        controller: controller,
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
          insets: EdgeInsets.zero,
        ),
        dividerColor: AppTheme.divider,
        tabs: tabs.map((t) => Tab(text: t, height: 44)).toList(),
      ),
    );
  }
}
