import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _roles = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService().getEmployees(),
      ApiService().getDepartments(),
      ApiService().getRoles(),
    ]);
    setState(() {
      _employees = results[0] as List<Map<String, dynamic>>;
      _departments = results[1] as List<Map<String, dynamic>>;
      _roles = results[2] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Employees', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'Employees'),
            Tab(text: 'Departments'),
            Tab(text: 'Roles'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(),
                _buildDepartmentsTab(),
                _buildRolesTab(),
              ],
            ),
    );
  }

  // ── EMPLOYEES TAB ────────────────────────────────────────────────────────────

  Widget _buildEmployeesTab() {
    final filtered = _employees.where((e) {
      if (_search.isEmpty) return true;
      final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.toLowerCase();
      final email = (e['email'] ?? '').toLowerCase();
      return name.contains(_search.toLowerCase()) || email.contains(_search.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text('${filtered.length} employees', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No employees found', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _employeeCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _employeeCard(Map<String, dynamic> e) {
    final firstName = (e['firstName'] ?? '').toString();
    final lastName = (e['lastName'] ?? '').toString();
    final name = '$firstName $lastName'.trim();
    final email = e['email'] ?? '';
    final empId = e['employeeId'] ?? e['empId'] ?? '';
    final role = e['role']?['name'] ?? e['roleName'] ?? e['role'] ?? '';
    final dept = e['department']?['name'] ?? e['departmentName'] ?? '';
    final isActive = e['isActive'] == true || e['isActive'] == 1;
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    final colors = [
      const Color(0xFF3B82F6), Colors.purple, Colors.teal, Colors.orange, Colors.pink,
    ];
    final colorIdx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    final avatarColor = colors[colorIdx];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor.withValues(alpha: 0.2),
                child: Text(initials.isEmpty ? '?' : initials,
                    style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name.isEmpty ? email : name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.red).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                  color: isActive ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (empId.toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(empId.toString(),
                                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (dept.toString().isNotEmpty)
                          Expanded(
                            child: Text(dept.toString(),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                        if (role.toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(role.toString(),
                                style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionIconBtn(Icons.history_outlined, Colors.teal, 'Travel History',
                  () => _showTravelHistory(e)),
              const SizedBox(width: 8),
              _actionIconBtn(Icons.edit_outlined, const Color(0xFF3B82F6), 'Edit',
                  () => _showEditDialog(e)),
              const SizedBox(width: 8),
              _actionIconBtn(Icons.delete_outline, Colors.red, 'Delete',
                  () => _confirmDelete(e)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIconBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(tooltip, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── EDIT EMPLOYEE DIALOG ─────────────────────────────────────────────────────

  void _showEditDialog(Map<String, dynamic> e) {
    final id = e['id']?.toString() ?? '';
    final firstCtrl = TextEditingController(text: e['firstName'] ?? '');
    final lastCtrl = TextEditingController(text: e['lastName'] ?? '');
    final emailCtrl = TextEditingController(text: e['email'] ?? '');
    final phoneCtrl = TextEditingController(text: e['contactNumber'] ?? e['phone'] ?? '');
    final pwdCtrl = TextEditingController();

    String selectedRoleId = e['roleId']?.toString() ?? e['role']?['id']?.toString() ?? '';
    String selectedDeptId = e['departmentId']?.toString() ?? e['department']?['id']?.toString() ?? '';
    bool isTeamHead = e['isTeamHead'] ?? false;
    bool isActive = e['isActive'] ?? true;
    bool savingMain = false;
    bool resetExpanded = false;
    bool resetSaving = false;
    bool deactivating = false;
    bool deleting = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Text('Edit Employee',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                child: Text(
                                  '${firstCtrl.text.isNotEmpty ? firstCtrl.text[0] : ''}${lastCtrl.text.isNotEmpty ? lastCtrl.text[0] : ''}'.toUpperCase(),
                                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Click the icon to upload a photo',
                                  style: TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name row
                        Row(
                          children: [
                            Expanded(child: _editField('First Name', firstCtrl)),
                            const SizedBox(width: 10),
                            Expanded(child: _editField('Last Name', lastCtrl)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Email
                        _editField('Email Address', emailCtrl),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            const Text('Email Verification',
                                style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (e['isEmailVerified'] ?? true) ? 'Verified' : 'Unverified',
                                style: TextStyle(
                                    color: (e['isEmailVerified'] ?? true) ? Colors.green : Colors.orange,
                                    fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Role dropdown
                        _editLabel('Role'),
                        _dropdownEdit<String>(
                          value: selectedRoleId.isEmpty ? null : selectedRoleId,
                          hint: e['role']?['name'] ?? e['roleName'] ?? 'Select Role',
                          items: _roles.map((r) => DropdownMenuItem(
                            value: r['id']?.toString() ?? '',
                            child: Text(r['name'] ?? '', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setLocal(() => selectedRoleId = v ?? ''),
                        ),
                        const SizedBox(height: 10),

                        // Department dropdown
                        _editLabel('Department'),
                        _dropdownEdit<String>(
                          value: selectedDeptId.isEmpty ? null : selectedDeptId,
                          hint: e['department']?['name'] ?? e['departmentName'] ?? 'Select Department',
                          items: _departments.map((d) => DropdownMenuItem(
                            value: d['id']?.toString() ?? '',
                            child: Text(d['name'] ?? '', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setLocal(() => selectedDeptId = v ?? ''),
                        ),
                        const SizedBox(height: 10),

                        // Contact Number
                        _editField('Contact Number', phoneCtrl, keyboard: TextInputType.phone),
                        const SizedBox(height: 10),

                        // Team Head toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Team Head',
                                        style: TextStyle(color: Colors.white, fontSize: 13)),
                                    Text('Can assign visits to any employee',
                                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isTeamHead,
                                activeColor: const Color(0xFF3B82F6),
                                onChanged: (v) => setLocal(() => isTeamHead = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Save + Cancel
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: savingMain ? null : () async {
                                  setLocal(() => savingMain = true);
                                  try {
                                    final body = <String, dynamic>{
                                      'firstName': firstCtrl.text.trim(),
                                      'lastName': lastCtrl.text.trim(),
                                      'contactNumber': phoneCtrl.text.trim(),
                                      'isTeamHead': isTeamHead,
                                    };
                                    if (selectedRoleId.isNotEmpty) body['roleId'] = selectedRoleId;
                                    if (selectedDeptId.isNotEmpty) body['departmentId'] = selectedDeptId;
                                    await ApiService().updateEmployee(id, body);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadData();
                                  } catch (err) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                        content: Text(err.toString().replaceFirst('Exception: ', '')),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  } finally {
                                    setLocal(() => savingMain = false);
                                  }
                                },
                                child: savingMain
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ACCOUNT ACTIONS
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ACCOUNT ACTIONS',
                                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 12),

                              // Reset password
                              GestureDetector(
                                onTap: () => setLocal(() => resetExpanded = !resetExpanded),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_reset_outlined, color: Colors.white54, size: 16),
                                      const SizedBox(width: 8),
                                      const Expanded(child: Text('Reset Password',
                                          style: TextStyle(color: Colors.white70, fontSize: 13))),
                                      Icon(resetExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.white38, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              if (resetExpanded) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: pwdCtrl,
                                  obscureText: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: _inputDeco('New password'),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: resetSaving ? null : () async {
                                      if (pwdCtrl.text.length < 6) return;
                                      setLocal(() => resetSaving = true);
                                      try {
                                        await ApiService().resetEmployeePassword(id, pwdCtrl.text);
                                        pwdCtrl.clear();
                                        setLocal(() { resetExpanded = false; resetSaving = false; });
                                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('Password reset'), backgroundColor: Colors.green));
                                      } catch (err) {
                                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(err.toString().replaceFirst('Exception: ', '')),
                                              backgroundColor: Colors.red));
                                        setLocal(() => resetSaving = false);
                                      }
                                    },
                                    child: resetSaving
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Set New Password', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),

                              // Deactivate
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Deactivate Account',
                                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                                        Text('Prevent this employee from logging in',
                                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  deactivating
                                      ? const SizedBox(width: 14, height: 14,
                                          child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2))
                                      : OutlinedButton.icon(
                                          onPressed: () async {
                                            setLocal(() => deactivating = true);
                                            try {
                                              await ApiService().deactivateEmployee(id);
                                              if (ctx.mounted) Navigator.pop(ctx);
                                              _loadData();
                                            } catch (_) {
                                              setLocal(() => deactivating = false);
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.orange),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.block, color: Colors.orange, size: 14),
                                          label: const Text('Deactivate',
                                              style: TextStyle(color: Colors.orange, fontSize: 12)),
                                        ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 8),

                              // Delete
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Delete Permanently',
                                            style: TextStyle(color: Colors.red, fontSize: 13)),
                                        Text('Irreversible — removes the account entirely',
                                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  deleting
                                      ? const SizedBox(width: 14, height: 14,
                                          child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                                      : ElevatedButton.icon(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            _confirmDelete(e);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.delete_forever, color: Colors.white, size: 14),
                                          label: const Text('Delete',
                                              style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: keyboard,
          decoration: _inputDeco(''),
        ),
      ],
    );
  }

  Widget _editLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
  );

  Widget _dropdownEdit<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          iconEnabledColor: Colors.white38,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF0F172A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );

  Future<void> _confirmDelete(Map<String, dynamic> e) async {
    final id = e['id']?.toString() ?? '';
    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Permanently', style: TextStyle(color: Colors.red)),
        content: Text('Remove $name permanently? This cannot be undone.',
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService().deleteEmployee(id);
      _loadData();
    }
  }

  // ── TRAVEL HISTORY DIALOG ────────────────────────────────────────────────────

  void _showTravelHistory(Map<String, dynamic> e) async {
    final id = e['id']?.toString() ?? '';
    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
    List<Map<String, dynamic>> trips = [];
    bool loading = true;
    Set<int> expanded = {};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (loading) {
            ApiService().getEmployeeTravelHistory(id).then((data) {
              setLocal(() { trips = data; loading = false; });
            });
          }

          double totalKm = trips.fold(0.0, (sum, t) {
            return sum + (double.tryParse((t['totalKm'] ?? t['distance'] ?? 0).toString()) ?? 0);
          });
          int gpsTracked = trips.where((t) => (t['gpsTracked'] ?? t['hasGps'] ?? false) == true).length;

          return Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('$name — Travel History',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.white38),
                        ),
                      ],
                    ),
                  ),

                  // Stats bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _travelStat('${trips.length}', 'Total Trips'),
                        _divider(),
                        _travelStat('$gpsTracked', 'GPS Tracked'),
                        _divider(),
                        _travelStat('${totalKm.toStringAsFixed(2)} km', 'Total Distance'),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // List
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                        : trips.isEmpty
                            ? const Center(child: Text('No travel history', style: TextStyle(color: Colors.white38)))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                itemCount: trips.length,
                                itemBuilder: (_, i) {
                                  final trip = trips[i];
                                  final isExpanded = expanded.contains(i);
                                  return _tripCard(trip, i, isExpanded, () {
                                    setLocal(() {
                                      if (isExpanded) expanded.remove(i);
                                      else expanded.add(i);
                                    });
                                  });
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tripCard(Map<String, dynamic> t, int idx, bool expanded, VoidCallback onToggle) {
    final from = t['from'] ?? t['fromLocation'] ?? 'Office';
    final to = t['to'] ?? t['toLocation'] ?? t['destination'] ?? '';
    final date = t['date'] ?? t['visitDate'] ?? t['createdAt'] ?? '';
    final km = double.tryParse((t['totalKm'] ?? t['distance'] ?? 0).toString()) ?? 0;
    final status = (t['status'] ?? 'approved').toString().toLowerCase();
    final completed = (t['completedAt'] ?? t['endTime'] ?? t['visitEndTime']) != null;
    final purpose = t['purpose'] ?? t['title'] ?? '';
    final time = t['startTime'] ?? t['visitStartTime'] ?? '';

    // GPS trail
    final startVisit = t['startVisitTime'] ?? t['visitStartTime'] ?? '';
    final meetingStart = t['meetingStartTime'] ?? '';
    final meetingEnd = t['meetingEndTime'] ?? '';
    final endVisit = t['endVisitTime'] ?? t['visitEndTime'] ?? t['completedAt'] ?? '';
    final meetingDuration = t['meetingDuration'] ?? '';
    final totalVisitTime = t['totalVisitTime'] ?? '';
    final travelToClient = t['travelToClientTime'] ?? '';
    final toClientDist = t['toClientKm'] ?? '';
    final returnTravel = t['returnTravelTime'] ?? '';

    final dateStr = _formatDate(date);
    final timeStr = _formatTime(time);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          // Trip row
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF3B82F6), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$from → $to',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.white38, size: 11),
                            const SizedBox(width: 3),
                            Text('$dateStr${timeStr.isNotEmpty ? ' · $timeStr' : ''}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            if (km > 0) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.swap_horiz, color: Colors.white38, size: 11),
                              const SizedBox(width: 3),
                              Text('${km.toStringAsFixed(2)} km actual',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ],
                        ),
                        if (purpose.isNotEmpty)
                          Text(purpose.toString(),
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (completed) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Completed',
                                  style: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white38, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // GPS trail (expanded)
          if (expanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GPS TRAIL',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  if (startVisit.isNotEmpty) _gpsStep('Start Visit', _formatTime(startVisit)),
                  if (meetingStart.isNotEmpty) _gpsStep('Meeting Start', _formatTime(meetingStart)),
                  if (meetingEnd.isNotEmpty) _gpsStep('Meeting End', _formatTime(meetingEnd)),
                  if (endVisit.isNotEmpty) _gpsStep('End Visit', _formatTime(endVisit)),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _gpsMetric('Total Distance', '${km.toStringAsFixed(2)} km')),
                      Expanded(child: _gpsMetric('Meeting Duration', meetingDuration.toString())),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _gpsMetric('Total Visit Time', totalVisitTime.toString())),
                      Expanded(child: _gpsMetric('Travel to Client', travelToClient.toString())),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _gpsMetric('To-client Distance', toClientDist.toString())),
                      Expanded(child: _gpsMetric('Return Travel', returnTravel.toString())),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gpsStep(String label, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          Text(time, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _gpsMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value.isNotEmpty ? value : '—',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _travelStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 32, color: Colors.white12,
  );

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${d[dt.weekday - 1]} ${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return iso.substring(0, 10); }
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$h:$min';
    } catch (_) { return iso; }
  }

  // ── DEPARTMENTS TAB ──────────────────────────────────────────────────────────

  Widget _buildDepartmentsTab() {
    if (_departments.isEmpty) {
      return const Center(child: Text('No departments found', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _departments.length,
      itemBuilder: (_, i) => _departmentCard(_departments[i]),
    );
  }

  Widget _departmentCard(Map<String, dynamic> d) {
    final name = d['name'] ?? '';
    final shift = d['shift'] as Map<String, dynamic>? ?? {};
    final startTime = shift['startTime'] ?? d['shiftStart'] ?? '10:00 AM';
    final endTime = shift['endTime'] ?? d['shiftEnd'] ?? '06:00 PM';
    final grace = shift['graceMinutes'] ?? d['gracePeriodMinutes'] ?? d['graceMinutes'] ?? 15;
    final selfie = d['selfieRequired'] ?? false;
    final overtime = d['overtimeEligible'] ?? false;
    final empCount = d['employeeCount'] ?? d['_count']?['users'] ?? 0;

    final deptEmployees = _employees.where((e) {
      final eDept = e['department']?['name']?.toString() ?? e['departmentName']?.toString() ?? '';
      return eDept == name.toString();
    }).toList();

    return GestureDetector(
      onTap: () => _showDeptEmployees(name.toString(), deptEmployees),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                child: Text(name.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              if (empCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$empCount emp',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _timeChip(Icons.login, startTime.toString(), Colors.green),
              const SizedBox(width: 8),
              _timeChip(Icons.logout, endTime.toString(), Colors.red),
              const SizedBox(width: 8),
              _timeChip(Icons.timer_outlined, '$grace min', Colors.orange),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _toggleInfo(Icons.camera_alt_outlined, 'Selfie', selfie),
              const SizedBox(width: 16),
              _toggleInfo(Icons.access_time, 'Overtime', overtime),
            ],
          ),
        ],
      ),
    ), // GestureDetector
    );
  }

  void _showDeptEmployees(String deptName, List<Map<String, dynamic>> emps) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Text('$deptName (${emps.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: emps.isEmpty
                  ? const Center(child: Text('No employees', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: emps.length,
                      itemBuilder: (_, i) {
                        final e = emps[i];
                        final firstName = (e['firstName'] ?? '').toString();
                        final lastName = (e['lastName'] ?? '').toString();
                        final name = '$firstName $lastName'.trim();
                        final empId = e['employeeId'] ?? e['empId'] ?? '';
                        final email = e['email'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.isEmpty ? email : name,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                    if (email.isNotEmpty)
                                      Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (empId.toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(empId.toString(),
                                      style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _toggleInfo(IconData icon, String label, bool enabled) {
    return Row(
      children: [
        Icon(icon, color: enabled ? const Color(0xFF3B82F6) : Colors.white24, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: enabled ? Colors.white70 : Colors.white24, fontSize: 12)),
        const SizedBox(width: 4),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: enabled ? Colors.green : Colors.white24,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  // ── ROLES TAB ────────────────────────────────────────────────────────────────

  Widget _buildRolesTab() {
    if (_roles.isEmpty) {
      return const Center(child: Text('No roles found', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _roles.length,
      itemBuilder: (_, i) => _roleCard(_roles[i]),
    );
  }

  Widget _roleCard(Map<String, dynamic> r) {
    final name = r['name'] ?? '';
    final description = r['description'] ?? '';
    final isSystem = r['isSystem'] ?? false;
    final permissions = r['permissions'];
    List<String> perms = [];
    if (permissions is List) {
      perms = permissions.map((p) => p.toString()).toList();
    } else if (permissions is String) {
      perms = [permissions];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (isSystem)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('System',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (description.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description.toString(), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (perms.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: perms
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                        ),
                        child: Text(p, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
