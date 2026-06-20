import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'employees_screen.dart';
import 'attendance_screen.dart';
import 'meetings_screen.dart';
import 'more_screen.dart';

class AdminMain extends StatefulWidget {
  const AdminMain({super.key});
  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int _index = 0;
  // Separate navigator key for the More tab so back-presses stay in-tab
  final _moreNavKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (_index == 4 && (_moreNavKey.currentState?.canPop() ?? false)) {
          _moreNavKey.currentState!.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: IndexedStack(
          index: _index,
          children: [
            const AdminDashboard(),
            const EmployeesScreen(),
            const AttendanceScreen(),
            const MeetingsScreen(),
            // More tab gets its own nested Navigator so sub-screens
            // push within the tab and the bottom nav stays visible
            HeroControllerScope(
              controller: MaterialApp.createMaterialHeroController(),
              child: Navigator(
                key: _moreNavKey,
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => const MoreScreen(),
                ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFF1A1A2E),
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Employees',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'More',
            ),
          ],
        ),
      ),
      ),
    );
  }
}
