import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
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
    try {
      final results = await Future.wait([ApiService().getEmployees(), ApiService().getDepartments()]);
      if (mounted) setState(() {
        _employees = results[0] as List<Map<String, dynamic>>;
        _departments = results[1] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
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
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Employees')),
            ..._employees.map((e) {
              final id = (e['id'] ?? e['_id'] ?? '').toString();
              final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
              return DropdownMenuItem(value: id, child: Text(name.isNotEmpty ? name : id, overflow: TextOverflow.ellipsis));
            }),
          ],
          onChanged: (v) { if (v != null) { setState(() => _selectedUserId = v); _load(); } },
        )),
        const SizedBox(width: 10),
        Expanded(child: _dropdown(
          value: _selectedDeptId,
          items: [
            const DropdownMenuItem(value: 'all', child: Text('All Departments')),
            ..._departments.map((d) => DropdownMenuItem(
                value: (d['id'] ?? d['_id'] ?? '').toString(),
                child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) { if (v != null) { setState(() => _selectedDeptId = v); _load(); } },
        )),
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: () { setState(() { if (_month == 1) { _month = 12; _year--; } else _month--; }); _load(); },
          icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text('${_months[_month - 1]} $_year',
              style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: () { setState(() { if (_month == 12) { _month = 1; _year++; } else _month++; }); _load(); },
          icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ),
      ]),
    ]),
  );

  Widget _dropdown({required String value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(12), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
      ),
    );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_logs.isEmpty) return _emptyWidget('No activity logs for this period');

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in _logs) {
      final raw = log['date'] ?? log['createdAt'] ?? log['timestamp'] ?? '';
      String key = '—';
      try { key = DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString())); } catch (_) {}
      (grouped[key] ??= []).add(log);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('${_logs.length} record${_logs.length == 1 ? '' : 's'}', style: AppTheme.label(12, color: AppTheme.textSecondary))),
      ),
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _tableHeader()),
      ),
      const Divider(color: AppTheme.divider, height: 1),
      Expanded(child: RefreshIndicator(
        onRefresh: _load, color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final date in dates) ...[
                _dateGroupHeader(date),
                ...grouped[date]!.asMap().entries.map((e) => _logRow(e.value, e.key.isOdd)),
              ],
            ]),
          ),
        ),
      )),
    ]);
  }

  Widget _tableHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      _th(130, 'Date'),
      _th(200, 'Employee'),
      _th(90, 'Emp. ID'),
      _th(150, 'Department'),
      _th(280, 'Activity'),
      _th(150, 'Tags'),
    ]),
  );

  Widget _dateGroupHeader(String date) {
    String label = date;
    try { label = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(date)).toUpperCase(); } catch (_) {}
    return Container(
      width: 1000,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Text(label, style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w700)),
    );
  }

  Widget _logRow(Map<String, dynamic> log, bool alt) {
    final uMap = log['user'] is Map ? log['user'] as Map : <String, dynamic>{};
    String name = (log['userName'] ?? log['employeeName'] ?? '').toString().trim();
    if (name.isEmpty) name = '${uMap['firstName'] ?? log['firstName'] ?? ''} ${uMap['lastName'] ?? log['lastName'] ?? ''}'.trim();
    final empId = (log['empId'] ?? log['employeeId'] ?? log['userEmployeeId'] ?? uMap['employeeId'] ?? '').toString();
    final dept = (log['department'] ?? log['departmentName'] ?? uMap['department']?['name'] ?? '').toString();
    final email = (log['email'] ?? uMap['email'] ?? '').toString();
    final activity = (log['title'] ?? log['activityTitle'] ?? log['activity'] ?? log['activityType'] ?? '').toString();
    final description = (log['description'] ?? log['content'] ?? log['activityText'] ?? log['text'] ?? '').toString();
    final dateRaw = (log['date'] ?? log['createdAt'] ?? log['timestamp'] ?? '').toString();
    String timeStr = '—';
    try { timeStr = DateFormat('h:mm a').format(DateTime.parse(dateRaw).toLocal()); } catch (_) {}
    final tags = log['tags'] is List ? (log['tags'] as List).map((t) => t.toString()).toList() :
        (log['tag']?.toString().isNotEmpty == true ? [log['tag'].toString()] : <String>[]);
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 130, child: Text(timeStr, style: AppTheme.label(12))),
        SizedBox(width: 200, child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(11, color: ac, weight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isNotEmpty ? name : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty) Text(email, style: AppTheme.label(9), overflow: TextOverflow.ellipsis),
          ])),
        ])),
        SizedBox(width: 90, child: Text(empId.isNotEmpty ? empId : '—', style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w600))),
        SizedBox(width: 150, child: Text(dept.isNotEmpty ? dept : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 280, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (activity.isNotEmpty) Text(activity, style: AppTheme.body(12), overflow: TextOverflow.ellipsis),
          if (description.isNotEmpty) Text(description, style: AppTheme.label(10), overflow: TextOverflow.ellipsis, maxLines: 2),
          if (activity.isEmpty && description.isEmpty) Text('—', style: AppTheme.label(12)),
        ])),
        SizedBox(width: 150, child: tags.isEmpty ? Text('—', style: AppTheme.label(12)) : Wrap(spacing: 4, runSpacing: 4, children: tags.take(3).map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
          child: Text(t, style: AppTheme.label(9, color: AppTheme.primary)),
        )).toList())),
      ]),
    );
  }

  Widget _th(double w, String label) => SizedBox(
    width: w,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
  );
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
