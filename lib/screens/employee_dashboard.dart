import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  final VoidCallback? onRequestMeeting;
  const EmployeeDashboard({super.key, this.onRequestMeeting});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  AttendanceRecord? _todayAttendance;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentAttendance = [];
  bool _loading = true;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final results = await Future.wait([
      ApiService().getMyTodayAttendance(),
      ApiService().getMyMonthlyStats(month: now.month, year: now.year),
      ApiService().getMyAttendanceHistory(month: now.month, year: now.year),
    ]);
    setState(() {
      _todayAttendance = results[0] as AttendanceRecord?;
      _stats = results[1] as Map<String, dynamic>;
      final historyData = results[2] as Map<String, dynamic>;
      final raw = historyData['records'] as List<Map<String, dynamic>>;
      _recentAttendance = raw.take(5).toList();
      _loading = false;
    });
  }

  Future<void> _handleCheckInOut() async {
    setState(() => _checkingIn = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) throw Exception('GPS location nahi mili');
      if (_todayAttendance == null || !_todayAttendance!.isCheckedIn) {
        final record = await ApiService().checkIn(pos.latitude, pos.longitude);
        setState(() => _todayAttendance = record);
        _snack('Check-in successful!', Colors.green);
      } else {
        final record = await ApiService().checkOut(pos.latitude, pos.longitude);
        setState(() => _todayAttendance = record);
        _snack('Check-out successful!', Colors.orange);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      setState(() => _checkingIn = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final firstName = user?.fullName.split(' ').first ?? 'User';
    final fullName = user?.fullName ?? 'User';
    final initials = fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
    final now = DateTime.now();
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final dateStr = '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}';
    final monthLabel = '${monthNames[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF374151)),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF374151)),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'profile') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              } else if (val == 'logout') {
                _logout();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3B82F6),
                child: Text(initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827), fontSize: 13)),
                    Text(user?.role ?? '', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'profile', child: Text('My Profile')),
              const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome
                    Text('Welcome back,', style: TextStyle(color: const Color(0xFF6B7280), fontSize: 14)),
                    Text('$firstName!',
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(dateStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    const SizedBox(height: 16),

                    // Today's Attendance card
                    _buildAttendanceCard(),
                    const SizedBox(height: 16),

                    // Monthly stats
                    _buildMonthlyStats(monthLabel),
                    const SizedBox(height: 16),

                    // Recent Attendance
                    _buildRecentAttendance(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAttendanceCard() {
    final att = _todayAttendance;
    final isCheckedIn = att?.isCheckedIn ?? false;
    final isCheckedOut = att?.isCheckedOut ?? false;
    final notCheckedIn = att == null;
    final checkInTime = att?.checkInTimeStr ?? '';

    String statusLabel = 'Not Checked In';
    Color statusBg = const Color(0xFFF3F4F6);
    Color statusText = const Color(0xFF6B7280);
    if (isCheckedIn && !isCheckedOut) {
      statusLabel = 'Checked In';
      statusBg = const Color(0xFFD1FAE5);
      statusText = const Color(0xFF059669);
    } else if (isCheckedOut) {
      statusLabel = 'Checked Out';
      statusBg = const Color(0xFFDBEAFE);
      statusText = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Today\'s Attendance',
                  style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(color: statusText, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (checkInTime.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Check-in: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              TextSpan(text: checkInTime, style: const TextStyle(color: Color(0xFF111827), fontSize: 13, fontWeight: FontWeight.bold)),
            ])),
          ],
          if (!isCheckedOut) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checkingIn ? null : _handleCheckInOut,
                icon: _checkingIn
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(notCheckedIn || !isCheckedIn ? Icons.login : Icons.logout,
                        color: Colors.white, size: 18),
                label: Text(
                  _checkingIn ? 'Please wait...'
                      : (notCheckedIn || !isCheckedIn ? 'Check In' : 'Check Out'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: notCheckedIn || !isCheckedIn ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (isCheckedOut && att != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Total: ${(att.duration ?? 0) ~/ 60}h ${(att.duration ?? 0) % 60}m',
                style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              const Text('Location access required for check-in',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats(String monthLabel) {
    final present = _stats['present'] ?? _stats['presentDays'] ?? 0;
    final late = _stats['late'] ?? _stats['lateDays'] ?? 0;
    final absent = _stats['absent'] ?? _stats['absentDays'] ?? 0;
    final leave = _stats['leave'] ?? _stats['leaveDays'] ?? _stats['halfDay'] ?? 0;
    final km = (_stats['totalKm'] ?? _stats['kmTravelled'] ?? 0.0).toDouble();
    final lateFine = (_stats['lateFine'] ?? _stats['fineAmount'] ?? 0.0).toDouble();
    final absentFine = (_stats['absentFine'] ?? 0.0).toDouble();
    final totalFine = lateFine + absentFine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_outlined, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(monthLabel,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [
            _statCard('$present', 'Present', const Color(0xFF059669), const Color(0xFFF0FDF4)),
            _statCardWithSub('$late', 'Late', 'Fine: PKR ${_fmtAmt(lateFine)}',
                const Color(0xFFF59E0B), const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
            _statCardWithSub('$absent', 'Absent', 'Fine: PKR ${_fmtAmt(absentFine)}',
                const Color(0xFFEF4444), const Color(0xFFFFF5F5), const Color(0xFFEF4444)),
            _statCard('$leave', 'Leave / Half-day', const Color(0xFF6366F1), const Color(0xFFF5F3FF)),
            _statCard('${km.toStringAsFixed(2)} km', 'KM Travelled',
                const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
            _visitButton(),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('TOTAL FINE THIS MONTH',
                        style: TextStyle(color: Color(0xFFE53E3E), fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(height: 2),
                    Text('Late + Absent combined',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                  ],
                ),
              ),
              Text('PKR ${_fmtAmt(totalFine)}',
                  style: const TextStyle(color: Color(0xFFE53E3E), fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statCardWithSub(String value, String label, String sub, Color textColor, Color bgColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          Text(sub, style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _visitButton() {
    return GestureDetector(
      onTap: widget.onRequestMeeting,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('+ Visit', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 2),
            Text('Request Meeting', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAttendance() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text('Recent Attendance',
                    style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('View all', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          if (_recentAttendance.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No attendance records', style: TextStyle(color: Color(0xFF9CA3AF)))),
            )
          else
            ..._recentAttendance.asMap().entries.map((e) {
              final idx = e.key;
              final r = e.value;
              return Column(
                children: [
                  _attendanceRow(r),
                  if (idx < _recentAttendance.length - 1)
                    const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _attendanceRow(Map<String, dynamic> r) {
    final dateStr = _fmtShortDate(r['date'] ?? r['checkIn'] ?? '');
    final checkIn = _fmtTime(r['checkIn'] ?? r['checkInTime'] ?? '');
    final checkOut = _fmtTime(r['checkOut'] ?? r['checkOutTime'] ?? '');
    final duration = r['totalHours'] ?? r['duration'];
    String durationStr = '';
    if (duration != null) {
      final mins = (duration is num ? duration.toInt() : int.tryParse('$duration') ?? 0);
      durationStr = '${mins ~/ 60}h${mins % 60 > 0 ? ' ${mins % 60}m' : ''}';
    }
    final status = (r['status'] ?? 'present').toString().toLowerCase();
    Color statusBg = const Color(0xFFD1FAE5);
    Color statusText = const Color(0xFF059669);
    if (status == 'absent') { statusBg = const Color(0xFFFFE4E6); statusText = const Color(0xFFEF4444); }
    if (status == 'late') { statusBg = const Color(0xFFFEF3C7); statusText = const Color(0xFFF59E0B); }
    if (status == 'leave') { statusBg = const Color(0xFFEDE9FE); statusText = const Color(0xFF7C3AED); }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  checkIn.isNotEmpty
                      ? (checkOut.isNotEmpty ? 'In: $checkIn · Out: $checkOut' : 'In: $checkIn')
                      : '—',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          if (durationStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(durationStr, style: const TextStyle(color: Color(0xFF374151), fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: statusText, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fmtShortDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return iso;
    }
  }

  String _fmtAmt(double amt) {
    if (amt == 0) return '0';
    return amt.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
