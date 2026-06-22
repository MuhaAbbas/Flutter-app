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

class _EmployeesTabState extends State<_EmployeesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    super.build(context);
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
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _showEditSheet(_filtered[i]),
            child: _card(_filtered[i]),
          ),
        );
      }),
    );
  }

  void _showEditSheet(Map<String, dynamic> e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditEmployeeSheet(employee: e, onSaved: _load),
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

class _DepartmentsTabState extends State<_DepartmentsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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

  // Match by ID first, then fall back to name comparison
  bool _matches(Map<String, dynamic> emp, Map<String, dynamic> dept) {
    final deptId = (dept['id'] ?? dept['_id'])?.toString();
    final deptName = (dept['name'] ?? '').toString().toLowerCase();
    final dObj = emp['department'] is Map ? emp['department'] as Map : null;
    final eDeptId = (dObj?['id'] ?? dObj?['_id'] ?? emp['departmentId'])?.toString();
    final eDeptName = (dObj?['name'] ?? emp['departmentName'] ?? '').toString().toLowerCase();
    if (deptId != null && deptId.isNotEmpty && eDeptId != null && eDeptId.isNotEmpty && deptId == eDeptId) return true;
    if (deptName.isNotEmpty && eDeptName.isNotEmpty && deptName == eDeptName) return true;
    return false;
  }

  int _count(Map<String, dynamic> dept) => _employees.where((e) => _matches(e, dept)).length;
  List<Map<String, dynamic>> _membersOf(Map<String, dynamic> dept) =>
      _employees.where((e) => _matches(e, dept)).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        final count = _count(d);
        final color = colors[i % colors.length];
        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _MembersSheet(title: name, members: _membersOf(d)),
          ),
          child: Container(
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
                Text(name, style: AppTheme.body(14)),
                Text('$count members', style: AppTheme.label(12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: GoogleFonts.poppins(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
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

class _RolesTabState extends State<_RolesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    final rName = roleRaw is Map
        ? (roleRaw['name'] ?? '').toString()
        : (roleRaw ?? '').toString();
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
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _MembersSheet(title: name, members: members),
          ),
          child: Container(
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
                Text(name, style: AppTheme.body(14)),
                if (perms.toString().isNotEmpty)
                  Text('Permission Level: ${perms.toString()}', style: AppTheme.label(11)),
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
    _isActive   = e['isActive'] == true || e['isActive'] == 1 ||
        e['status']?.toString().toLowerCase() == 'active';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Employee updated'), backgroundColor: Color(0xFF4ADE80)));
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive() async {
    final newActive = !_isActive;
    try {
      await ApiService().setEmployeeActive(
          (widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), newActive);
      if (mounted) setState(() => _isActive = newActive);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newActive ? 'Account activated' : 'Account deactivated'),
          backgroundColor: newActive ? const Color(0xFF4ADE80) : AppTheme.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error));
    }
  }

  Future<void> _setPassword() async {
    final pw = _newPassword.text.trim();
    final cpw = _confirmPassword.text.trim();
    if (pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a new password'), backgroundColor: AppTheme.error));
      return;
    }
    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters'), backgroundColor: AppTheme.error));
      return;
    }
    if (pw != cpw) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Passwords do not match'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _settingPassword = true);
    try {
      await ApiService().resetEmployeePassword(
          (widget.employee['id'] ?? widget.employee['_id'] ?? '').toString(), pw);
      _newPassword.clear(); _confirmPassword.clear();
      setState(() => _showReset = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated successfully'), backgroundColor: Color(0xFF4ADE80)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error));
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
        content: Text('This is irreversible. The account will be permanently removed.',
            style: AppTheme.body(13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: AppTheme.label(13))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: AppTheme.label(13, color: AppTheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await ApiService().deleteEmployee(
          (widget.employee['id'] ?? widget.employee['_id'] ?? '').toString());
      if (mounted) { widget.onSaved(); Navigator.pop(context); }
    } catch (e) {
      if (mounted) setState(() => _deleting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppTheme.error));
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header
            Row(children: [
              Text('Edit Employee', style: AppTheme.heading(17)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20)),
            ]),
            const SizedBox(height: 16),

            // Avatar
            Center(child: CircleAvatar(
              radius: 30, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.label(22, color: ac, weight: FontWeight.w700)),
            )),
            const SizedBox(height: 20),

            // Name row
            Row(children: [
              Expanded(child: _field('First Name', _firstName)),
              const SizedBox(width: 12),
              Expanded(child: _field('Last Name', _lastName)),
            ]),
            const SizedBox(height: 14),

            // Email (readonly)
            _lbl('Email Address'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(children: [
                Expanded(child: Text(email, style: AppTheme.body(13, color: AppTheme.textSecondary))),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Verified', style: AppTheme.label(10, color: const Color(0xFF4ADE80))),
                  ),
              ]),
            ),
            const SizedBox(height: 14),

            // Department
            _lbl('Department'),
            const SizedBox(height: 6),
            _loadingMeta
                ? const SizedBox(height: 42, child: LinearProgressIndicator(color: AppTheme.primary))
                : _dropdown(
                    value: _depts.any((d) => (d['id'] ?? d['_id'])?.toString() == _selectedDeptId)
                        ? _selectedDeptId : null,
                    hint: 'Select department',
                    items: _depts.map((d) {
                      final id = (d['id'] ?? d['_id'] ?? '').toString();
                      return DropdownMenuItem(value: id, child: Text((d['name'] ?? '').toString(), overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedDeptId = v),
                  ),
            const SizedBox(height: 14),

            // Role
            _lbl('Role'),
            const SizedBox(height: 6),
            _loadingMeta
                ? const SizedBox(height: 42, child: LinearProgressIndicator(color: AppTheme.primary))
                : _dropdown(
                    value: _roles.any((r) => (r['name'] ?? '').toString() == _selectedRoleName)
                        ? _selectedRoleName : null,
                    hint: 'Select role',
                    items: _roles.map((r) {
                      final n = (r['name'] ?? '').toString();
                      return DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRoleName = v),
                  ),
            const SizedBox(height: 14),

            // Contact
            _field('Contact Number', _contact, type: TextInputType.phone),
            const SizedBox(height: 14),

            // Team Head toggle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Team Head', style: AppTheme.body(13)),
                  Text('Can assign visits to any employee', style: AppTheme.label(11)),
                ])),
                Switch(value: _isTeamHead, onChanged: (v) => setState(() => _isTeamHead = v),
                    activeColor: AppTheme.primary),
              ]),
            ),
            const SizedBox(height: 20),

            // Save / Cancel
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Cancel', style: AppTheme.label(14)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes',
                        style: AppTheme.label(14, color: Colors.white, weight: FontWeight.w600)),
              )),
            ]),
            const SizedBox(height: 24),

            // Account actions header
            Text('ACCOUNT ACTIONS', style: AppTheme.label(11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),

            // Change Password (admin sets directly)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(children: [
                InkWell(
                  onTap: () => setState(() => _showReset = !_showReset),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Change Password', style: AppTheme.body(13))),
                      Icon(_showReset ? Icons.expand_less : Icons.expand_more,
                          color: AppTheme.textSecondary, size: 18),
                    ]),
                  ),
                ),
                if (_showReset)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(children: [
                      // New password
                      TextField(
                        controller: _newPassword,
                        obscureText: _obscureNew,
                        style: AppTheme.body(13),
                        decoration: InputDecoration(
                          hintText: 'New password',
                          hintStyle: AppTheme.label(13),
                          filled: true, fillColor: AppTheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18, color: AppTheme.textSecondary),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Confirm password
                      TextField(
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        style: AppTheme.body(13),
                        decoration: InputDecoration(
                          hintText: 'Confirm password',
                          hintStyle: AppTheme.label(13),
                          filled: true, fillColor: AppTheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18, color: AppTheme.textSecondary),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _settingPassword ? null : _setPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _settingPassword
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Set Password', style: AppTheme.label(13, color: Colors.white, weight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 10),

            // Deactivate / Activate
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isActive ? 'Deactivate Account' : 'Activate Account', style: AppTheme.body(13)),
                  Text(_isActive ? 'Prevent this employee from logging in'
                      : 'Allow this employee to log in', style: AppTheme.label(11)),
                ])),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _toggleActive,
                  icon: Icon(_isActive ? Icons.block : Icons.check_circle_outline,
                      size: 14, color: Colors.white),
                  label: Text(_isActive ? 'Deactivate' : 'Activate',
                      style: AppTheme.label(12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isActive ? const Color(0xFF64748B) : const Color(0xFF4ADE80),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),

            // Delete Permanently
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Delete Permanently', style: AppTheme.body(13, color: AppTheme.error)),
                  Text('Irreversible — removes the account entirely', style: AppTheme.label(11)),
                ])),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting
                      ? const SizedBox(width: 12, height: 12,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                  label: Text('Delete', style: AppTheme.label(12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, hint: Text(hint, style: AppTheme.label(13)),
        isExpanded: true, dropdownColor: AppTheme.surfaceElevated,
        style: AppTheme.body(13), iconEnabledColor: AppTheme.textSecondary,
        items: items, onChanged: onChanged,
      ),
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
        ),
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
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 10),
                  Text('No members found', style: AppTheme.label(14)),
                ]),
              )
            : Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => Divider(color: AppTheme.divider.withOpacity(0.5), height: 14),
                  itemBuilder: (_, idx) {
                    final e = members[idx];
                    String name = '${e['firstName'] ?? e['first_name'] ?? ''} ${e['lastName'] ?? e['last_name'] ?? ''}'.trim();
                    if (name.isEmpty) name = (e['name'] ?? 'Unknown').toString();
                    final isActive = e['isActive'] == true || e['isActive'] == 1 ||
                        e['status']?.toString().toLowerCase() == 'active';
                    final empId = (e['employeeId'] ?? e['empId'] ?? '').toString();
                    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
                    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];
                    return Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: ac.withOpacity(0.15),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTheme.label(13, color: ac, weight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: AppTheme.body(13), overflow: TextOverflow.ellipsis),
                        if (empId.isNotEmpty) Text('ID: $empId', style: AppTheme.label(11)),
                      ])),
                      StatusBadge(status: isActive ? 'active' : 'inactive', fontSize: 10),
                    ]);
                  },
                ),
              ),
      ]),
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
