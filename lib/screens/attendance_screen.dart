import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;

  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _attRequests = [];
  List<Map<String, dynamic>> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadForTab(_tabController.index);
    });
    _loadForTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForTab(int tab) async {
    setState(() => _loading = true);
    try {
      if (tab == 0) {
        final data = await ApiService().getAttendanceAll();
        setState(() {
          _stats = data['stats'] as Map<String, dynamic>? ?? {};
          final List list = data['records'] ?? data['items'] ?? data['attendance'] ?? [];
          _records = list.cast<Map<String, dynamic>>();
        });
      } else if (tab == 1) {
        final data = await ApiService().getAttendanceRequests();
        setState(() => _attRequests = data);
      } else if (tab == 2) {
        final data = await ApiService().getLeaveRequests();
        setState(() => _leaveRequests = data);
      }
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Attendance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
              onPressed: () => _loadForTab(_tabController.index),
              icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF3B82F6),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Records'),
            Tab(text: 'Att. Requests'),
            Tab(text: 'Leave Requests'),
            Tab(text: 'Import/Export'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecordsTab(),
                _buildAttRequestsTab(),
                _buildLeaveRequestsTab(),
                _buildImportExportTab(),
              ],
            ),
    );
  }

  // ── RECORDS TAB ──────────────────────────────────────────────────────────────

  Widget _buildRecordsTab() {
    final present = _stats['present'] ?? _stats['presentToday'] ?? 0;
    final absent = _stats['absent'] ?? _stats['absentToday'] ?? 0;
    final late = _stats['late'] ?? _stats['lateToday'] ?? 0;
    final total = _records.isNotEmpty ? _records.length : (_stats['total'] ?? 0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _statCard('Present', present, Colors.green),
              const SizedBox(width: 8),
              _statCard('Absent', absent, Colors.red),
              const SizedBox(width: 8),
              _statCard('Late', late, Colors.orange),
              const SizedBox(width: 8),
              _statCard('Total', total, const Color(0xFF3B82F6)),
            ],
          ),
        ),
        Expanded(
          child: _records.isEmpty
              ? const Center(child: Text('No records found', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _records.length,
                  itemBuilder: (_, i) => _recordCard(_records[i]),
                ),
        ),
      ],
    );
  }

  Widget _statCard(String label, dynamic value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> r) {
    final firstName = r['firstName'] ?? r['user']?['firstName'] ?? '';
    final lastName = r['lastName'] ?? r['user']?['lastName'] ?? '';
    final name = r['userName'] ?? '$firstName $lastName'.trim();
    final dept = r['departmentName'] ?? r['department']?['name'] ?? '';
    final date = _formatDate(r['date']?.toString() ?? '');
    final checkIn = _formatTime(r['checkInTime']?.toString());
    final checkOut = _formatTime(r['checkOutTime']?.toString());
    final status = (r['status'] ?? '').toString();

    Color statusColor = Colors.green;
    if (status == 'late') statusColor = Colors.orange;
    if (status == 'absent') statusColor = Colors.red;
    if (status == 'on_leave') statusColor = const Color(0xFF3B82F6);

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            child: Text(initial, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unknown' : name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${dept.isNotEmpty ? '$dept • ' : ''}$date',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.login, color: Colors.green, size: 12),
                    const SizedBox(width: 3),
                    Text(checkIn, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 10),
                    const Icon(Icons.logout, color: Colors.red, size: 12),
                    const SizedBox(width: 3),
                    Text(checkOut, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── ATT. REQUESTS TAB ────────────────────────────────────────────────────────

  Widget _buildAttRequestsTab() {
    return _attRequests.isEmpty
        ? const Center(child: Text('No attendance requests', style: TextStyle(color: Colors.white38)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _attRequests.length,
            itemBuilder: (_, i) => _attRequestCard(_attRequests[i]),
          );
  }

  Widget _attRequestCard(Map<String, dynamic> r) {
    final firstName = r['firstName'] ?? r['user']?['firstName'] ?? '';
    final lastName = r['lastName'] ?? r['user']?['lastName'] ?? '';
    final name = r['userName'] ?? '$firstName $lastName'.trim();
    final empId = r['employeeId'] ?? r['user']?['employeeId'] ?? '';
    final date = _formatDate(r['date']?.toString() ?? r['requestDate']?.toString() ?? '');
    final reason = r['reason'] ?? '';
    final status = (r['status'] ?? 'pending').toString();

    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Employee' : name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (empId.toString().isNotEmpty)
                      Text(empId.toString(), style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          if (reason.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _doAction(() => ApiService().approveAttendanceRequest(r['id']?.toString() ?? ''), 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _doAction(() => ApiService().rejectAttendanceRequest(r['id']?.toString() ?? ''), 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── LEAVE REQUESTS TAB ───────────────────────────────────────────────────────

  Widget _buildLeaveRequestsTab() {
    return _leaveRequests.isEmpty
        ? const Center(child: Text('No leave requests', style: TextStyle(color: Colors.white38)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _leaveRequests.length,
            itemBuilder: (_, i) => _leaveCard(_leaveRequests[i]),
          );
  }

  Widget _leaveCard(Map<String, dynamic> r) {
    final firstName = r['firstName'] ?? r['user']?['firstName'] ?? '';
    final lastName = r['lastName'] ?? r['user']?['lastName'] ?? '';
    final name = r['userName'] ?? '$firstName $lastName'.trim();
    final type = r['leaveType'] ?? r['type'] ?? '';
    final startDate = _formatDate(r['startDate']?.toString() ?? '');
    final endDate = _formatDate(r['endDate']?.toString() ?? '');
    final days = r['totalDays'] ?? r['days'] ?? '';
    final reason = r['reason'] ?? '';
    final status = (r['status'] ?? 'pending').toString();

    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Employee' : name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (type.toString().isNotEmpty)
                      Text(type.toString(), style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.date_range, color: Colors.white38, size: 13),
              const SizedBox(width: 4),
              Text('$startDate — $endDate', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (days.toString().isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('($days days)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ],
          ),
          if (reason.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _doAction(() => ApiService().approveLeaveRequest(r['id']?.toString() ?? ''), 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _doAction(() => ApiService().rejectLeaveRequest(r['id']?.toString() ?? ''), 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── IMPORT/EXPORT TAB ────────────────────────────────────────────────────────

  Widget _buildImportExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            title: 'Export Data',
            subtitle: 'Download as Excel or PDF',
            child: Column(
              children: [
                _exportBtn('Attendance Records', Icons.people_outline, Colors.green),
                const SizedBox(height: 8),
                _exportBtn('Activity Logs', Icons.timeline, Colors.orange),
                const SizedBox(height: 8),
                _exportBtn('Payroll Data', Icons.payments_outlined, const Color(0xFF3B82F6)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Import Data',
            subtitle: 'Upload CSV or XLSX to bulk-import records',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSnack('Import not available on mobile'),
                icon: const Icon(Icons.upload_file, color: Colors.white38),
                label: const Text('Choose File & Import', style: TextStyle(color: Colors.white38)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _exportBtn(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSnack('$label export coming soon'),
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text('Export $label', style: const TextStyle(color: Colors.white, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  Future<void> _doAction(Future<void> Function() action, int reloadTab) async {
    try {
      await action();
      if (mounted) _loadForTab(reloadTab);
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF334155), duration: const Duration(seconds: 2)),
    );
  }

  String _formatTime(String? s) {
    if (s == null || s.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(s).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    } catch (_) {
      return s.length > 5 ? s.substring(0, 5) : s;
    }
  }

  String _formatDate(String s) {
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.parse(s);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }
}
