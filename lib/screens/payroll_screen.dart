// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Map<String, dynamic>> _payrolls = [];
  bool _loading = true;
  String? _error;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiService().getPayroll(month: _month, year: _year);
      if (mounted) setState(() {
        final list = raw['records'] ?? raw['data'] ?? raw['payrolls'] ?? [];
        _payrolls = list is List ? list.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openPayslip(String id) {
    final url = '${ApiConfig.baseUrl}/payroll/$id/pdf';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Payroll',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary)),
        ],
      ),
      body: Column(children: [
        _monthBar(),
        _summaryRow(),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _monthBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      IconButton(
        onPressed: () { setState(() { if (_month == 1) { _month = 12; _year--; } else _month--; }); _load(); },
        icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text('${_months[_month - 1]} $_year',
              style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () { setState(() { if (_month == 12) { _month = 1; _year++; } else _month++; }); _load(); },
        icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
      ),
      const Spacer(),
      TextButton.icon(
        onPressed: () => html.window.open('${ApiConfig.baseUrl}/payroll/export?month=$_month&year=$_year&format=excel', '_blank'),
        icon: const Icon(Icons.download_outlined, size: 16, color: AppTheme.secondary),
        label: Text('Export', style: AppTheme.label(12, color: AppTheme.secondary)),
      ),
    ]),
  );

  Widget _summaryRow() {
    if (_payrolls.isEmpty) return const SizedBox.shrink();
    double total = 0, paid = 0, pending = 0;
    for (final p in _payrolls) {
      final net = double.tryParse((p['netSalary'] ?? p['net'] ?? 0).toString()) ?? 0;
      total += net;
      if ((p['status'] ?? '').toString().toLowerCase() == 'paid') paid += net; else pending += net;
    }
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(children: [
        _sumChip('Total', total, AppTheme.primary),
        const SizedBox(width: 10),
        _sumChip('Paid', paid, AppTheme.secondary),
        const SizedBox(width: 10),
        _sumChip('Pending', pending, AppTheme.warning),
      ]),
    );
  }

  Widget _sumChip(String label, double value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTheme.label(10, color: color)),
        Text(_fmt(value), style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_payrolls.isEmpty) return _emptyWidget('No payroll records for this month');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payrolls.length,
        itemBuilder: (_, i) => _card(_payrolls[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final name = '${p['user']?['firstName'] ?? p['firstName'] ?? ''} ${p['user']?['lastName'] ?? p['lastName'] ?? ''}'.trim();
    final empId = p['user']?['employeeId'] ?? p['empId'] ?? p['employeeId'] ?? '';
    final dept = p['user']?['department']?['name'] ?? p['department'] ?? '';
    final net = double.tryParse((p['netSalary'] ?? p['net'] ?? 0).toString()) ?? 0;
    final basic = double.tryParse((p['basicSalary'] ?? p['baseSalary'] ?? 0).toString()) ?? 0;
    final deductions = double.tryParse((p['totalDeductions'] ?? p['deductions'] ?? 0).toString()) ?? 0;
    final status = (p['status'] ?? 'pending').toString();
    final id = p['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _showDetail(p, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
        ),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTheme.label(14, color: AppTheme.primary, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Employee' : name, style: AppTheme.body(13)),
              if (dept.toString().isNotEmpty) Text(dept.toString(), style: AppTheme.label(11)),
              if (empId.toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(empId.toString(), style: AppTheme.label(9, color: AppTheme.primary, weight: FontWeight.w600)),
                ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(net), style: GoogleFonts.poppins(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              StatusBadge(status: status, fontSize: 10),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _amtChip('Basic', basic, Colors.white54),
            const SizedBox(width: 8),
            _amtChip('Deductions', deductions, AppTheme.error),
            const SizedBox(width: 8),
            _amtChip('Net', net, AppTheme.secondary),
            const Spacer(),
            if (id.isNotEmpty)
              GestureDetector(
                onTap: () => _openPayslip(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('Payslip', style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _amtChip(String label, double value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.label(9, color: AppTheme.textSecondary)),
      Text(_fmt(value), style: AppTheme.label(11, color: color, weight: FontWeight.w600)),
    ],
  );

  void _showDetail(Map<String, dynamic> p, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, ctrl) {
          final items = [
            ('Basic Salary', p['basicSalary'] ?? p['baseSalary'] ?? 0, AppTheme.textPrimary),
            ('Housing Allow.', p['housingAllowance'] ?? p['houseAllowance'] ?? 0, AppTheme.textPrimary),
            ('Transport Allow.', p['transportAllowance'] ?? 0, AppTheme.textPrimary),
            ('Medical Allow.', p['medicalAllowance'] ?? 0, AppTheme.textPrimary),
            ('Total Allowances', p['totalAllowances'] ?? p['allowances'] ?? 0, AppTheme.secondary),
            ('Tax', p['incomeTax'] ?? p['tax'] ?? 0, AppTheme.error),
            ('Insurance', p['insurance'] ?? 0, AppTheme.error),
            ('Total Deductions', p['totalDeductions'] ?? p['deductions'] ?? 0, AppTheme.error),
            ('Net Salary', p['netSalary'] ?? p['net'] ?? 0, AppTheme.secondary),
          ];
          return ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Expanded(child: Text(name.isEmpty ? 'Employee' : name, style: AppTheme.heading(16))),
              StatusBadge(status: (p['status'] ?? 'pending').toString()),
            ]),
            const SizedBox(height: 4),
            Text('${_months[_month - 1]} $_year', style: AppTheme.label(12)),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.divider),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(item.$1, style: AppTheme.label(13))),
                Text(_fmt(double.tryParse(item.$2.toString()) ?? 0),
                    style: AppTheme.label(13, color: item.$3, weight: FontWeight.w600)),
              ]),
            )),
          ]);
        },
      ),
    );
  }

  String _fmt(double v) {
    if (v == 0) return 'PKR 0';
    return 'PKR ${NumberFormat('#,##0').format(v)}';
  }
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
