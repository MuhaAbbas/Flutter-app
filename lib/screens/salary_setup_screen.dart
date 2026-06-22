import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../services/api_service.dart';

class SalarySetupScreen extends StatefulWidget {
  const SalarySetupScreen({super.key});
  @override
  State<SalarySetupScreen> createState() => _SalarySetupScreenState();
}

class _SalarySetupScreenState extends State<SalarySetupScreen> {
  List<Map<String, dynamic>> _setups = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() { setState(() => _search = _searchCtrl.text); });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getSalarySetupsWithError(search: _search.isNotEmpty ? _search : null);
      if (mounted) setState(() { _setups = data; _loading = false; });
    } catch (e) {
      final msg = e.toString();
      if (mounted) setState(() {
        _error = msg.replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Salary Setup',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            style: AppTheme.body(13),
            onChanged: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search employees...',
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
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 40),
        const SizedBox(height: 12),
        Text(_error!.replaceFirst('Exception: ', ''), style: AppTheme.body(13, color: AppTheme.error), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: _load, child: Text('Retry', style: AppTheme.label(13, color: AppTheme.primary))),
      ]),
    ));
    if (_setups.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text('No salary setups found', style: AppTheme.label(14)),
    ]));
    return Column(children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _setups.asMap().entries.map((e) => _setupRow(e.value, e.key.isOdd)).toList(),
            ),
          ),
        ),
      )),
    ]);
  }

  Widget _tableHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      _th(230, 'Employee'),
      _th(90, 'Emp. ID'),
      _th(150, 'Department'),
      _th(130, 'Base Salary'),
      _th(130, 'Allowances'),
      _th(120, 'Deductions'),
      _th(130, 'Net Salary'),
      _th(90, 'Status', center: true),
      _th(120, 'Action', center: true),
    ]),
  );

  Widget _setupRow(Map<String, dynamic> s, bool alt) {
    String name = '${s['user']?['firstName'] ?? s['firstName'] ?? ''} ${s['user']?['lastName'] ?? s['lastName'] ?? ''}'.trim();
    if (name.isEmpty) name = 'Employee';
    final email = (s['user']?['email'] ?? s['email'] ?? '').toString();
    final empId = (s['user']?['employeeId'] ?? s['empId'] ?? s['employeeId'] ?? '').toString();
    final dept = (s['user']?['department']?['name'] ?? s['department'] ?? '').toString();
    final basic = double.tryParse((s['basicSalary'] ?? s['baseSalary'] ?? 0).toString()) ?? 0;
    final net = double.tryParse((s['netSalary'] ?? s['net'] ?? 0).toString()) ?? 0;
    final deductions = double.tryParse((s['totalDeductions'] ?? s['deductions'] ?? 0).toString()) ?? 0;
    final allowances = double.tryParse((s['totalAllowances'] ?? s['allowances'] ?? 0).toString()) ?? 0;
    final configured = s['isConfigured'] == true || s['configured'] == true || basic > 0;
    final id = (s['id'] ?? s['_id'] ?? '').toString();
    final userId = (s['userId'] ?? s['user']?['id'] ?? s['user']?['_id'] ?? '').toString();
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: const Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 230, child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(12, color: ac, weight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.body(12), overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty) Text(email, style: AppTheme.label(10), overflow: TextOverflow.ellipsis),
          ])),
        ])),
        SizedBox(width: 90, child: Text(empId.isNotEmpty ? empId : '—', style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w600))),
        SizedBox(width: 150, child: Text(dept.isNotEmpty ? dept : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 130, child: Text(_fmt(basic), style: AppTheme.body(12))),
        SizedBox(width: 130, child: Text('+${_fmt(allowances)}', style: AppTheme.label(12, color: const Color(0xFF4ADE80), weight: FontWeight.w600))),
        SizedBox(width: 120, child: Text('-${_fmt(deductions)}', style: AppTheme.label(12, color: AppTheme.error, weight: FontWeight.w600))),
        SizedBox(width: 130, child: Text(_fmt(net), style: AppTheme.label(12, color: AppTheme.textPrimary, weight: FontWeight.w700))),
        SizedBox(width: 90, child: Center(child: StatusBadge(status: configured ? 'active' : 'pending', fontSize: 10))),
        SizedBox(width: 120, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalarySetupEditScreen(setup: s, userId: userId))).then((_) => _load()),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text('Edit', style: AppTheme.label(11, color: AppTheme.primary)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              final ok = await _confirmDelete(name);
              if (ok == true) { await ApiService().deleteSalarySetup(id); _load(); }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.delete_outline, size: 13, color: AppTheme.error),
                const SizedBox(width: 4),
                Text('Del', style: AppTheme.label(11, color: AppTheme.error)),
              ]),
            ),
          ),
        ]))),
      ]),
    );
  }

  Widget _th(double w, String label, {bool center = false}) => SizedBox(
    width: w,
    child: Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(label.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    ),
  );

  Future<bool?> _confirmDelete(String name) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surfaceElevated,
      title: Text('Delete Setup', style: AppTheme.heading(16)),
      content: Text('Remove salary setup for $name?', style: AppTheme.label(13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.label(13))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: AppTheme.label(13, color: Colors.white)),
        ),
      ],
    ),
  );

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

// ── Edit Screen ───────────────────────────────────────────────────────────────

class SalarySetupEditScreen extends StatefulWidget {
  final Map<String, dynamic> setup;
  final String userId;
  const SalarySetupEditScreen({super.key, required this.setup, required this.userId});
  @override
  State<SalarySetupEditScreen> createState() => _SalarySetupEditScreenState();
}

class _SalarySetupEditScreenState extends State<SalarySetupEditScreen> {
  bool _saving = false;

  late final TextEditingController _basicCtrl;
  late final TextEditingController _housingCtrl;
  late final TextEditingController _transportCtrl;
  late final TextEditingController _medicalCtrl;
  late final TextEditingController _mealCtrl;
  late final TextEditingController _overtimeCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _commissionCtrl;
  late final TextEditingController _miscCtrl;
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
    _housingCtrl = TextEditingController(text: _v(s['housingAllowance']));
    _transportCtrl = TextEditingController(text: _v(s['transportAllowance']));
    _medicalCtrl = TextEditingController(text: _v(s['medicalAllowance']));
    _mealCtrl = TextEditingController(text: _v(s['mealAllowance']));
    _overtimeCtrl = TextEditingController(text: _v(s['overtime']));
    _mobileCtrl = TextEditingController(text: _v(s['mobileAllowance']));
    _commissionCtrl = TextEditingController(text: _v(s['commission']));
    _miscCtrl = TextEditingController(text: _v(s['miscAllowance']));
    _taxPctCtrl = TextEditingController(text: _v(s['incomeTaxPercent'] ?? s['taxPercent']));
    _insuranceCtrl = TextEditingController(text: _v(s['insurance']));
    _advanceCtrl = TextEditingController(text: _v(s['advance']));
    _fineCtrl = TextEditingController(text: _v(s['fine']));
    final ef = s['effectiveFrom'];
    if (ef != null) { try { _effectiveFrom = DateTime.parse(ef.toString()); } catch (_) {} }
    for (final c in _allCtrls) c.addListener(() => setState(() {}));
  }

  List<TextEditingController> get _allCtrls => [_basicCtrl, _housingCtrl, _transportCtrl, _medicalCtrl,
    _mealCtrl, _overtimeCtrl, _mobileCtrl, _commissionCtrl, _miscCtrl, _taxPctCtrl, _insuranceCtrl, _advanceCtrl, _fineCtrl];

  @override
  void dispose() { for (final c in _allCtrls) c.dispose(); super.dispose(); }

  String _v(dynamic val) {
    if (val == null) return '0';
    final d = double.tryParse(val.toString()) ?? 0;
    return d == 0 ? '0' : d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get _gross => _d(_basicCtrl) + _totalAllow;
  double get _totalAllow => _d(_housingCtrl) + _d(_transportCtrl) + _d(_medicalCtrl) +
      _d(_mealCtrl) + _d(_overtimeCtrl) + _d(_mobileCtrl) + _d(_commissionCtrl) + _d(_miscCtrl);
  double get _taxAmt => _gross * (_d(_taxPctCtrl) / 100);
  double get _totalDed => _taxAmt + _d(_insuranceCtrl) + _d(_advanceCtrl) + _d(_fineCtrl);
  double get _net => _gross - _totalDed;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService().saveSalarySetup(widget.userId, {
        'basicSalary': _d(_basicCtrl), 'housingAllowance': _d(_housingCtrl),
        'transportAllowance': _d(_transportCtrl), 'medicalAllowance': _d(_medicalCtrl),
        'mealAllowance': _d(_mealCtrl), 'overtime': _d(_overtimeCtrl),
        'mobileAllowance': _d(_mobileCtrl), 'commission': _d(_commissionCtrl),
        'miscAllowance': _d(_miscCtrl), 'incomeTaxPercent': _d(_taxPctCtrl),
        'insurance': _d(_insuranceCtrl), 'advance': _d(_advanceCtrl), 'fine': _d(_fineCtrl),
        'currency': 'PKR', 'effectiveFrom': _effectiveFrom.toIso8601String().substring(0, 10),
      });
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully'), backgroundColor: AppTheme.secondary)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.setup['user']?['firstName'] ?? widget.setup['firstName'] ?? ''} ${widget.setup['user']?['lastName'] ?? widget.setup['lastName'] ?? ''}'.trim();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(title: 'Salary Setup — $name', showBack: true),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('Earnings'),
            _grid2([
              _field('Basic Salary', _basicCtrl),
              _field('Housing Allowance', _housingCtrl),
              _field('Transport Allowance', _transportCtrl),
              _field('Medical Allowance', _medicalCtrl),
              _field('Meal / Lunch', _mealCtrl),
              _field('Overtime', _overtimeCtrl),
              _field('Mobile Allowance', _mobileCtrl),
              _field('Commission', _commissionCtrl),
            ]),
            _field('Misc Allowance', _miscCtrl),
            const SizedBox(height: 20),
            _section('Deductions'),
            _grid2([
              _field('Income Tax %', _taxPctCtrl, prefix: '%'),
              _field('Insurance', _insuranceCtrl),
              _field('Advance', _advanceCtrl),
              _field('Fine', _fineCtrl),
            ]),
            const SizedBox(height: 20),
            _section('Other'),
            _datePicker(),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Salary Structure', style: AppTheme.label(14, color: Colors.white, weight: FontWeight.w600)),
            )),
            const SizedBox(height: 20),
          ]),
        )),
        Expanded(flex: 2, child: Container(
          margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Breakdown', style: AppTheme.heading(14)),
            const SizedBox(height: 14),
            _bRow('Gross Salary', _gross, AppTheme.textPrimary),
            const Divider(color: AppTheme.divider),
            _bRow('Total Allowances', _totalAllow, AppTheme.secondary, small: true),
            const Divider(color: AppTheme.divider),
            _bRow('Tax (${_taxPctCtrl.text}%)', _taxAmt, AppTheme.error, small: true),
            _bRow('Other Deductions', _totalDed - _taxAmt, AppTheme.error, small: true),
            _bRow('Total Deductions', _totalDed, AppTheme.error),
            const Divider(color: AppTheme.divider),
            _bRow('Net Salary', _net, AppTheme.secondary, bold: true),
          ]),
        )),
      ]),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: AppTheme.heading(14)),
  );

  Widget _grid2(List<Widget> children) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: children[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
      ]));
      rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _field(String label, TextEditingController ctrl, {String prefix = 'PKR'}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.label(11)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: AppTheme.body(13),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixText: '$prefix  ',
          prefixStyle: AppTheme.label(12),
          filled: true, fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        ),
      ),
    ],
  );

  Widget _datePicker() => GestureDetector(
    onTap: () async {
      final p = await showDatePicker(
        context: context, initialDate: _effectiveFrom,
        firstDate: DateTime(2020), lastDate: DateTime(2030),
        builder: (_, c) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
          child: c!,
        ),
      );
      if (p != null) setState(() => _effectiveFrom = p);
    },
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Effective From', style: AppTheme.label(11)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.background, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text('${_effectiveFrom.month.toString().padLeft(2, '0')}/${_effectiveFrom.day.toString().padLeft(2, '0')}/${_effectiveFrom.year}',
              style: AppTheme.body(13)),
        ]),
      ),
    ]),
  );

  Widget _bRow(String label, double value, Color color, {bool bold = false, bool small = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: AppTheme.label(small ? 11 : 12))),
      Text('PKR ${value.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(color: color, fontSize: small ? 11 : 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
    ]),
  );
}
