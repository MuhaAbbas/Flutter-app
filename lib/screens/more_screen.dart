import 'package:flutter/material.dart';
import 'activity_logs_screen.dart';
import 'payroll_screen.dart';
import 'salary_setup_screen.dart';
import 'send_notification_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(
        icon: Icons.bar_chart_rounded,
        label: 'Activity Logs',
        subtitle: 'View daily employee activities',
        color: Colors.teal,
        screen: const ActivityLogsScreen(),
      ),
      _MoreItem(
        icon: Icons.payments_outlined,
        label: 'Payroll',
        subtitle: 'Manage employee payroll',
        color: const Color(0xFF3B82F6),
        screen: const PayrollScreen(),
      ),
      _MoreItem(
        icon: Icons.settings_outlined,
        label: 'Salary Setup',
        subtitle: 'Configure salary structures',
        color: Colors.purple,
        screen: const SalarySetupScreen(),
      ),
      _MoreItem(
        icon: Icons.notifications_outlined,
        label: 'Send Notification',
        subtitle: 'Notify employees or assign tasks',
        color: Colors.orange,
        screen: const SendNotificationScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('More',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: items.map((item) => _MoreCard(item: item)).toList(),
        ),
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Widget screen;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.screen,
  });
}

class _MoreCard extends StatelessWidget {
  final _MoreItem item;
  const _MoreCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.screen),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
