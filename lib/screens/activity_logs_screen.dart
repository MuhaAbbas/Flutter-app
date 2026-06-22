import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
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
  String? _error;
  String _selectedUserId = 'all';
  String _selectedDeptId = 'all';
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  void initState() { super.initState(); _loadMeta(); }

  Future<void> _loadMeta() async {
    final results = await Future.wait([ApiService().getEmployees(), ApiService().getDepartments()]);
    setState(() {
      _employees = results[0] as List<Map<String, dynamic>>;
      _departments = results[1] as List<Map<String, dynamic>>;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getActivityLogsWithError(
        userId: _selectedUserId,
        departmentId: _selectedDeptId,
        month: _month,
        year: _year,
      );
      if (mounted) setState(() { _logs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Activity Logs',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary)),
        ],
      ),
      body: Column(children: [
        _filters(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _filters() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(children: [
      Row(children: [
        Expanded(child: _dropdown(
          value: _selectedUserId,
          hint: 'All Employees',
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Employees')),
            ..._employees.map((e) {
              final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
              return DropdownMenuItem(value: e['id']?.toString() ?? '', child: Text(name, overflow: TextOverflow.ellipsis));
            }),
          ],
          onChanged: (v) { if (v != null) { setState(() => _selectedUserId = v); _load(); } },
        )),
        const SizedBox(width: 10),
        Expanded(child: _dropdown(
          value: _selectedDeptId,
          hint: 'All Departments',
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Departments')),
            ..._departments.map((d) => DropdownMenuItem(
                value: d['id']?.toString() ?? '',
                child: Text(d['name']?.toString() ?? '', overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) { if (v != null) { setState(() => _selectedDeptId = v); _load(); } },
        )),
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: () {
            setState(() { if (_month == 1) { _month = 12; _year--; } else _month--; });
            _load();
          },
          icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        ),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${_months[_month - 1]} $_year',
                style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w600)),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() { if (_month == 12) { _month = 1; _year++; } else _month++; });
            _load();
          },
          icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ),
      ]),
    ]),
  );

  Widget _dropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppTheme.surfaceElevated,
        style: AppTheme.body(12),
        iconEnabledColor: AppTheme.textSecondary,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_logs.isEmpty) return _emptyWidget('No activity logs for this period');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: _buildTimeline(),
    );
  }

  Widget _buildTimeline() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final log in _logs) {
      final key = _dayKey(log['date'] ?? log['createdAt'] ?? '');
      grouped.putIfAbsent(key, () => []).add(log);
    }
    final sections = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(section.key,
                style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w700)),
          ),
          ...section.value.map(_logEntry),
        ]);
      },
    );
  }

  Widget _logEntry(Map<String, dynamic> log) {
    final name = log['userName'] ?? log['employeeName'] ??
        '${log['user']?['firstName'] ?? ''} ${log['user']?['lastName'] ?? ''}'.trim();
    final empId = log['empId'] ?? log['employeeId'] ?? log['user']?['employeeId'] ?? '';
    final dept = log['department'] ?? log['departmentName'] ?? log['user']?['department']?['name'] ?? '';
    final activity = log['title'] ?? log['activityTitle'] ?? log['activity'] ?? '';
    final description = log['description'] ?? log['content'] ?? log['activityText'] ?? '';
    final time = _fmtTime(log['date'] ?? log['createdAt'] ?? '');

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w700))),
        ),
        Container(width: 1, height: 30, color: AppTheme.divider, margin: const EdgeInsets.symmetric(vertical: 2)),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name.isEmpty ? 'Unknown' : name, style: AppTheme.body(13))),
              if (empId.toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(empId.toString(), style: AppTheme.label(9, color: AppTheme.primary, weight: FontWeight.w600)),
                ),
            ]),
            if (dept.toString().isNotEmpty)
              Text(dept.toString(), style: AppTheme.label(10)),
            if (activity.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(activity.toString(), style: AppTheme.body(12, color: AppTheme.textPrimary)),
            ],
            if (description.toString().isNotEmpty)
              Text(description.toString(), style: AppTheme.label(11), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(time, style: AppTheme.label(10, color: AppTheme.primary)),
          ]),
        ),
      ),
    ]);
  }

  String _dayKey(String iso) {
    if (iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('EEEE, MMMM d, yyyy').format(dt);
    } catch (_) { return iso.substring(0, min(10, iso.length)); }
  }

  String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try { return DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return ''; }
  }

  int min(int a, int b) => a < b ? a : b;
}

Widget _errWidget(String msg, VoidCallback retry) => Center(child: Padding(
  padding: const EdgeInsets.all(24),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
    const SizedBox(height: 12),
    Text(msg.replaceFirst('Exception: ', ''), style: AppTheme.body(13, color: AppTheme.error), textAlign: TextAlign.center),
    const SizedBox(height: 12),
    TextButton(onPressed: retry, child: Text('Retry', style: AppTheme.label(13, color: AppTheme.primary))),
  ]),
));

Widget _emptyWidget(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
  Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
  const SizedBox(height: 12),
  Text(msg, style: AppTheme.label(14)),
]));
