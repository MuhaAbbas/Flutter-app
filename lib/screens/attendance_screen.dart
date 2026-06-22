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
          tabs: const ['Records', 'Att. Requests', 'Leave Requests', 'Import / Export'],
          controller: _tab,
          isScrollable: false,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        // Prevent horizontal swipe from switching tabs — conflicts with table scroll
        physics: const NeverScrollableScrollPhysics(),
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
  List<Map<String, dynamic>> _records = [], _employees = [], _depts = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  String _empId = 'all';
  String _deptId = 'all';
  String _statusFilter = 'all';

  // Synced horizontal scroll controllers for sticky header
  late final ScrollController _hHeader;
  late final ScrollController _hBody;
  bool _hSyncing = false;

  List<Map<String, dynamic>> get _visible {
    return _records.where((r) {
      bool stOk = _statusFilter == 'all' || (r['status'] ?? '').toString().toLowerCase() == _statusFilter;
      bool eOk = _empId == 'all';
      if (!eOk) {
        final rEmp = r['user']?['id']?.toString() ?? r['userId']?.toString() ?? r['user']?['_id']?.toString();
        eOk = rEmp == _empId;
      }
      bool dOk = _deptId == 'all';
      if (!dOk) {
        final rDept = r['user']?['department']?['id']?.toString() ?? r['user']?['department']?['_id']?.toString() ?? r['departmentId']?.toString();
        dOk = rDept == _deptId;
      }
      return stOk && eOk && dOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _hHeader = ScrollController();
    _hBody   = ScrollController();
    _hHeader.addListener(_onHeaderScroll);
    _hBody.addListener(_onBodyScroll);
    widget.filterNotifier?.addListener(_onExternalFilter);
    _loadAll();
  }

  void _onHeaderScroll() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hBody.hasClients) _hBody.jumpTo(_hHeader.offset.clamp(_hBody.position.minScrollExtent, _hBody.position.maxScrollExtent));
    _hSyncing = false;
  }

  void _onBodyScroll() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hHeader.hasClients) _hHeader.jumpTo(_hBody.offset.clamp(_hHeader.position.minScrollExtent, _hHeader.position.maxScrollExtent));
    _hSyncing = false;
  }

  void _onExternalFilter() {
    final v = widget.filterNotifier?.value ?? 'all';
    if (mounted) setState(() => _statusFilter = v);
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    widget.filterNotifier?.removeListener(_onExternalFilter);
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_from);
      final toStr = DateFormat('yyyy-MM-dd').format(_to);
      final results = await Future.wait([
        ApiService().getAttendanceAll(from: fromStr, to: toStr),
        ApiService().getEmployees(),
        ApiService().getDepartments(),
      ]);
      if (mounted) setState(() {
        final raw = (results[0] as Map)['records'] ?? (results[0] as Map)['data'] ?? (results[0] as Map)['attendance'] ?? [];
        _records = raw is List ? raw.cast<Map<String, dynamic>>() : [];
        _stats = (results[0] as Map)['stats'] ?? (results[0] as Map)['summary'] ?? {};
        _employees = results[1] as List<Map<String, dynamic>>;
        _depts = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fromStr = DateFormat('yyyy-MM-dd').format(_from);
      final toStr = DateFormat('yyyy-MM-dd').format(_to);
      final result = await ApiService().getAttendanceAll(from: fromStr, to: toStr);
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

  void _clearFilters() => setState(() { _empId = 'all'; _deptId = 'all'; _statusFilter = 'all'; });

  int _cnt(String s) => _records.where((r) => (r['status'] ?? '').toString().toLowerCase() == s).length;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filterBar(),
      if (!_loading && _error == null) _statCards(),
      Expanded(child: _body()),
    ]);
  }

  Widget _filterBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _datePicker(label: 'From Date', value: _from, onChanged: (d) { setState(() => _from = d); _load(); }),
      _datePicker(label: 'To Date', value: _to, onChanged: (d) { setState(() => _to = d); _load(); }),
      SizedBox(width: 170, child: _dropFilter(
        value: _deptId,
        items: [const DropdownMenuItem(value: 'all', child: Text('All Departments')),
          ..._depts.map((d) => DropdownMenuItem(value: (d['id'] ?? d['_id'] ?? '').toString(), child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis)))],
        onChanged: (v) => setState(() => _deptId = v ?? 'all'),
      )),
      SizedBox(width: 180, child: _dropFilter(
        value: _empId,
        items: [const DropdownMenuItem(value: 'all', child: Text('All Employees')),
          ..._employees.map((e) {
            final id = (e['id'] ?? e['_id'] ?? '').toString();
            final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
            return DropdownMenuItem(value: id, child: Text(name.isEmpty ? id : name, overflow: TextOverflow.ellipsis));
          })],
        onChanged: (v) => setState(() => _empId = v ?? 'all'),
      )),
      SizedBox(width: 140, child: _dropFilter(
        value: _statusFilter,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Status')),
          DropdownMenuItem(value: 'present', child: Text('Present')),
          DropdownMenuItem(value: 'absent', child: Text('Absent')),
          DropdownMenuItem(value: 'late', child: Text('Late')),
          DropdownMenuItem(value: 'leave', child: Text('Leave')),
        ],
        onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
      )),
      TextButton(
        onPressed: _clearFilters,
        style: TextButton.styleFrom(
          backgroundColor: AppTheme.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Clear Filters', style: AppTheme.label(12)),
      ),
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20), padding: const EdgeInsets.all(8), constraints: const BoxConstraints()),
    ]),
  );

  Widget _datePicker({required String label, required DateTime value, required void Function(DateTime) onChanged}) =>
    GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context, initialDate: value,
          firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)),
          builder: (_, c) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: c!),
        );
        if (p != null) onChanged(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: AppTheme.label(9, color: AppTheme.textSecondary)),
            Text(DateFormat('MMM d, yyyy').format(value), style: AppTheme.label(12, color: AppTheme.textPrimary, weight: FontWeight.w600)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.calendar_today, size: 13, color: AppTheme.textSecondary),
        ]),
      ),
    );

  Widget _dropFilter({required String value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 42,
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(12), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
      ),
    );

  Widget _statCards() {
    final present = (_stats['present'] ?? _stats['presentToday']) as int? ?? _cnt('present');
    final absent = (_stats['absent'] ?? _stats['absentToday']) as int? ?? _cnt('absent');
    final late = (_stats['late'] ?? _stats['lateToday']) as int? ?? _cnt('late');
    final total = _records.length;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        _statCard('Present Today', present, const Color(0xFF4ADE80), Icons.check_circle_outline),
        const SizedBox(width: 10),
        _statCard('Absent Today', absent, const Color(0xFFF87171), Icons.cancel_outlined),
        const SizedBox(width: 10),
        _statCard('Late Today', late, const Color(0xFFFBBF24), Icons.schedule_outlined),
        const SizedBox(width: 10),
        _statCard('Total Records', total, AppTheme.primary, Icons.event_note_outlined),
      ]),
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25))),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$count', style: GoogleFonts.poppins(color: color, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
        Text(label, style: AppTheme.label(10, color: color.withOpacity(0.8))),
      ])),
    ]),
  ));

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    final shown = _visible;
    if (_records.isEmpty) return _emptyWidget('No attendance records for this period');
    if (shown.isEmpty) return _emptyWidget('No records match the selected filters');

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in shown) {
      final raw = r['date'] ?? r['attendanceDate'] ?? r['checkIn'] ?? r['checkInTime'] ?? '';
      String key = '—';
      try { key = DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString())); } catch (_) {}
      (grouped[key] ??= []).add(r);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('Showing ${shown.length} record${shown.length == 1 ? '' : 's'}', style: AppTheme.label(12, color: AppTheme.textSecondary))),
      ),
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(
          controller: _hHeader,
          scrollDirection: Axis.horizontal,
          child: _tableHeader(),
        ),
      ),
      const Divider(color: AppTheme.divider, height: 1),
      Expanded(child: RefreshIndicator(
        onRefresh: _load, color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            controller: _hBody,
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final date in dates) ...[
                _dateGroupHeader(date),
                ...grouped[date]!.asMap().entries.map((e) => _recordRow(e.value, e.key.isOdd)),
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
      _th(220, 'Employee'),
      _th(90, 'Emp. ID'),
      _th(150, 'Department'),
      _th(130, 'Date'),
      _th(100, 'Check In'),
      _th(100, 'Check Out'),
      _th(80, 'Hours', center: true),
      _th(90, 'Status', center: true),
    ]),
  );

  Widget _dateGroupHeader(String date) {
    String label = date;
    try {
      final dt = DateTime.parse(date);
      label = DateFormat('EEEE, MMMM d, yyyy').format(dt).toUpperCase();
    } catch (_) {}
    return Container(
      width: 960,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Text(label, style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w700)),
    );
  }

  Widget _recordRow(Map<String, dynamic> r, bool alt) {
    final firstName = r['firstName'] ?? r['user']?['firstName'] ?? '';
    final lastName = r['lastName'] ?? r['user']?['lastName'] ?? '';
    String name = '$firstName $lastName'.trim();
    final email = (r['email'] ?? r['user']?['email'] ?? '').toString();
    if (name.isEmpty) name = (r['name'] ?? 'Employee').toString();
    final empId = (r['employeeId'] ?? r['userEmployeeId'] ?? r['user']?['employeeId'] ?? '').toString();
    final dept = (r['department'] ?? r['departmentName'] ?? r['user']?['department']?['name'] ?? '').toString();
    final status = (r['status'] ?? 'present').toString();
    final checkIn = _fmtTime(r['checkIn'] ?? r['checkInTime'] ?? '');
    final checkOut = _fmtTime(r['checkOut'] ?? r['checkOutTime'] ?? '');
    final hours = r['totalHours'] ?? r['workingHours'] ?? '';
    final dateRaw = r['date'] ?? r['attendanceDate'] ?? r['checkIn'] ?? '';
    String dateStr = '—';
    try { dateStr = DateFormat('MMM d').format(DateTime.parse(dateRaw.toString())); } catch (_) {}
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 220, child: Row(children: [
          CircleAvatar(radius: 17, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(12, color: ac, weight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.body(12), overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty) Text(email, style: AppTheme.label(10), overflow: TextOverflow.ellipsis),
          ])),
        ])),
        SizedBox(width: 90, child: Text(empId.isNotEmpty ? empId : '—', style: AppTheme.label(12, color: AppTheme.primary, weight: FontWeight.w600))),
        SizedBox(width: 150, child: Text(dept.isNotEmpty ? dept : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 130, child: Text(dateStr, style: AppTheme.label(12))),
        SizedBox(width: 100, child: Text(checkIn.isNotEmpty ? checkIn : '—', style: AppTheme.label(12))),
        SizedBox(width: 100, child: Text(checkOut.isNotEmpty ? checkOut : '—', style: AppTheme.label(12))),
        SizedBox(width: 80, child: Center(child: Text(hours.toString().isNotEmpty ? '${hours}h' : '—', style: AppTheme.label(12)))),
        SizedBox(width: 90, child: Center(child: StatusBadge(status: status, fontSize: 10))),
      ]),
    );
  }

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try { return DateFormat('h:mm a').format(DateTime.parse(v.toString()).toLocal()); }
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

Widget _th(double w, String label, {bool center = false}) => SizedBox(
  width: w,
  child: Align(
    alignment: center ? Alignment.center : Alignment.centerLeft,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
  ),
);

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
