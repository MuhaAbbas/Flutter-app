import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'admin_dashboard.dart';
import 'employees_screen.dart';
import 'attendance_screen.dart';
import 'meetings_screen.dart';
import 'activity_logs_screen.dart';
import 'payroll_screen.dart';
import 'salary_setup_screen.dart';
import 'send_notification_screen.dart';
import 'login_screen.dart';

class AdminMain extends StatefulWidget {
  const AdminMain({super.key});
  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int _index = 0;
  bool _extended = false;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.people_outline, active: Icons.people, label: 'Employees'),
    (icon: Icons.event_note_outlined, active: Icons.event_note, label: 'Attendance'),
    (icon: Icons.location_on_outlined, active: Icons.location_on, label: 'Meetings'),
    (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Activity'),
    (icon: Icons.payments_outlined, active: Icons.payments, label: 'Payroll'),
    (icon: Icons.settings_outlined, active: Icons.settings, label: 'Salary Setup'),
    (icon: Icons.notifications_outlined, active: Icons.notifications, label: 'Notify'),
  ];

  void _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          _buildRail(),
          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                AdminDashboard(),
                EmployeesScreen(),
                AttendanceScreen(),
                MeetingsScreen(),
                ActivityLogsScreen(),
                PayrollScreen(),
                SalarySetupScreen(),
                SendNotificationScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _extended ? 200 : 72,
      color: AppTheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _railHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _destinations.length,
              itemBuilder: (_, i) => _railItem(i),
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          _logoutItem(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _railHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _extended = !_extended),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _extended ? Icons.menu_open : Icons.menu,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
          if (_extended) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text('Admin', style: GoogleFonts.poppins(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _railItem(int i) {
    final d = _destinations[i];
    final selected = _index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        onTap: () => setState(() => _index = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: _extended ? 12 : 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: _extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                selected ? d.active : d.icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 20,
              ),
              if (_extended) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.label, style: GoogleFonts.inter(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ), overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _extended ? 12 : 8, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: _extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: Color(0xFFF87171), size: 20),
              if (_extended) ...[
                const SizedBox(width: 10),
                Text('Logout', style: GoogleFonts.inter(
                  color: const Color(0xFFF87171),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
