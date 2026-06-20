import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});
  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;

  String _selectedUserId = 'all';
  String _selectedDeptId = 'all';
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final results = await Future.wait([
      ApiService().getEmployees(),
      ApiService().getDepartments(),
    ]);
    setState(() {
      _employees = results[0] as List<Map<String, dynamic>>;
      _departments = results[1] as List<Map<String, dynamic>>;
    });
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final data = await ApiService().getActivityLogs(
      userId: _selectedUserId,
      departmentId: _selectedDeptId,
      month: _month,
      year: _year,
    );
    if (mounted) setState(() { _logs = data; _loading = false; });
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; }
      else _month--;
    });
    _loadLogs();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) { _month = 1; _year++; }
      else _month++;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Activity Logs',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(onPressed: _loadLogs, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _logs.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: _buildGroupedList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _dropdown(
                value: _selectedUserId,
                hint: 'All Employees',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Employees')),
                  ..._employees.map((e) {
                    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                    final id = e['id']?.toString() ?? '';
                    return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) { if (v != null) { setState(() => _selectedUserId = v); _loadLogs(); } },
              )),
              const SizedBox(width: 8),
              Expanded(child: _dropdown(
                value: _selectedDeptId,
                hint: 'All Departments',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Departments')),
                  ..._departments.map((d) {
                    final name = d['name']?.toString() ?? '';
                    final id = d['id']?.toString() ?? '';
                    return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) { if (v != null) { setState(() => _selectedDeptId = v); _loadLogs(); } },
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Text('${_months[_month - 1]} $_year',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          iconEnabledColor: Colors.white38,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in _logs) {
      final key = _dateKey(log['date'] ?? log['createdAt'] ?? '');
      grouped.putIfAbsent(key, () => []).add(log);
    }

    final sections = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(section.key.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ),
            ...section.value.map(_logCard),
          ],
        );
      },
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final name = log['userName'] ?? log['employeeName'] ??
        '${log['user']?['firstName'] ?? ''} ${log['user']?['lastName'] ?? ''}'.trim();
    final empId = log['empId'] ?? log['employeeId'] ?? log['user']?['employeeId'] ?? '';
    final dept = log['department'] ?? log['departmentName'] ?? log['user']?['department']?['name'] ?? '';
    final activityTitle = log['title'] ?? log['activityTitle'] ?? log['activity'] ?? '';
    final preview = log['description'] ?? log['content'] ?? log['activityText'] ?? '';
    final tags = log['tags'] as List? ?? [];
    final date = log['date'] ?? log['createdAt'] ?? '';
    final dayAbbr = _dayAbbr(date);
    final dateStr = _shortDate(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date col
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayAbbr,
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                Text(dateStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.teal.withValues(alpha: 0.2),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (empId.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(empId.toString(),
                            style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                if (dept.toString().isNotEmpty)
                  Text(dept.toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 4),
                if (activityTitle.toString().isNotEmpty)
                  Text(activityTitle.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                if (preview.toString().isNotEmpty)
                  Text(preview.toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t.toString(),
                          style: const TextStyle(color: Colors.purple, fontSize: 10)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateKey(String iso) {
    if (iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  String _dayAbbr(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return d[dt.weekday - 1];
    } catch (_) { return '—'; }
  }

  String _shortDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No activity logs found',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
