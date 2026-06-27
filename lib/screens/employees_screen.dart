import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_tab_bar.dart';
import '../services/api_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Employees',
        bottomHeight: 44,
        bottom: CustomTabBar(tabs: const ['Employees', 'Departments'], controller: _tab),
      ),
      body: TabBarView(
        controller: _tab,
        // Prevent horizontal swipe from triggering tab switch — conflicts with table scroll
        physics: const NeverScrollableScrollPhysics(),
        children: const [_EmployeesTab(), _DepartmentsTab()],
      ),
    );
  }
}

// ── Employees Tab ─────────────────────────────────────────────────────────────

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();
  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _all = [], _filtered = [], _depts = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _selectedDeptId = 'all';
  String _selectedStatus = 'all';

  // Synced horizontal scroll controllers
  late final ScrollController _hHeader;
  late final ScrollController _hBody;
  bool _hSyncing = false;

  @override
  void initState() {
    super.initState();
    _hHeader = ScrollController();
    _hBody   = ScrollController();
    _hHeader.addListener(_onHeaderScroll);
    _hBody.addListener(_onBodyScroll);
    _searchCtrl.addListener(_applyFilters);
    _load();
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

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([ApiService().getEmployees(), ApiService().getDepartments()]);
      if (mounted) setState(() {
        _all   = r[0] as List<Map<String, dynamic>>;
        _depts = r[1] as List<Map<String, dynamic>>;
        _applyFiltersInline();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFiltersInline() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _all.where((e) {
      final name  = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final id    = (e['employeeId'] ?? '').toString().toLowerCase();
      final searchOk = q.isEmpty || name.contains(q) || email.contains(q) || id.contains(q);
      bool deptOk = _selectedDeptId == 'all';
      if (!deptOk) {
        final dObj = e['department'] is Map ? e['department'] as Map : null;
        final eDeptId = (dObj?['id'] ?? dObj?['_id'] ?? e['departmentId'])?.toString();
        deptOk = eDeptId == _selectedDeptId;
      }
      bool statusOk = _selectedStatus == 'all';
      if (!statusOk) {
        final isActive = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
        statusOk = _selectedStatus == 'active' ? isActive : !isActive;
      }
      return searchOk && deptOk && statusOk;
    }).toList();
  }

  void _applyFilters() => setState(_applyFiltersInline);

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() { _selectedDeptId = 'all'; _selectedStatus = 'all'; _applyFiltersInline(); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      _filterBar(),
      Expanded(child: _body()),
    ]);
  }

  Widget _filterBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _searchCtrl,
        style: AppTheme.body(13),
        decoration: InputDecoration(
          hintText: 'Search by name, email or ID...',
          hintStyle: AppTheme.label(13),
          prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
          filled: true, fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _dropFilter(
            value: _selectedDeptId, width: 190,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Departments')),
              ..._depts.map((d) => DropdownMenuItem(
                value: (d['id'] ?? d['_id'] ?? '').toString(),
                child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (v) => setState(() { _selectedDeptId = v ?? 'all'; _applyFiltersInline(); }),
          ),
          const SizedBox(width: 8),
          _dropFilter(
            value: _selectedStatus, width: 150,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() { _selectedStatus = v ?? 'all'; _applyFiltersInline(); }),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.surfaceElevated,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Clear Filters', style: AppTheme.label(12)),
          ),
        ]),
      ),
    ]),
  );

  Widget _dropFilter({required String value, required double width, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    SizedBox(
      width: width, height: 42,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(12), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
        ),
      ),
    );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    return Column(children: [
      // Sticky header synced with body scroll
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(
          controller: _hHeader,
          scrollDirection: Axis.horizontal,
          child: _headerRow(),
        ),
      ),
      Divider(color: AppTheme.divider, height: 1),
      Expanded(
        child: _filtered.isEmpty
          ? _emptyWidget('No employees found')
          : RefreshIndicator(
              onRefresh: _load, color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  controller: _hBody,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(_filtered.length, (i) => _empRow(_filtered[i], i.isOdd)),
                  ),
                ),
              ),
            ),
      ),
    ]);
  }

  Widget _headerRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      _th(230, 'Employee'),
      _th(90,  'Emp. ID'),
      _th(110, 'Role'),
      _th(150, 'Department'),
      _th(90,  'Status',  center: true),
      _th(130, 'Joined'),
      _th(100, 'Actions', center: true),
    ]),
  );

  Widget _empRow(Map<String, dynamic> e, bool alt) {
    String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
    if (name.isEmpty) name = (e['name'] ?? 'Unknown').toString();
    final email = (e['email'] ?? '').toString();
    final empId = (e['employeeId'] ?? e['empId'] ?? '').toString();
    final deptObj = e['department'] is Map ? e['department'] as Map : null;
    final dept = (deptObj?['name'] ?? e['departmentName'] ?? '').toString();
    final roleObj = e['role'] is Map ? e['role'] as Map : null;
    final role = (roleObj?['name'] ?? (e['role'] is String ? e['role'] : '') ?? '').toString();
    final isActive   = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
    final isVerified = e['isVerified'] == true || e['emailVerified'] == true;
    final joined = _fmtDate(e['createdAt'] ?? e['joinedAt'] ?? e['created_at'] ?? e['startDate']);
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 230, child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(13, color: ac, weight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.body(13), overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty) Text(email, style: AppTheme.label(10), overflow: TextOverflow.ellipsis),
            if (isVerified) Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text('Verified', style: AppTheme.label(9, color: const Color(0xFF4ADE80))),
            ),
          ])),
        ])),
        SizedBox(width: 90,  child: Text(empId.isNotEmpty ? empId : '—', style: AppTheme.label(12, color: AppTheme.primary, weight: FontWeight.w600))),
        SizedBox(width: 110, child: role.isNotEmpty ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.divider)),
          child: Text(role, style: AppTheme.label(11), overflow: TextOverflow.ellipsis),
        ) : Text('—', style: AppTheme.label(12))),
        SizedBox(width: 150, child: Text(dept.isNotEmpty ? dept : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 90,  child: Center(child: StatusBadge(status: isActive ? 'active' : 'inactive', fontSize: 11))),
        SizedBox(width: 130, child: Text(joined, style: AppTheme.label(12))),
        SizedBox(width: 100, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _iconBtn(Icons.visibility_outlined, () => _openEdit(e)),
          const SizedBox(width: 4),
          _iconBtn(Icons.edit_outlined, () => _openEdit(e)),
        ])),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: AppTheme.textSecondary)),
  );

  void _openEdit(Map<String, dynamic> e) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _EditEmployeeSheet(employee: e, onSaved: _load),
  );

  String _fmtDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    try { return DateFormat('d MMM yyyy').format(DateTime.parse(v.toString())); } catch (_) { return '—'; }
  }
}

// ── Departments Tab ────────────────────────────────────────────────────────────

class _DepartmentsTab extends StatefulWidget {
  const _DepartmentsTab();
  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  List<Map<String, dynamic>> _depts = [];
  Map<String, Map<String, dynamic>> _rowData = {};
  final Map<String, TextEditingController> _graceCtrl = {};
  Map<String, bool> _saving = {};
  bool _loading = true;
  String? _error;

  late final ScrollController _hHeader;
  late final ScrollController _hBody;
  bool _hSyncing = false;

  @override
  void initState() {
    super.initState();
    _hHeader = ScrollController();
    _hBody   = ScrollController();
    _hHeader.addListener(_onHeaderScroll);
    _hBody.addListener(_onBodyScroll);
    _load();
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

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    for (final c in _graceCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getDepartments();
      if (mounted) {
        final rowData = <String, Map<String, dynamic>>{};
        for (final d in data) {
          final id = (d['id'] ?? d['_id'] ?? '').toString();
          rowData[id] = {
            'startTime': _parseTime(d['shiftStart'] ?? d['startTime'] ?? d['shift_start'] ?? '10:00'),
            'endTime':   _parseTime(d['shiftEnd']   ?? d['endTime']   ?? d['shift_end']   ?? '18:00'),
            'grace':    _parseInt(d['gracePeriod'] ?? d['grace'] ?? d['graceMinutes'] ?? 15),
            'selfie':   d['requiresSelfie'] ?? d['selfie'] ?? false,
            'overtime': d['allowOvertime']  ?? d['overtime'] ?? false,
          };
        }
        for (final c in _graceCtrl.values) c.dispose();
        _graceCtrl.clear();
        for (final entry in rowData.entries) {
          _graceCtrl[entry.key] = TextEditingController(text: (entry.value['grace'] as int).toString());
        }
        setState(() { _depts = data; _rowData = rowData; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  TimeOfDay _parseTime(dynamic v) {
    try {
      final s = v.toString().trim().toUpperCase();
      final isPm = s.contains('PM');
      final clean = s.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = clean.split(':');
      int h = int.parse(parts[0]);
      final m = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (_) { return const TimeOfDay(hour: 10, minute: 0); }
  }

  int _parseInt(dynamic v) { try { return int.parse(v.toString()); } catch (_) { return 15; } }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _toApiTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save(Map<String, dynamic> dept) async {
    final id  = (dept['id'] ?? dept['_id'] ?? '').toString();
    final row = _rowData[id]; if (row == null) return;
    setState(() => _saving[id] = true);
    try {
      final grace = int.tryParse(_graceCtrl[id]?.text ?? '') ?? (row['grace'] as int);
      await ApiService().updateDepartment(id, {
        'shiftStart':    _toApiTime(row['startTime'] as TimeOfDay),
        'shiftEnd':      _toApiTime(row['endTime']   as TimeOfDay),
        'gracePeriod':   grace,
        'requiresSelfie': row['selfie'],
        'allowOvertime':  row['overtime'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally { if (mounted) setState(() => _saving.remove(id)); }
  }

  Future<void> _delete(Map<String, dynamic> dept) async {
    final id = (dept['id'] ?? dept['_id'] ?? '').toString();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Delete Department', style: AppTheme.heading(16)),
      content: Text('Delete "${dept['name']}"? Cannot be undone.', style: AppTheme.body(13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppTheme.label(13))),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Delete', style: AppTheme.label(13, color: AppTheme.error))),
      ],
    ));
    if (ok != true) return;
    try { await ApiService().deleteDepartment(id); _load(); }
    catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  void _openEdit(Map<String, dynamic> dept) {
    final id = (dept['id'] ?? dept['_id'] ?? '').toString();
    final row = _rowData[id] ?? {};
    showDialog(
      context: context,
      builder: (_) => _EditDepartmentDialog(
        dept: dept,
        row: row,
        onSaved: _load,
      ),
    );
  }

  void _newDept() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('New Department', style: AppTheme.heading(16)),
      content: TextField(controller: ctrl, autofocus: true, style: AppTheme.body(13),
        decoration: InputDecoration(hintText: 'Department name', hintStyle: AppTheme.label(13),
          filled: true, fillColor: AppTheme.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTheme.label(13))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context);
            try {
              await ApiService().createDepartment({'name': name, 'shiftStart': '10:00', 'shiftEnd': '18:00', 'gracePeriod': 15});
              _load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
            }
          },
          child: Text('Create', style: AppTheme.label(13, color: Colors.white)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Department Timings', style: AppTheme.heading(18)),
            const SizedBox(height: 3),
            Text('Set shift times and grace period per department.', style: AppTheme.label(12)),
          ])),
          ElevatedButton.icon(
            onPressed: _newDept,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: Text('New Department', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      ),
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(
          controller: _hHeader,
          scrollDirection: Axis.horizontal,
          child: _deptHeader(),
        ),
      ),
      Divider(color: AppTheme.divider, height: 1),
      Expanded(child: _depts.isEmpty
        ? _emptyWidget('No departments')
        : SingleChildScrollView(
            child: SingleChildScrollView(
              controller: _hBody,
              scrollDirection: Axis.horizontal,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _depts.map(_deptRow).toList()),
            ),
          )),
    ]);
  }

  Widget _deptHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      _th(170, 'Department'),
      _th(130, 'Start'),
      _th(130, 'End'),
      _th(100, 'Grace (Min)', center: true),
      _th(90,  'Selfie',   center: true),
      _th(100, 'Overtime', center: true),
      _th(310, 'Action',   center: true),
    ]),
  );

  Widget _deptRow(Map<String, dynamic> dept) {
    final id  = (dept['id'] ?? dept['_id'] ?? '').toString();
    final name = (dept['name'] ?? '').toString();
    final row = _rowData[id] ?? {'startTime': const TimeOfDay(hour: 10, minute: 0), 'endTime': const TimeOfDay(hour: 18, minute: 0), 'grace': 15, 'selfie': false, 'overtime': false};
    final isSaving = _saving[id] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 170, child: Text(name, style: AppTheme.body(13))),
        SizedBox(width: 130, child: _timePicker(value: row['startTime'] as TimeOfDay, onChanged: (t) => setState(() => _rowData[id] = {...row, 'startTime': t}))),
        SizedBox(width: 130, child: _timePicker(value: row['endTime']   as TimeOfDay, onChanged: (t) => setState(() => _rowData[id] = {...row, 'endTime': t}))),
        SizedBox(width: 100, child: Center(child: SizedBox(width: 65, child: TextField(
          controller: _graceCtrl[id], keyboardType: TextInputType.number, textAlign: TextAlign.center, style: AppTheme.body(12),
          decoration: InputDecoration(
            filled: true, fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        )))),
        SizedBox(width: 90,  child: Center(child: Switch(value: row['selfie']   as bool, onChanged: (v) => setState(() => _rowData[id] = {...row, 'selfie':   v}), activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        SizedBox(width: 100, child: Center(child: Switch(value: row['overtime'] as bool, onChanged: (v) => setState(() => _rowData[id] = {...row, 'overtime': v}), activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        SizedBox(width: 310, child: Row(children: [
          _deptBtn('Edit', Icons.edit_outlined, const Color(0xFF64748B), () => _openEdit(dept)),
          const SizedBox(width: 6),
          _deptBtn('Save', Icons.save_outlined, AppTheme.primary, isSaving ? null : () => _save(dept), loading: isSaving),
          const SizedBox(width: 6),
          _deptBtn('Delete', Icons.delete_outline, AppTheme.error, () => _delete(dept)),
        ])),
      ]),
    );
  }

  Widget _timePicker({required TimeOfDay value, required void Function(TimeOfDay) onChanged}) =>
    GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value,
          builder: (_, c) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: c!));
        if (t != null) onChanged(t);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.divider)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmtTime(value), style: AppTheme.body(12)),
          const SizedBox(width: 6),
          Icon(Icons.access_time, size: 13, color: AppTheme.textSecondary),
        ]),
      ),
    );

  Widget _deptBtn(String label, IconData icon, Color color, VoidCallback? onPressed, {bool loading = false}) =>
    ElevatedButton.icon(
      onPressed: onPressed,
      icon: loading
        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Icon(icon, size: 13, color: Colors.white),
      label: Text(label, style: AppTheme.label(12, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    );
}

// ── Edit Department Dialog ────────────────────────────────────────────────────

class _EditDepartmentDialog extends StatefulWidget {
  final Map<String, dynamic> dept;
  final Map<String, dynamic> row;
  final VoidCallback onSaved;
  const _EditDepartmentDialog({required this.dept, required this.row, required this.onSaved});
  @override State<_EditDepartmentDialog> createState() => _EditDepartmentDialogState();
}

class _EditDepartmentDialogState extends State<_EditDepartmentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _graceCtrl;
  late final TextEditingController _absencesCtrl;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _selfie;
  late bool _overtime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dept;
    final r = widget.row;
    _nameCtrl    = TextEditingController(text: (d['name'] ?? '').toString());
    _descCtrl    = TextEditingController(text: (d['description'] ?? '').toString());
    _graceCtrl   = TextEditingController(text: ((r['grace'] ?? d['gracePeriod'] ?? 15)).toString());
    _absencesCtrl = TextEditingController(text: ((d['allowedAbsences'] ?? d['allowedAbsencesPerMonth'] ?? 2)).toString());
    _startTime   = r['startTime'] is TimeOfDay ? r['startTime'] as TimeOfDay : const TimeOfDay(hour: 10, minute: 0);
    _endTime     = r['endTime'] is TimeOfDay ? r['endTime'] as TimeOfDay : const TimeOfDay(hour: 18, minute: 0);
    _selfie      = (r['selfie'] ?? d['requiresSelfie'] ?? false) == true;
    _overtime    = (r['overtime'] ?? d['allowOvertime'] ?? false) == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _graceCtrl.dispose(); _absencesCtrl.dispose();
    super.dispose();
  }

  String _toApiTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? "AM" : "PM"}';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = (widget.dept['id'] ?? widget.dept['_id'] ?? '').toString();
      await ApiService().updateDepartment(id, {
        'name': name,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'shiftStart': _toApiTime(_startTime),
        'shiftEnd': _toApiTime(_endTime),
        'gracePeriod': int.tryParse(_graceCtrl.text) ?? 15,
        'allowedAbsences': int.tryParse(_absencesCtrl.text) ?? 2,
        'requiresSelfie': _selfie,
        'allowOvertime': _overtime,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Edit Department', style: AppTheme.heading(16)),
      insetPadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Name'),
            const SizedBox(height: 6),
            _field(_nameCtrl, 'Department name'),
            const SizedBox(height: 14),
            _lbl('Description'),
            const SizedBox(height: 6),
            _field(_descCtrl, 'Optional description', maxLines: 2),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('Start Time'),
                const SizedBox(height: 6),
                _timePicker(_startTime, (t) => setState(() => _startTime = t)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('End Time'),
                const SizedBox(height: 6),
                _timePicker(_endTime, (t) => setState(() => _endTime = t)),
              ])),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('Grace Period (min)'),
                const SizedBox(height: 6),
                _numField(_graceCtrl),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _lbl('Allowed Absences/Month'),
                const SizedBox(height: 6),
                _numField(_absencesCtrl),
              ])),
            ]),
            const SizedBox(height: 14),
            _toggle('Require Selfie', _selfie, (v) => setState(() => _selfie = v)),
            const SizedBox(height: 8),
            _toggle('Allow Overtime', _overtime, (v) => setState(() => _overtime = v)),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTheme.label(13))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Save', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _lbl(String t) => Text(t, style: AppTheme.label(11, color: AppTheme.textSecondary));

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl, style: AppTheme.body(13), maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint, hintStyle: AppTheme.label(13),
      filled: true, fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
    ),
  );

  Widget _numField(TextEditingController ctrl) => TextField(
    controller: ctrl, style: AppTheme.body(13), keyboardType: TextInputType.number, textAlign: TextAlign.center,
    decoration: InputDecoration(
      filled: true, fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
    ),
  );

  Widget _timePicker(TimeOfDay value, void Function(TimeOfDay) onChanged) => GestureDetector(
    onTap: () async {
      final t = await showTimePicker(context: context, initialTime: value,
        builder: (_, c) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: c!));
      if (t != null) onChanged(t);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
      child: Row(children: [
        Expanded(child: Text(_fmtTime(value), style: AppTheme.body(13))),
        Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
      ]),
    ),
  );

  Widget _toggle(String label, bool value, void Function(bool) onChanged) => Row(children: [
    Expanded(child: Text(label, style: AppTheme.body(13))),
    Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
  ]);
}

// ── Edit Employee Sheet ───────────────────────────────────────────────────────

class _EditEmployeeSheet extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onSaved;
  const _EditEmployeeSheet({required this.employee, required this.onSaved});
  @override State<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends State<_EditEmployeeSheet> {
  late final TextEditingController _firstName, _lastName, _contact, _newPwd, _confirmPwd;
  bool _isTeamHead = false, _isActive = true, _saving = false, _deleting = false;
  bool _showReset = false, _obscureNew = true, _obscureConfirm = true, _settingPwd = false;
  String? _selectedDeptId, _selectedRoleName;
  List<Map<String, dynamic>> _depts = [], _roles = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _firstName  = TextEditingController(text: (e['firstName'] ?? e['first_name'] ?? '').toString());
    _lastName   = TextEditingController(text: (e['lastName']  ?? e['last_name']  ?? '').toString());
    _contact    = TextEditingController(text: (e['contactNumber'] ?? e['phone'] ?? e['contact'] ?? '').toString());
    _newPwd     = TextEditingController();
    _confirmPwd = TextEditingController();
    _isTeamHead = e['isTeamHead'] == true || e['isTeamHead'] == 1;
    _isActive   = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
    final deptObj = e['department'] is Map ? e['department'] as Map : null;
    _selectedDeptId  = (deptObj?['id'] ?? deptObj?['_id'] ?? e['departmentId'])?.toString();
    final roleObj = e['role'] is Map ? e['role'] as Map : null;
    _selectedRoleName = (roleObj?['name'] ?? (e['role'] is String ? e['role'] : null))?.toString();
    _loadMeta();
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _contact, _newPwd, _confirmPwd]) c.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final r = await Future.wait([ApiService().getDepartments(), ApiService().getRoles()]);
      if (mounted) setState(() { _depts = r[0] as List<Map<String, dynamic>>; _roles = r[1] as List<Map<String, dynamic>>; _loadingMeta = false; });
    } catch (_) { if (mounted) setState(() => _loadingMeta = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = (widget.employee['id'] ?? widget.employee['_id'] ?? '').toString();
      final body = <String, dynamic>{'firstName': _firstName.text.trim(), 'lastName': _lastName.text.trim(), 'isTeamHead': _isTeamHead};
      if (_contact.text.trim().isNotEmpty) body['contactNumber'] = _contact.text.trim();
      if (_selectedDeptId != null) body['departmentId'] = _selectedDeptId;
      if (_selectedRoleName != null) body['role'] = _selectedRoleName;
      await ApiService().updateEmployee(id, body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated'), backgroundColor: Color(0xFF4ADE80)));
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _toggleActive() async {
    final newActive = !_isActive;
    try {
      await ApiService().setEmployeeActive((widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), newActive);
      if (mounted) setState(() => _isActive = newActive);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _setPwd() async {
    final pw = _newPwd.text.trim();
    if (pw.isEmpty || pw.length < 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min 6 characters'), backgroundColor: AppTheme.error)); return; }
    if (pw != _confirmPwd.text.trim()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppTheme.error)); return; }
    setState(() => _settingPwd = true);
    try {
      await ApiService().resetEmployeePassword((widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), pw);
      _newPwd.clear(); _confirmPwd.clear(); setState(() => _showReset = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated'), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally { if (mounted) setState(() => _settingPwd = false); }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Delete Employee', style: AppTheme.heading(16)),
      content: Text('Permanently remove this account?', style: AppTheme.body(13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppTheme.label(13))),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Delete', style: AppTheme.label(13, color: AppTheme.error))),
      ],
    ));
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await ApiService().deleteEmployee((widget.employee['id'] ?? widget.employee['_id'] ?? '').toString());
      if (mounted) { widget.onSaved(); Navigator.pop(context); }
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
    if (name.isEmpty) name = (e['name'] ?? '').toString();
    final email      = (e['email'] ?? '').toString();
    final isVerified = e['isVerified'] == true || e['emailVerified'] == true || e['isEmailVerified'] == true;
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Edit Employee', style: AppTheme.heading(17)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20)),
            ]),
            const SizedBox(height: 16),
            Center(child: CircleAvatar(radius: 30, backgroundColor: ac.withOpacity(0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(22, color: ac, weight: FontWeight.w700)))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _field('First Name', _firstName)),
              const SizedBox(width: 12),
              Expanded(child: _field('Last Name', _lastName)),
            ]),
            const SizedBox(height: 14),
            _lbl('Email Address'), const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
              child: Row(children: [
                Expanded(child: Text(email, style: AppTheme.body(13, color: AppTheme.textSecondary))),
                if (isVerified) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('Verified', style: AppTheme.label(10, color: const Color(0xFF4ADE80)))),
              ]),
            ),
            const SizedBox(height: 14),
            _lbl('Department'), const SizedBox(height: 6),
            _loadingMeta
              ? const SizedBox(height: 42, child: LinearProgressIndicator(color: AppTheme.primary))
              : _dropdown(
                  value: _depts.any((d) => (d['id'] ?? d['_id'])?.toString() == _selectedDeptId) ? _selectedDeptId : null,
                  hint: 'Select department',
                  items: _depts.map((d) { final id = (d['id'] ?? d['_id'] ?? '').toString(); return DropdownMenuItem(value: id, child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis)); }).toList(),
                  onChanged: (v) => setState(() => _selectedDeptId = v),
                ),
            const SizedBox(height: 14),
            _lbl('Role'), const SizedBox(height: 6),
            _loadingMeta
              ? const SizedBox(height: 42, child: LinearProgressIndicator(color: AppTheme.primary))
              : _dropdown(
                  value: _roles.any((r) => (r['name'] ?? '').toString() == _selectedRoleName) ? _selectedRoleName : null,
                  hint: 'Select role',
                  items: _roles.map((r) { final n = (r['name'] ?? '').toString(); return DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis)); }).toList(),
                  onChanged: (v) => setState(() => _selectedRoleName = v),
                ),
            const SizedBox(height: 14),
            _field('Contact Number', _contact, type: TextInputType.phone),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Team Head', style: AppTheme.body(13)),
                  Text('Can assign visits to employees', style: AppTheme.label(11)),
                ])),
                Switch(value: _isTeamHead, onChanged: (v) => setState(() => _isTeamHead = v), activeColor: AppTheme.primary),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: AppTheme.divider), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text('Cancel', style: AppTheme.label(14)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Changes', style: AppTheme.label(14, color: Colors.white, weight: FontWeight.w600)),
              )),
            ]),
            const SizedBox(height: 24),
            Text('ACCOUNT ACTIONS', style: AppTheme.label(11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
              child: Column(children: [
                InkWell(
                  onTap: () => setState(() => _showReset = !_showReset),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                    Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Change Password', style: AppTheme.body(13))),
                    Icon(_showReset ? Icons.expand_less : Icons.expand_more, color: AppTheme.textSecondary, size: 18),
                  ])),
                ),
                if (_showReset) Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(children: [
                    _pwdField('New password', _newPwd, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                    const SizedBox(height: 8),
                    _pwdField('Confirm password', _confirmPwd, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _settingPwd ? null : _setPwd,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: _settingPwd
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Set Password', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
                    )),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isActive ? 'Deactivate Account' : 'Activate Account', style: AppTheme.body(13)),
                  Text(_isActive ? 'Block login' : 'Allow login', style: AppTheme.label(11)),
                ])),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _toggleActive,
                  icon: Icon(_isActive ? Icons.block : Icons.check_circle_outline, size: 14, color: Colors.white),
                  label: Text(_isActive ? 'Deactivate' : 'Activate', style: AppTheme.label(12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: _isActive ? const Color(0xFF64748B) : const Color(0xFF4ADE80), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.error.withOpacity(0.2))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Delete Permanently', style: AppTheme.body(13, color: AppTheme.error)),
                  Text('Irreversible — removes account', style: AppTheme.label(11)),
                ])),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                  label: Text('Delete', style: AppTheme.label(12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? type}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label), const SizedBox(height: 6),
      TextField(controller: ctrl, style: AppTheme.body(13), keyboardType: type,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        )),
    ]);

  Widget _pwdField(String hint, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
    TextField(controller: ctrl, obscureText: obscure, style: AppTheme.body(13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: AppTheme.label(13),
        filled: true, fillColor: AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary), onPressed: toggle),
      ));

  Widget _lbl(String t) => Text(t, style: AppTheme.label(12, color: AppTheme.textSecondary));

  Widget _dropdown({required String? value, required String hint, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(value: value, hint: Text(hint, style: AppTheme.label(13)), isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(13), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
      ),
    );
}

// ── Members Sheet ─────────────────────────────────────────────────────────────

class _MembersSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> members;
  const _MembersSheet({required this.title, required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Expanded(child: Text(title, style: AppTheme.heading(17))),
            Text('${members.length} members', style: AppTheme.label(12)),
          ]),
        ),
        Divider(color: AppTheme.divider, height: 1),
        members.isEmpty
          ? Padding(padding: const EdgeInsets.all(32), child: Text('No members found', style: AppTheme.label(14)))
          : Flexible(child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (_, __) => Divider(color: AppTheme.divider.withOpacity(0.5), height: 14),
              itemBuilder: (_, i) {
                final e = members[i];
                String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
                if (name.isEmpty) name = (e['name'] ?? 'Unknown').toString();
                final isActive = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
                final empId = (e['employeeId'] ?? e['empId'] ?? '').toString();
                final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
                final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];
                return Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: ac.withOpacity(0.15),
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(13, color: ac, weight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: AppTheme.body(13), overflow: TextOverflow.ellipsis),
                    if (empId.isNotEmpty) Text('ID: $empId', style: AppTheme.label(11)),
                  ])),
                  StatusBadge(status: isActive ? 'active' : 'inactive', fontSize: 10),
                ]);
              },
            )),
      ]),
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
