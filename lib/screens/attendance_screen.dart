// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_tab_bar.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class AttendanceScreen extends StatefulWidget {
  final ValueNotifier<String>? filterNotifier;
  const AttendanceScreen({super.key, this.filterNotifier});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Attendance',
        bottomHeight: 44,
        bottom: CustomTabBar(
          tabs: const ['Records', 'Corrections', 'Leave Requests', 'Import / Export'],
          controller: _tab,
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _RecordsTab(filterNotifier: widget.filterNotifier),
          const _CorrectionsTab(),
          const _LeaveTab(),
          const _ImportExportTab(),
        ],
      ),
    );
  }
}

// ── Records Tab ───────────────────────────────────────────────────────────────

class _RecordsTab extends StatefulWidget {
  final ValueNotifier<String>? filterNotifier;
  const _RecordsTab({this.filterNotifier});
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  DateTime _date = DateTime.now();
  String _statusFilter = 'all';

  List<Map<String, dynamic>> get _visible => _statusFilter == 'all'
      ? _records
      : _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == _statusFilter).toList();

  @override
  void initState() {
    super.initState();
    widget.filterNotifier?.addListener(_onExternalFilter);
    _load();
  }

  void _onExternalFilter() {
    final v = widget.filterNotifier?.value ?? 'all';
    if (mounted) setState(() => _statusFilter = v);
  }

  @override
  void dispose() {
    widget.filterNotifier?.removeListener(_onExternalFilter);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final result = await ApiService().getAttendanceAll(from: dateStr, to: dateStr);
      if (mounted) setState(() {
        final raw = result['records'] ?? result['data'] ?? result['attendance'] ?? [];
        _records = raw is List ? raw.cast<Map<String, dynamic>>() : [];
        _stats = result['stats'] ?? result['summary'] ?? {};
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _cnt(String s) => _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == s).length;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _dateBar(),
      if (!_loading && _error == null) _statsRow(),
      Expanded(child: _body()),
    ]);
  }

  Widget _dateBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        IconButton(
          onPressed: () { setState(() => _date = _date.subtract(const Duration(days: 1))); _load(); },
          icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final p = await showDatePicker(
              context: context, initialDate: _date,
              firstDate: DateTime(2020), lastDate: DateTime.now(),
              builder: (_, c) => Theme(
                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
                child: c!,
              ),
            );
            if (p != null) { setState(() => _date = p); _load(); }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: AppTheme.primary, size: 14),
              const SizedBox(width: 8),
              Text(DateFormat('EEE, MMM d, yyyy').format(_date),
                  style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _date.day == DateTime.now().day ? null : () {
            setState(() => _date = _date.add(const Duration(days: 1))); _load();
          },
          icon: Icon(Icons.chevron_right,
              color: _date.day == DateTime.now().day ? AppTheme.divider : AppTheme.textSecondary),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const Spacer(),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20)),
      ]),
    );
  }

  Widget _statsRow() {
    final present = (_stats['present'] ?? _stats['presentToday']) as int? ?? _cnt('present');
    final absent = (_stats['absent'] ?? _stats['absentToday']) as int? ?? _cnt('absent');
    final late = (_stats['late'] ?? _stats['lateToday']) as int? ?? _cnt('late');
    final leave = (_stats['onLeave'] ?? _stats['leave']) as int? ?? _cnt('leave');
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        _statChip('Present', present, const Color(0xFF4ADE80), 'present'),
        const SizedBox(width: 10),
        _statChip('Absent', absent, const Color(0xFFF87171), 'absent'),
        const SizedBox(width: 10),
        _statChip('Late', late, const Color(0xFF60A5FA), 'late'),
        const SizedBox(width: 10),
        _statChip('Leave', leave, const Color(0xFFFBBF24), 'leave'),
      ]),
    );
  }

  Widget _statChip(String label, int count, Color color, String filterKey) {
    final active = _statusFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = active ? 'all' : filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.22) : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Column(children: [
          Text('$count', style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: AppTheme.label(10, color: color)),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_records.isEmpty) return _emptyWidget('No attendance records for this date');
    final shown = _visible;
    if (shown.isEmpty) return _emptyWidget('No ${_statusFilter == "all" ? "" : "$_statusFilter "}records for this date');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: shown.length,
        itemBuilder: (_, i) => _recordCard(shown[i]),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> r) {
    final firstName = r['firstName'] ?? r['user']?['firstName'] ?? '';
    final lastName = r['lastName'] ?? r['user']?['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final empId = r['employeeId'] ?? r['userEmployeeId'] ?? r['user']?['employeeId'] ?? '';
    final dept = r['department'] ?? r['departmentName'] ?? r['user']?['department']?['name'] ?? '';
    final status = (r['status'] ?? 'present').toString();
    final checkIn = _fmtTime(r['checkIn'] ?? r['checkInTime'] ?? '');
    final checkOut = _fmtTime(r['checkOut'] ?? r['checkOutTime'] ?? '');
    final hours = r['totalHours'] ?? r['workingHours'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primary.withOpacity(0.12),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTheme.label(14, color: AppTheme.primary, weight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name.isEmpty ? 'Employee' : name, style: AppTheme.body(13), overflow: TextOverflow.ellipsis)),
            if (empId.toString().isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(empId.toString(), style: AppTheme.label(10, color: AppTheme.primary, weight: FontWeight.w600)),
              ),
            ],
          ]),
          if (dept.toString().isNotEmpty)
            Text(dept.toString(), style: AppTheme.label(11)),
          const SizedBox(height: 6),
          Row(children: [
            if (checkIn.isNotEmpty) _timeChip(Icons.login, checkIn),
            if (checkOut.isNotEmpty) ...[const SizedBox(width: 8), _timeChip(Icons.logout, checkOut)],
            if (hours.toString().isNotEmpty) ...[const SizedBox(width: 8), _timeChip(Icons.timer_outlined, '${hours}h')],
          ]),
        ])),
        const SizedBox(width: 10),
        StatusBadge(status: status),
      ]),
    );
  }

  Widget _timeChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: AppTheme.textSecondary),
      const SizedBox(width: 3),
      Text(text, style: AppTheme.label(10)),
    ],
  );

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try { return DateFormat('hh:mm a').format(DateTime.parse(v.toString()).toLocal()); }
    catch (_) { return v.toString().length > 5 ? v.toString().substring(11, 16) : v.toString(); }
  }
}

// ── Corrections Tab ───────────────────────────────────────────────────────────

class _CorrectionsTab extends StatefulWidget {
  const _CorrectionsTab();
  @override
  State<_CorrectionsTab> createState() => _CorrectionsTabState();
}

class _CorrectionsTabState extends State<_CorrectionsTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getAttendanceRequests();
      if (mounted) setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService().approveAttendanceRequest(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService().rejectAttendanceRequest(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_requests.isEmpty) return _emptyWidget('No correction requests');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (_, i) => _reqCard(_requests[i]),
      ),
    );
  }

  Widget _reqCard(Map<String, dynamic> r) {
    final name = '${r['user']?['firstName'] ?? r['firstName'] ?? ''} ${r['user']?['lastName'] ?? r['lastName'] ?? ''}'.trim();
    final status = (r['status'] ?? 'pending').toString();
    final date = r['date'] ?? r['attendanceDate'] ?? '';
    final reason = r['reason'] ?? r['description'] ?? '';
    final id = r['id']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name.isEmpty ? 'Employee' : name, style: AppTheme.body(14))),
          StatusBadge(status: status),
        ]),
        if (date.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Date: $date', style: AppTheme.label(12)),
          ),
        if (reason.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(reason.toString(), style: AppTheme.label(12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        if (status.toLowerCase() == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _reject(id),
              icon: const Icon(Icons.close, size: 14, color: AppTheme.error),
              label: Text('Reject', style: AppTheme.label(12, color: AppTheme.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _approve(id),
              icon: const Icon(Icons.check, size: 14, color: Colors.white),
              label: Text('Approve', style: AppTheme.label(12, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, padding: const EdgeInsets.symmetric(vertical: 8)),
            )),
          ]),
        ],
      ]),
    );
  }
}

// ── Leave Requests Tab ────────────────────────────────────────────────────────

class _LeaveTab extends StatefulWidget {
  const _LeaveTab();
  @override
  State<_LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<_LeaveTab> {
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getLeaveRequests();
      if (mounted) setState(() { _leaves = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _action(String id, bool approve) async {
    try {
      if (approve) {
        await ApiService().approveLeaveRequest(id);
      } else {
        await ApiService().rejectLeaveRequest(id);
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _leaves
      : _leaves.where((l) => (l['status'] ?? '').toString().toLowerCase() == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filterBar(),
      Expanded(child: _body()),
    ]);
  }

  Widget _filterBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final f in ['all', 'pending', 'approved', 'rejected'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == f ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filter == f ? AppTheme.primary : AppTheme.divider),
                ),
                child: Text(
                  '${f[0].toUpperCase()}${f.substring(1)}',
                  style: AppTheme.label(12, color: _filter == f ? AppTheme.primary : AppTheme.textSecondary,
                      weight: _filter == f ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
          ),
      ]),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_visible.isEmpty) return _emptyWidget('No ${_filter == 'all' ? '' : _filter} leave requests');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visible.length,
        itemBuilder: (_, i) => _leaveCard(_visible[i]),
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> l) {
    final name = '${l['user']?['firstName'] ?? l['firstName'] ?? ''} ${l['user']?['lastName'] ?? l['lastName'] ?? ''}'.trim();
    final status = (l['status'] ?? 'pending').toString();
    final type = l['leaveType'] ?? l['type'] ?? '';
    final from = l['startDate'] ?? l['fromDate'] ?? '';
    final to = l['endDate'] ?? l['toDate'] ?? '';
    final reason = l['reason'] ?? '';
    final id = l['id']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? 'Employee' : name, style: AppTheme.body(14)),
            if (type.toString().isNotEmpty)
              Text(type.toString(), style: AppTheme.label(11, color: AppTheme.primary)),
          ])),
          StatusBadge(status: status),
        ]),
        if (from.toString().isNotEmpty || to.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('$from → $to', style: AppTheme.label(12)),
            ]),
          ),
        if (reason.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(reason.toString(), style: AppTheme.label(12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        if (status.toLowerCase() == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => _action(id, false),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), padding: const EdgeInsets.symmetric(vertical: 8)),
              child: Text('Reject', style: AppTheme.label(12, color: AppTheme.error)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => _action(id, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, padding: const EdgeInsets.symmetric(vertical: 8)),
              child: Text('Approve', style: AppTheme.label(12, color: Colors.white)),
            )),
          ]),
        ],
      ]),
    );
  }
}

// ── Import / Export Tab ───────────────────────────────────────────────────────

class _ImportExportTab extends StatelessWidget {
  const _ImportExportTab();

  void _export(String endpoint, String format) {
    final url = '${ApiConfig.baseUrl}$endpoint?format=$format';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Export', style: AppTheme.heading(15)),
        const SizedBox(height: 14),
        _exportCard(
          context,
          title: 'Attendance Records',
          subtitle: 'Download daily attendance data',
          icon: Icons.event_note_outlined,
          color: AppTheme.primary,
          endpoint: '/attendance/export',
        ),
        const SizedBox(height: 10),
        _exportCard(
          context,
          title: 'Activity Logs',
          subtitle: 'Download employee activity data',
          icon: Icons.bar_chart_outlined,
          color: AppTheme.secondary,
          endpoint: '/activities/export',
        ),
        const SizedBox(height: 10),
        _exportCard(
          context,
          title: 'Payroll Data',
          subtitle: 'Download salary and payroll records',
          icon: Icons.payments_outlined,
          color: const Color(0xFFC084FC),
          endpoint: '/payroll/export',
        ),
        const SizedBox(height: 28),
        Text('Import', style: AppTheme.heading(15)),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file_outlined, color: AppTheme.warning, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Import Attendance (CSV)', style: AppTheme.body(14)),
                Text('Upload a CSV file with attendance records', style: AppTheme.label(12)),
              ])),
            ]),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.divider, height: 1),
            const SizedBox(height: 14),
            Text('Required CSV Format:', style: AppTheme.label(12, color: AppTheme.primary, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'employeeId, date, checkIn, checkOut, status\nCS0001, 2026-06-01, 09:00, 17:00, present\nCS0002, 2026-06-01, 09:15, 17:00, late',
                style: GoogleFonts.sourceCodePro(color: AppTheme.secondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import via CSV file upload — use the web panel'))),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text('Upload CSV', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _exportCard(BuildContext ctx, {
    required String title, required String subtitle,
    required IconData icon, required Color color, required String endpoint,
  }) {
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTheme.body(14)),
            Text(subtitle, style: AppTheme.label(11)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _fmtBtn(ctx, endpoint, 'PDF', Icons.picture_as_pdf, AppTheme.error),
          const SizedBox(width: 8),
          _fmtBtn(ctx, endpoint, 'Excel', Icons.table_chart_outlined, AppTheme.secondary),
        ]),
      ]),
    );
  }

  Widget _fmtBtn(BuildContext ctx, String endpoint, String fmt, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _export(endpoint, fmt.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(fmt, style: AppTheme.label(11, color: color, weight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
