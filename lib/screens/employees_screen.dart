import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
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
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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

class _EmployeesTabState extends State<_EmployeesTab> {
  List<Map<String, dynamic>> _all = [], _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getEmployees();
      if (mounted) setState(() { _all = data; _filtered = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _all : _all.where((e) {
        final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.toLowerCase();
        final dept = (e['department']?['name'] ?? e['departmentName'] ?? '').toString().toLowerCase();
        final id = (e['employeeId'] ?? '').toString().toLowerCase();
        return name.contains(q) || dept.contains(q) || id.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: TextField(
          controller: _searchCtrl,
          style: AppTheme.body(13),
          decoration: InputDecoration(
            hintText: 'Search by name, ID, or department...',
            hintStyle: AppTheme.label(13),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(child: _body()),
    ]);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_filtered.isEmpty) return _emptyWidget('No employees found');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: cols == 1 ? 3.5 : 1.9,
          ),
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _card(_filtered[i]),
        );
      }),
    );
  }

  Widget _card(Map<String, dynamic> e) {
    // Multiple field-name variants for each field
    String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
    if (name.isEmpty) name = (e['name'] ?? e['fullName'] ?? e['displayName'] ?? '').toString().trim();

    final empId = (e['employeeId'] ?? e['empId'] ?? e['employeeCode'] ?? e['emp_id'] ?? e['employee_id'] ?? '').toString();

    final deptObj = e['department'] is Map ? e['department'] as Map : null;
    final dept = (deptObj?['name'] ?? e['departmentName'] ?? e['dept_name'] ?? '').toString();

    final roleObj = e['role'] is Map ? e['role'] as Map : null;
    final role = (roleObj?['name'] ?? e['roleName'] ?? e['designation'] ?? e['position'] ?? (e['role'] is String ? e['role'] : '')).toString();

    final isActive = e['isActive'] == true || e['isActive'] == 1 ||
        e['status']?.toString().toLowerCase() == 'active';
    final email = (e['email'] ?? '').toString();
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ac.withOpacity(0.15),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTheme.label(16, color: ac, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name.isEmpty ? 'Unknown' : name,
                    style: AppTheme.body(13), overflow: TextOverflow.ellipsis)),
                StatusBadge(status: isActive ? 'active' : 'inactive', fontSize: 10),
              ]),
              if (role.isNotEmpty) Text(role.toString(), style: AppTheme.label(11), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (empId.toString().isNotEmpty) _chip(Icons.badge_outlined, empId.toString()),
              if (dept.toString().isNotEmpty) _chip(Icons.business_outlined, dept.toString()),
              if (email.toString().isNotEmpty) _chip(Icons.email_outlined, email.toString()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 11, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Expanded(child: Text(text, style: AppTheme.label(10), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ── Departments Tab ───────────────────────────────────────────────────────────

class _DepartmentsTab extends StatefulWidget {
  const _DepartmentsTab();
  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> {
  List<Map<String, dynamic>> _depts = [], _employees = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([ApiService().getDepartments(), ApiService().getEmployees()]);
      if (mounted) setState(() {
        _depts = r[0] as List<Map<String, dynamic>>;
        _employees = r[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _count(dynamic id) => _employees.where((e) {
    final dObj = e['department'] is Map ? e['department'] as Map : null;
    final dId = dObj?['id'] ?? dObj?['_id'] ?? e['departmentId'];
    return dId?.toString() == id?.toString();
  }).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_depts.isEmpty) return _emptyWidget('No departments found');
    final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24), const Color(0xFFF87171)];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _depts.length,
      itemBuilder: (_, i) {
        final d = _depts[i];
        final name = (d['name'] ?? d['departmentName'] ?? d['title'] ?? '').toString();
        final deptId = d['id'] ?? d['_id'] ?? d['departmentId'];
        final count = _count(deptId);
        final color = colors[i % colors.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: color, width: 3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.business, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.toString(), style: AppTheme.body(14)),
              Text('$count members', style: AppTheme.label(12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: GoogleFonts.poppins(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      },
    );
  }
}

// ── Roles Tab ─────────────────────────────────────────────────────────────────

class _RolesTab extends StatefulWidget {
  const _RolesTab();
  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getRoles();
      if (mounted) setState(() { _roles = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_roles.isEmpty) return _emptyWidget('No roles found');
    final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC)];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _roles.length,
      itemBuilder: (_, i) {
        final r = _roles[i];
        final name = r['name'] ?? r['roleName'] ?? '';
        final perms = r['permissions'] ?? r['level'] ?? r['permissionLevel'] ?? '';
        final color = colors[i % colors.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.admin_panel_settings_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.toString(), style: AppTheme.body(14)),
              if (perms.toString().isNotEmpty)
                Text('Permission Level: ${perms.toString()}', style: AppTheme.label(11)),
            ])),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary.withOpacity(0.5)),
          ]),
        );
      },
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
