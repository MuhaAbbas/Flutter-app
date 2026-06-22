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
    _tab = TabController(length: 3, vsync: this);
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
        bottom: CustomTabBar(tabs: const ['Employees', 'Departments', 'Roles'], controller: _tab),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_EmployeesTab(), _DepartmentsTab(), _RolesTab()],
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

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_applyFilters); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([ApiService().getEmployees(), ApiService().getDepartments()]);
      if (mounted) setState(() {
        _all = r[0] as List<Map<String, dynamic>>;
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
      final name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final id = (e['employeeId'] ?? '').toString().toLowerCase();
      final searchOk = q.isEmpty || name.contains(q) || email.contains(q) || id.contains(q);
      bool deptOk = true;
      if (_selectedDeptId != 'all') {
        final dObj = e['department'] is Map ? e['department'] as Map : null;
        final eDeptId = (dObj?['id'] ?? dObj?['_id'] ?? e['departmentId'])?.toString();
        deptOk = eDeptId == _selectedDeptId;
      }
      bool statusOk = true;
      if (_selectedStatus != 'all') {
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
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(children: [
      Expanded(flex: 3, child: _searchField()),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: _dropFilter(
        value: _selectedDeptId,
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All Departments')),
          ..._depts.map((d) => DropdownMenuItem(
            value: (d['id'] ?? d['_id'] ?? '').toString(),
            child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis),
          )),
        ],
        onChanged: (v) => setState(() { _selectedDeptId = v ?? 'all'; _applyFiltersInline(); }),
      )),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: _dropFilter(
        value: _selectedStatus,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Status')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        ],
        onChanged: (v) => setState(() { _selectedStatus = v ?? 'all'; _applyFiltersInline(); }),
      )),
      const SizedBox(width: 10),
      TextButton(
        onPressed: _clearFilters,
        style: TextButton.styleFrom(
          backgroundColor: AppTheme.surfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Clear Filters', style: AppTheme.label(13)),
      ),
    ]),
  );

  Widget _searchField() => TextField(
    controller: _searchCtrl,
    style: AppTheme.body(13),
    decoration: InputDecoration(
      hintText: 'Search by name or email...',
      hintStyle: AppTheme.label(13),
      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
      filled: true, fillColor: AppTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary)),
    ),
  );

  Widget _dropFilter({required String value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(13), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
      ),
    );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    return Column(children: [
      // Table header
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _headerRow(),
        ),
      ),
      const Divider(color: AppTheme.divider, height: 1),
      Expanded(
        child: _filtered.isEmpty
            ? _emptyWidget('No employees found')
            : RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SingleChildScrollView(
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
      _th(240, 'Employee'),
      _th(90, 'Emp. ID'),
      _th(110, 'Role'),
      _th(150, 'Department'),
      _th(90, 'Status', center: true),
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
    final isActive = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
    final isVerified = e['isVerified'] == true || e['emailVerified'] == true;
    final joined = _fmtDate(e['createdAt'] ?? e['joinedAt'] ?? e['created_at'] ?? e['startDate']);
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // EMPLOYEE
        SizedBox(width: 240, child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.label(13, color: ac, weight: FontWeight.w700))),
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
        // EMP. ID
        SizedBox(width: 90, child: Text(empId.isNotEmpty ? empId : '—',
            style: AppTheme.label(12, color: AppTheme.primary, weight: FontWeight.w600))),
        // ROLE
        SizedBox(width: 110, child: role.isNotEmpty ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.divider)),
          child: Text(role, style: AppTheme.label(11)),
        ) : Text('—', style: AppTheme.label(12))),
        // DEPARTMENT
        SizedBox(width: 150, child: Text(dept.isNotEmpty ? dept : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis)),
        // STATUS
        SizedBox(width: 90, child: Center(child: StatusBadge(status: isActive ? 'active' : 'inactive', fontSize: 11))),
        // JOINED
        SizedBox(width: 130, child: Text(joined, style: AppTheme.label(12))),
        // ACTIONS
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

// ── Departments Tab (Department Timings) ──────────────────────────────────────

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

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
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
            'endTime': _parseTime(d['shiftEnd'] ?? d['endTime'] ?? d['shift_end'] ?? '18:00'),
            'grace': _parseInt(d['gracePeriod'] ?? d['grace'] ?? d['graceMinutes'] ?? 15),
            'selfie': d['requiresSelfie'] ?? d['selfie'] ?? false,
            'overtime': d['allowOvertime'] ?? d['overtime'] ?? false,
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

  String _toApiTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save(Map<String, dynamic> dept) async {
    final id = (dept['id'] ?? dept['_id'] ?? '').toString();
    final row = _rowData[id];
    if (row == null) return;
    setState(() => _saving[id] = true);
    try {
      final grace = int.tryParse(_graceCtrl[id]?.text ?? '') ?? (row['grace'] as int);
      await ApiService().updateDepartment(id, {
        'shiftStart': _toApiTime(row['startTime'] as TimeOfDay),
        'shiftEnd': _toApiTime(row['endTime'] as TimeOfDay),
        'gracePeriod': grace,
        'requiresSelfie': row['selfie'],
        'allowOvertime': row['overtime'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully'), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> dept) async {
    final id = (dept['id'] ?? dept['_id'] ?? '').toString();
    final name = dept['name'] ?? 'this department';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Department', style: AppTheme.heading(16)),
        content: Text('Delete "$name"? This cannot be undone.', style: AppTheme.body(13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppTheme.label(13))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: AppTheme.label(13, color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deleteDepartment(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  void _newDept() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('New Department', style: AppTheme.heading(16)),
        content: TextField(
          controller: ctrl, autofocus: true, style: AppTheme.body(13),
          decoration: InputDecoration(
            hintText: 'Department name', hintStyle: AppTheme.label(13),
            filled: true, fillColor: AppTheme.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.divider)),
          ),
        ),
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
      ),
    );
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
            Text('Set shift start/end time and late-arrival grace period per department.', style: AppTheme.label(12)),
          ])),
          ElevatedButton.icon(
            onPressed: _newDept,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: Text('New Department', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(color: AppTheme.background, border: Border(bottom: BorderSide(color: AppTheme.divider))),
                child: Row(children: [
                  _th(170, 'Department'),
                  _th(130, 'Start'),
                  _th(130, 'End'),
                  _th(100, 'Grace (Min)', center: true),
                  _th(90, 'Selfie', center: true),
                  _th(100, 'Overtime', center: true),
                  _th(230, 'Action', center: true),
                ]),
              ),
              if (_depts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No departments', style: AppTheme.label(14)),
                )
              else
                ..._depts.map(_deptRow),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _deptRow(Map<String, dynamic> dept) {
    final id = (dept['id'] ?? dept['_id'] ?? '').toString();
    final name = (dept['name'] ?? '').toString();
    final row = _rowData[id] ?? {'startTime': const TimeOfDay(hour: 10, minute: 0), 'endTime': const TimeOfDay(hour: 18, minute: 0), 'grace': 15, 'selfie': false, 'overtime': false};
    final isSaving = _saving[id] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: AppTheme.surface, border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 170, child: Text(name, style: AppTheme.body(13))),
        // Start time
        SizedBox(width: 130, child: _timePicker(value: row['startTime'] as TimeOfDay, onChanged: (t) => setState(() => _rowData[id] = {...row, 'startTime': t}))),
        // End time
        SizedBox(width: 130, child: _timePicker(value: row['endTime'] as TimeOfDay, onChanged: (t) => setState(() => _rowData[id] = {...row, 'endTime': t}))),
        // Grace
        SizedBox(width: 100, child: Center(child: SizedBox(width: 65, child: TextField(
          controller: _graceCtrl[id],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: AppTheme.body(12),
          decoration: InputDecoration(
            filled: true, fillColor: AppTheme.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        )))),
        // Selfie
        SizedBox(width: 90, child: Center(child: Switch(value: row['selfie'] as bool, onChanged: (v) => setState(() => _rowData[id] = {...row, 'selfie': v}), activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        // Overtime
        SizedBox(width: 100, child: Center(child: Switch(value: row['overtime'] as bool, onChanged: (v) => setState(() => _rowData[id] = {...row, 'overtime': v}), activeColor: AppTheme.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
        // Actions
        SizedBox(width: 230, child: Row(children: [
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
        final t = await showTimePicker(
          context: context, initialTime: value,
          builder: (_, c) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: c!),
        );
        if (t != null) onChanged(t);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.divider)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmtTime(value), style: AppTheme.body(12)),
          const SizedBox(width: 6),
          const Icon(Icons.access_time, size: 13, color: AppTheme.textSecondary),
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
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
}

// ── Roles Tab ─────────────────────────────────────────────────────────────────

class _RolesTab extends StatefulWidget {
  const _RolesTab();
  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  List<Map<String, dynamic>> _roles = [], _employees = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([ApiService().getRoles(), ApiService().getEmployees()]);
      if (mounted) setState(() {
        _roles = r[0] as List<Map<String, dynamic>>;
        _employees = r[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _membersOf(String roleName) => _employees.where((e) {
    final roleRaw = e['role'];
    final rName = roleRaw is Map ? (roleRaw['name'] ?? '').toString() : (roleRaw ?? '').toString();
    return rName.toLowerCase() == roleName.toLowerCase();
  }).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_roles.isEmpty) return _emptyWidget('No roles found');
    final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC)];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roles.length,
      itemBuilder: (_, i) {
        final r = _roles[i];
        final name = (r['name'] ?? r['roleName'] ?? '').toString();
        final perms = r['permissions'] ?? r['level'] ?? r['permissionLevel'] ?? '';
        final color = colors[i % colors.length];
        final members = _membersOf(name);
        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
            builder: (_) => _MembersSheet(title: name, members: members),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)]),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.admin_panel_settings_outlined, color: color, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppTheme.body(14)),
                if (perms.toString().isNotEmpty) Text('Permission Level: ${perms.toString()}', style: AppTheme.label(11)),
                Text('${members.length} employees', style: AppTheme.label(11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('${members.length}', style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Edit Employee Sheet ───────────────────────────────────────────────────────

class _EditEmployeeSheet extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onSaved;
  const _EditEmployeeSheet({required this.employee, required this.onSaved});
  @override
  State<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends State<_EditEmployeeSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _contact;
  late final TextEditingController _newPassword;
  late final TextEditingController _confirmPassword;

  bool _isTeamHead = false;
  bool _isActive = true;
  String? _selectedDeptId;
  String? _selectedRoleName;
  bool _saving = false;
  bool _deleting = false;
  bool _showReset = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _settingPassword = false;
  List<Map<String, dynamic>> _depts = [];
  List<Map<String, dynamic>> _roles = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _firstName = TextEditingController(text: (e['firstName'] ?? e['first_name'] ?? '').toString());
    _lastName  = TextEditingController(text: (e['lastName']  ?? e['last_name']  ?? '').toString());
    _contact   = TextEditingController(text: (e['contactNumber'] ?? e['phone'] ?? e['contact'] ?? '').toString());
    _newPassword     = TextEditingController();
    _confirmPassword = TextEditingController();
    _isTeamHead = e['isTeamHead'] == true || e['isTeamHead'] == 1;
    _isActive   = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
    final deptObj = e['department'] is Map ? e['department'] as Map : null;
    _selectedDeptId = (deptObj?['id'] ?? deptObj?['_id'] ?? e['departmentId'])?.toString();
    final roleObj = e['role'] is Map ? e['role'] as Map : null;
    _selectedRoleName = (roleObj?['name'] ?? (e['role'] is String ? e['role'] : null))?.toString();
    _loadMeta();
  }

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _contact.dispose();
    _newPassword.dispose(); _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final r = await Future.wait([ApiService().getDepartments(), ApiService().getRoles()]);
      if (mounted) setState(() {
        _depts = r[0] as List<Map<String, dynamic>>;
        _roles = r[1] as List<Map<String, dynamic>>;
        _loadingMeta = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = (widget.employee['id'] ?? widget.employee['_id'] ?? '').toString();
      final body = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'isTeamHead': _isTeamHead,
      };
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive() async {
    final newActive = !_isActive;
    try {
      await ApiService().setEmployeeActive((widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), newActive);
      if (mounted) setState(() => _isActive = newActive);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newActive ? 'Account activated' : 'Account deactivated'),
          backgroundColor: newActive ? const Color(0xFF4ADE80) : AppTheme.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _setPassword() async {
    final pw = _newPassword.text.trim();
    final cpw = _confirmPassword.text.trim();
    if (pw.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a new password'), backgroundColor: AppTheme.error)); return; }
    if (pw.length < 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: AppTheme.error)); return; }
    if (pw != cpw) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppTheme.error)); return; }
    setState(() => _settingPassword = true);
    try {
      await ApiService().resetEmployeePassword((widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), pw);
      _newPassword.clear(); _confirmPassword.clear();
      setState(() => _showReset = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully'), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _settingPassword = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Employee', style: AppTheme.heading(16)),
        content: Text('This is irreversible. The account will be permanently removed.', style: AppTheme.body(13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppTheme.label(13))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: AppTheme.label(13, color: AppTheme.error))),
        ],
      ),
    );
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
    final email = (e['email'] ?? '').toString();
    final isVerified = e['isVerified'] == true || e['emailVerified'] == true || e['isEmailVerified'] == true;
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Edit Employee', style: AppTheme.heading(17)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20)),
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
            _lbl('Email Address'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
              child: Row(children: [
                Expanded(child: Text(email, style: AppTheme.body(13, color: AppTheme.textSecondary))),
                if (isVerified) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF4ADE80).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('Verified', style: AppTheme.label(10, color: const Color(0xFF4ADE80))),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            _lbl('Department'),
            const SizedBox(height: 6),
            _loadingMeta
                ? const SizedBox(height: 42, child: LinearProgressIndicator(color: AppTheme.primary))
                : _dropdown(
                    value: _depts.any((d) => (d['id'] ?? d['_id'])?.toString() == _selectedDeptId) ? _selectedDeptId : null,
                    hint: 'Select department',
                    items: _depts.map((d) { final id = (d['id'] ?? d['_id'] ?? '').toString(); return DropdownMenuItem(value: id, child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis)); }).toList(),
                    onChanged: (v) => setState(() => _selectedDeptId = v),
                  ),
            const SizedBox(height: 14),
            _lbl('Role'),
            const SizedBox(height: 6),
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
                  Text('Can assign visits to any employee', style: AppTheme.label(11)),
                ])),
                Switch(value: _isTeamHead, onChanged: (v) => setState(() => _isTeamHead = v), activeColor: AppTheme.primary),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: AppTheme.divider), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text('Cancel', style: AppTheme.label(14)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Save Changes', style: AppTheme.label(14, color: Colors.white, weight: FontWeight.w600)),
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
                    const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Change Password', style: AppTheme.body(13))),
                    Icon(_showReset ? Icons.expand_less : Icons.expand_more, color: AppTheme.textSecondary, size: 18),
                  ])),
                ),
                if (_showReset) Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(children: [
                    TextField(
                      controller: _newPassword, obscureText: _obscureNew, style: AppTheme.body(13),
                      decoration: InputDecoration(
                        hintText: 'New password', hintStyle: AppTheme.label(13),
                        filled: true, fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
                        suffixIcon: IconButton(icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary), onPressed: () => setState(() => _obscureNew = !_obscureNew)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPassword, obscureText: _obscureConfirm, style: AppTheme.body(13),
                      decoration: InputDecoration(
                        hintText: 'Confirm password', hintStyle: AppTheme.label(13),
                        filled: true, fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
                        suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: _settingPassword ? null : _setPassword,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: _settingPassword ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Set Password', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
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
                  Text(_isActive ? 'Prevent this employee from logging in' : 'Allow this employee to log in', style: AppTheme.label(11)),
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
                  Text('Irreversible — removes the account entirely', style: AppTheme.label(11)),
                ])),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.delete_outline, size: 14, color: Colors.white),
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
      TextField(
        controller: ctrl, style: AppTheme.body(13), keyboardType: type,
        decoration: InputDecoration(
          filled: true, fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        ),
      ),
    ]);

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
      decoration: const BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Expanded(child: Text(title, style: AppTheme.heading(17))),
            const SizedBox(width: 8),
            Text('${members.length} members', style: AppTheme.label(12)),
          ]),
        ),
        const Divider(color: AppTheme.divider, height: 1),
        members.isEmpty
            ? Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 10),
                Text('No members found', style: AppTheme.label(14)),
              ]))
            : Flexible(child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                separatorBuilder: (_, __) => Divider(color: AppTheme.divider.withOpacity(0.5), height: 14),
                itemBuilder: (_, idx) {
                  final e = members[idx];
                  String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
                  if (name.isEmpty) name = (e['name'] ?? 'Unknown').toString();
                  final isActive = e['isActive'] == true || e['isActive'] == 1 || e['status']?.toString().toLowerCase() == 'active';
                  final empId = (e['employeeId'] ?? e['empId'] ?? '').toString();
                  final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
                  final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];
                  return Row(children: [
                    CircleAvatar(radius: 18, backgroundColor: ac.withOpacity(0.15), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(13, color: ac, weight: FontWeight.w700))),
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
