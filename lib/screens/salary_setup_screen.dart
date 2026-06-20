import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SalarySetupScreen extends StatefulWidget {
  const SalarySetupScreen({super.key});
  @override
  State<SalarySetupScreen> createState() => _SalarySetupScreenState();
}

class _SalarySetupScreenState extends State<SalarySetupScreen> {
  List<Map<String, dynamic>> _setups = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService().getSalarySetups(search: _search.isNotEmpty ? _search : null);
    if (mounted) setState(() { _setups = data; _loading = false; });
  }

  Future<void> _delete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Setup', style: TextStyle(color: Colors.white)),
        content: Text('Remove salary setup for $name?',
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
      await ApiService().deleteSalarySetup(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Salary Setup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) {
                setState(() => _search = v);
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Search employees...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _setups.isEmpty
                    ? const Center(
                        child: Text('No salary setups found',
                            style: TextStyle(color: Colors.white38)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: _setups.length,
                          itemBuilder: (_, i) => _setupCard(_setups[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _setupCard(Map<String, dynamic> s) {
    final firstName = s['user']?['firstName'] ?? s['firstName'] ?? '';
    final lastName = s['user']?['lastName'] ?? s['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();
    final email = s['user']?['email'] ?? s['email'] ?? '';
    final empId = s['user']?['employeeId'] ?? s['empId'] ?? s['employeeId'] ?? '';
    final dept = s['user']?['department']?['name'] ?? s['department'] ?? s['departmentName'] ?? '';
    final baseSalary = double.tryParse((s['basicSalary'] ?? s['baseSalary'] ?? 0).toString()) ?? 0;
    final allowances = double.tryParse((s['totalAllowances'] ?? s['allowances'] ?? 0).toString()) ?? 0;
    final deductions = double.tryParse((s['totalDeductions'] ?? s['deductions'] ?? 0).toString()) ?? 0;
    final netSalary = double.tryParse((s['netSalary'] ?? s['net'] ?? 0).toString()) ?? 0;
    final configured = s['isConfigured'] ?? s['configured'] ?? baseSalary > 0;
    final id = s['id']?.toString() ?? '';
    final userId = s['userId']?.toString() ?? s['user']?['id']?.toString() ?? '';

    final colors = [
      const Color(0xFF3B82F6), Colors.purple, Colors.teal, Colors.orange, Colors.pink,
    ];
    final colorIdx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    final avatarColor = colors[colorIdx];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarColor.withValues(alpha: 0.2),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    if (email.isNotEmpty)
                      Text(email,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
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
          const SizedBox(height: 8),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              if (dept.isNotEmpty)
                Expanded(
                  child: Text(dept.toString(),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: configured
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(configured ? 'Configured' : 'Not Set',
                    style: TextStyle(
                        color: configured ? Colors.green : Colors.white38,
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _salaryChip('Base', baseSalary, Colors.white),
              const SizedBox(width: 6),
              _salaryChip('+Allow', allowances, Colors.green),
              const SizedBox(width: 6),
              _salaryChip('-Deduct', deductions, Colors.red),
              const SizedBox(width: 6),
              _salaryChip('Net', netSalary, const Color(0xFF3B82F6)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 18),
                onPressed: () => _openEdit(s, userId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                onPressed: () => _delete(id, name),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salaryChip(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9)),
        Text('${_fmt(value)}',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _openEdit(Map<String, dynamic> setup, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalarySetupEditScreen(setup: setup, userId: userId),
      ),
    ).then((_) => _load());
  }

  String _fmt(double v) {
    if (v == 0) return 'PKR 0';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer('PKR ');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Salary Setup Edit Screen ─────────────────────────────────────────────────

class SalarySetupEditScreen extends StatefulWidget {
  final Map<String, dynamic> setup;
  final String userId;

  const SalarySetupEditScreen({super.key, required this.setup, required this.userId});

  @override
  State<SalarySetupEditScreen> createState() => _SalarySetupEditScreenState();
}

class _SalarySetupEditScreenState extends State<SalarySetupEditScreen> {
  bool _saving = false;
  bool _deleting = false;

  // Earnings controllers
  late final TextEditingController _basicCtrl;
  late final TextEditingController _housingCtrl;
  late final TextEditingController _transportCtrl;
  late final TextEditingController _medicalCtrl;
  late final TextEditingController _mealCtrl;
  late final TextEditingController _overtimeCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _commissionCtrl;
  late final TextEditingController _miscCtrl;

  // Deductions controllers
  late final TextEditingController _taxPctCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _advanceCtrl;
  late final TextEditingController _fineCtrl;

  DateTime _effectiveFrom = DateTime.now();

  @override
  void initState() {
    super.initState();
    final s = widget.setup;
    _basicCtrl = TextEditingController(text: _v(s['basicSalary'] ?? s['baseSalary']));
    _housingCtrl = TextEditingController(text: _v(s['housingAllowance'] ?? s['houseAllowance']));
    _transportCtrl = TextEditingController(text: _v(s['transportAllowance'] ?? s['transport']));
    _medicalCtrl = TextEditingController(text: _v(s['medicalAllowance'] ?? s['medical']));
    _mealCtrl = TextEditingController(text: _v(s['mealAllowance'] ?? s['meal']));
    _overtimeCtrl = TextEditingController(text: _v(s['overtime']));
    _mobileCtrl = TextEditingController(text: _v(s['mobileAllowance'] ?? s['mobile']));
    _commissionCtrl = TextEditingController(text: _v(s['commission']));
    _miscCtrl = TextEditingController(text: _v(s['miscAllowance'] ?? s['misc']));
    _taxPctCtrl = TextEditingController(text: _v(s['incomeTaxPercent'] ?? s['taxPercent'] ?? s['tax']));
    _insuranceCtrl = TextEditingController(text: _v(s['insurance']));
    _advanceCtrl = TextEditingController(text: _v(s['advance']));
    _fineCtrl = TextEditingController(text: _v(s['fine']));

    final ef = s['effectiveFrom'];
    if (ef != null) {
      try { _effectiveFrom = DateTime.parse(ef.toString()); } catch (_) {}
    }

    for (final c in _allControllers) {
      c.addListener(() => setState(() {}));
    }
  }

  List<TextEditingController> get _allControllers => [
    _basicCtrl, _housingCtrl, _transportCtrl, _medicalCtrl, _mealCtrl,
    _overtimeCtrl, _mobileCtrl, _commissionCtrl, _miscCtrl,
    _taxPctCtrl, _insuranceCtrl, _advanceCtrl, _fineCtrl,
  ];

  @override
  void dispose() {
    for (final c in _allControllers) c.dispose();
    super.dispose();
  }

  String _v(dynamic val) {
    if (val == null) return '0';
    final d = double.tryParse(val.toString()) ?? 0;
    return d == 0 ? '0' : d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;

  double get _grossSalary => _d(_basicCtrl) + _totalAllowances;
  double get _totalAllowances =>
      _d(_housingCtrl) + _d(_transportCtrl) + _d(_medicalCtrl) +
      _d(_mealCtrl) + _d(_overtimeCtrl) + _d(_mobileCtrl) +
      _d(_commissionCtrl) + _d(_miscCtrl);
  double get _taxAmount => _grossSalary * (_d(_taxPctCtrl) / 100);
  double get _totalDeductions => _taxAmount + _d(_insuranceCtrl) + _d(_advanceCtrl) + _d(_fineCtrl);
  double get _netSalary => _grossSalary - _totalDeductions;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService().saveSalarySetup(widget.userId, {
        'basicSalary': _d(_basicCtrl),
        'housingAllowance': _d(_housingCtrl),
        'transportAllowance': _d(_transportCtrl),
        'medicalAllowance': _d(_medicalCtrl),
        'mealAllowance': _d(_mealCtrl),
        'overtime': _d(_overtimeCtrl),
        'mobileAllowance': _d(_mobileCtrl),
        'commission': _d(_commissionCtrl),
        'miscAllowance': _d(_miscCtrl),
        'incomeTaxPercent': _d(_taxPctCtrl),
        'insurance': _d(_insuranceCtrl),
        'advance': _d(_advanceCtrl),
        'fine': _d(_fineCtrl),
        'currency': 'PKR',
        'effectiveFrom': _effectiveFrom.toIso8601String().substring(0, 10),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary structure saved'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Setup', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove the salary structure permanently.',
            style: TextStyle(color: Colors.white54)),
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
      setState(() => _deleting = true);
      final id = widget.setup['id']?.toString() ?? '';
      await ApiService().deleteSalarySetup(id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.setup['user']?['firstName'] ??
        widget.setup['firstName'] ?? '';
    final lastName = widget.setup['user']?['lastName'] ??
        widget.setup['lastName'] ?? '';
    final name = '$firstName $lastName'.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Salary Setup',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(name,
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          if (_deleting)
            const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)))
          else
            TextButton(
              onPressed: _delete,
              child: const Text('Delete Setup', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Earnings'),
                  _grid2([
                    _earnField('Base Salary', _basicCtrl),
                    _earnField('Housing Allowance', _housingCtrl),
                    _earnField('Transport Allowance', _transportCtrl),
                    _earnField('Medical Allowance', _medicalCtrl),
                    _earnField('Meal / Lunch Allowance', _mealCtrl),
                    _earnField('Overtime', _overtimeCtrl),
                    _earnField('Mobile Allowance', _mobileCtrl),
                    _earnField('Commission', _commissionCtrl),
                  ]),
                  _fullField('Misc Allowance', _miscCtrl),
                  const SizedBox(height: 16),
                  _sectionTitle('Deductions'),
                  _grid2([
                    _earnField('Income Tax %', _taxPctCtrl, prefix: '%'),
                    _earnField('Insurance', _insuranceCtrl),
                    _earnField('Advance', _advanceCtrl),
                    _earnField('Fine', _fineCtrl),
                  ]),
                  const SizedBox(height: 16),
                  _sectionTitle('Other'),
                  _infoField('Currency', 'PKR - Pakistani Rupee'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _effectiveFrom,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: Color(0xFF3B82F6))),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _effectiveFrom = picked);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Effective From',
                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                '${_effectiveFrom.month.toString().padLeft(2, '0')}/'
                                '${_effectiveFrom.day.toString().padLeft(2, '0')}/'
                                '${_effectiveFrom.year}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Salary Structure',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Breakdown
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 14, 14, 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Salary Breakdown',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  _bRow('Gross Salary', _grossSalary, Colors.white),
                  const Divider(color: Colors.white12, height: 16),
                  _bRow('Housing', _d(_housingCtrl), Colors.white54, small: true),
                  _bRow('Transport', _d(_transportCtrl), Colors.white54, small: true),
                  _bRow('Medical', _d(_medicalCtrl), Colors.white54, small: true),
                  _bRow('Lunch', _d(_mealCtrl), Colors.white54, small: true),
                  _bRow('Overtime', _d(_overtimeCtrl), Colors.white54, small: true),
                  _bRow('Mobile', _d(_mobileCtrl), Colors.white54, small: true),
                  _bRow('Commission', _d(_commissionCtrl), Colors.white54, small: true),
                  _bRow('Misc', _d(_miscCtrl), Colors.white54, small: true),
                  _bRow('Total Allowances', _totalAllowances, Colors.white),
                  const Divider(color: Colors.white12, height: 16),
                  _bRow('Tax (${_taxPctCtrl.text}%)', _taxAmount, Colors.red, small: true),
                  _bRow('Insurance', _d(_insuranceCtrl), Colors.red, small: true),
                  _bRow('Advance', _d(_advanceCtrl), Colors.red, small: true),
                  _bRow('Fine', _d(_fineCtrl), Colors.red, small: true),
                  const Divider(color: Colors.white12, height: 16),
                  _bRow('Net Salary', _netSalary, Colors.green, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13,
            decoration: TextDecoration.underline, decorationColor: Colors.white24)),
  );

  Widget _grid2(List<Widget> children) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: children[i]),
          const SizedBox(width: 10),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
        ],
      ));
      rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _earnField(String label, TextEditingController ctrl, {String prefix = 'PKR'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '$prefix  ',
            prefixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
          ),
        ),
      ],
    );
  }

  Widget _fullField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: 'PKR  ',
            prefixStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _bRow(String label, double value, Color color, {bool bold = false, bool small = false}) {
    final formatted = value == 0
        ? 'PKR 0.00'
        : 'PKR ${value.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: small ? Colors.white38 : Colors.white54,
                  fontSize: small ? 10 : 11)),
          Text(formatted,
              style: TextStyle(
                  color: color,
                  fontSize: small ? 10 : 11,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
