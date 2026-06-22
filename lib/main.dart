import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'screens/login_screen.dart';
import 'screens/admin_main.dart';
import 'screens/employee_main.dart';
import 'theme/app_theme.dart' as theme_pkg;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.load();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Attendance System',
        debugShowCheckedModeBanner: false,
        theme: theme_pkg.AppTheme.light,
        darkTheme: theme_pkg.AppTheme.dark,
        themeMode: mode,
        home: const _SplashRouter(),
      ),
    );
  }
}

Widget dashboardForUser() {
  final user = AuthService().currentUser;
  if (user == null) return const LoginScreen();
  if (user.isAdminOrHod) return const AdminMain();
  return const EmployeeMain();
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService().tryAutoLogin();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => loggedIn ? dashboardForUser() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 64, color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }
}
