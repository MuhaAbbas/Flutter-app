import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  TodayStats _stats = TodayStats.empty();
  List<Map<String, dynamic>> _activeVisits = [];
  List<Map<String, dynamic>> _absentEmployees = [];
  List<Map<String, dynamic>> _holidays = [];
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  int _extrasTab = 0;

  // Holiday form
  final _holidayNameCtrl = TextEditingController();
  String _holidayYear = DateTime.now().year.toString();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _addingHoliday = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _holidayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService().getTodayStats(),
      ApiService().getActiveVisits(),
      ApiService().getAbsentToday(),
      ApiService().getHolidays(year: DateTime.now().year),
      ApiService().getSettings(),
    ]);
    setState(() {
      _stats = results[0] as TodayStats;
      _activeVisits = results[1] as List<Map<String, dynamic>>;
      _absentEmployees = results[2] as List<Map<String, dynamic>>;
      _holidays = results[3] as List<Map<String, dynamic>>;
      _settings = results[4] as Map<String, dynamic>;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(user?.fullName ?? 'Admin', user?.role ?? '', dateStr),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildTeamToday(),
                        const SizedBox(height: 16),
                        _buildActiveVisits(),
                        const SizedBox(height: 16),
                        _buildAbsentList(),
                        const SizedBox(height: 16),
                        _buildExtrasSection(),
                        const SizedBox(height: 16),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar(String name, String role, String date) {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A2E),
      actions: [
        IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.white70)),
        PopupMenuButton<String>(
          color: const Color(0xFF1E293B),
          offset: const Offset(0, 48),
          onSelected: (val) {
            if (val == 'profile') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            } else if (val == 'logout') {
              _logout();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(role.replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.orange, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: Colors.white70, size: 16),
                  SizedBox(width: 10),
                  Text('My Profile', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 16),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                ),
                child: Text(role.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text('Welcome back, $name!',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              Text(date, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamToday() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.groups, color: Colors.white54, size: 16),
            SizedBox(width: 6),
            Text('TEAM TODAY', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('Present', _stats.present, Colors.green),
            const SizedBox(width: 10),
            _statCard('Late', _stats.late, Colors.orange),
            const SizedBox(width: 10),
            _statCard('Absent', _stats.absent, Colors.red),
            const SizedBox(width: 10),
            _statCard('Leave', _stats.onLeave, const Color(0xFF3B82F6)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVisits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            const Text('ACTIVE VISITS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_activeVisits.length} active',
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_activeVisits.isEmpty)
          _emptyCard('No active visits right now', Icons.map_outlined)
        else
          ..._activeVisits.take(5).map((v) => _activeVisitRow(v)),
      ],
    );
  }

  Widget _activeVisitRow(Map<String, dynamic> v) {
    final name = v['userName'] ?? 'Employee';
    final status = (v['status'] ?? '').toString().replaceAll('_', ' ');
    final liveKm = v['liveKm'] != null ? '${double.tryParse(v['liveKm'].toString())?.toStringAsFixed(1) ?? 0} km' : '0 km';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(status, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.directions_car, color: Colors.green, size: 14),
              Text(liveKm, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbsentList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_off, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            const Text('ABSENT TODAY', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const Spacer(),
            Text('${_absentEmployees.length}', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        if (_absentEmployees.isEmpty)
          _emptyCard('All employees present!', Icons.check_circle_outline)
        else
          ..._absentEmployees.take(6).map((e) => _absentRow(e)),
      ],
    );
  }

  Widget _absentRow(Map<String, dynamic> e) {
    final name = (e['userName'] ?? '').toString().trim();
    final dept = e['userDepartment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.red.withValues(alpha: 0.15),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                if (dept.isNotEmpty)
                  Text(dept, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.circle, color: Colors.red, size: 8),
        ],
      ),
    );
  }

  // ── EXTRAS SECTION (Public Holidays + WhatsApp) ──────────────────────────────

  Widget _buildExtrasSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          // Tab switcher
          Row(
            children: [
              _extraTab(0, Icons.beach_access_outlined, 'Public Holidays'),
              _extraTab(1, Icons.chat_outlined, 'WhatsApp'),
            ],
          ),
          const Divider(color: Colors.white12, height: 1),
          // Content
          _extrasTab == 0 ? _buildHolidaysContent() : _buildWhatsAppContent(),
        ],
      ),
    );
  }

  Widget _extraTab(int index, IconData icon, String label) {
    final selected = _extrasTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _extrasTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? const Color(0xFF3B82F6) : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF3B82F6) : Colors.white38,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHolidaysContent() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add form
          TextField(
            controller: _holidayNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDeco('Holiday Name (e.g. Eid ul-Fitr)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _datePicker('Start Date', _startDate, (d) => setState(() => _startDate = d))),
              const SizedBox(width: 8),
              Expanded(child: _datePicker('End Date', _endDate, (d) => setState(() => _endDate = d))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addingHoliday ? null : _addHoliday,
              icon: _addingHoliday
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text('Add Holiday', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_holidays.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            ..._holidays.map((h) => _holidayRow(h)),
          ] else ...[
            const SizedBox(height: 12),
            const Center(child: Text('No holidays added yet', style: TextStyle(color: Colors.white38, fontSize: 12))),
          ],
        ],
      ),
    );
  }

  Widget _holidayRow(Map<String, dynamic> h) {
    final name = h['name'] ?? h['holidayName'] ?? '';
    final start = h['startDate'] ?? h['date'] ?? '';
    final end = h['endDate'] ?? start;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access, color: Color(0xFF3B82F6), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('$start${end != start ? ' → $end' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => _deleteHoliday(h['id']?.toString() ?? ''),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _addHoliday() async {
    if (_holidayNameCtrl.text.trim().isEmpty || _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Holiday name and start date required'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _addingHoliday = true);
    try {
      await ApiService().addHoliday({
        'name': _holidayNameCtrl.text.trim(),
        'year': int.parse(_holidayYear),
        'startDate': _startDate!.toIso8601String().substring(0, 10),
        'endDate': (_endDate ?? _startDate!).toIso8601String().substring(0, 10),
      });
      _holidayNameCtrl.clear();
      setState(() { _startDate = null; _endDate = null; });
      final h = await ApiService().getHolidays(year: DateTime.now().year);
      setState(() => _holidays = h);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _addingHoliday = false);
    }
  }

  Future<void> _deleteHoliday(String id) async {
    if (id.isEmpty) return;
    await ApiService().deleteHoliday(id);
    final h = await ApiService().getHolidays(year: DateTime.now().year);
    setState(() => _holidays = h);
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF3B82F6))),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
            const SizedBox(width: 6),
            Text(
              value != null ? '${value.day}/${value.month}/${value.year}' : label,
              style: TextStyle(color: value != null ? Colors.white : Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF0F172A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );

  Widget _buildWhatsAppContent() {
    final whatsapp = _settings['whatsapp'] as Map<String, dynamic>? ?? _settings;

    final toggles = [
      {'key': 'leaveRequest', 'label': 'Leave Request', 'desc': 'Notify admin when employee submits a leave'},
      {'key': 'missedAttendance', 'label': 'Missed Attendance', 'desc': 'Notify on missed attendance request'},
      {'key': 'meetingRequest', 'label': 'Meeting Request', 'desc': 'Notify on new meeting / visit request'},
      {'key': 'activityReport', 'label': 'Activity Report', 'desc': 'Notify on activity report submission'},
      {'key': 'publicHoliday', 'label': 'Public Holiday', 'desc': 'Notify all employees on new holiday'},
    ];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: toggles.map((t) {
          final key = t['key']!;
          final enabled = whatsapp[key] == true || whatsapp[key] == 1;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['label']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(t['desc']!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    activeColor: const Color(0xFF3B82F6),
                    onChanged: (v) async {
                      final updated = Map<String, dynamic>.from(whatsapp);
                      updated[key] = v;
                      setState(() {
                        if (_settings.containsKey('whatsapp')) {
                          _settings['whatsapp'] = updated;
                        } else {
                          _settings[key] = v;
                        }
                      });
                      await ApiService().updateSettings({'whatsapp': updated});
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 8),
          Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
