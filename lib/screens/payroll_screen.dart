import 'package:flutter/material.dart';
import '../services/api_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  bool _runningPayroll = false;

  String _selectedUserId = 'all';
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String _statusFilter = 'all';

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  static const _monthsShort = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final emp = await ApiService().getEmployees();
    if (mounted) setState(() => _employees = emp);
    await _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    setState(() => _loading = true);
    final data = await ApiService().getPayroll(
      userId: _selectedUserId,
      month: _month,
      year: _year,
      status: _statusFilter,
    );
    if (!mounted) return;
    final List rawRecords = data['records'] as List? ??
        data['payrolls'] as List? ??
        data['items'] as List? ?? [];
    final stats = data['stats'] as Map<String, dynamic>? ?? data;
    setState(() {
      _records = rawRecords.cast<Map<String, dynamic>>();
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _runPayroll() async {
    setState(() => _runningPayroll = true);
    try {
      await ApiService().runPayroll(
        month: _month,
        year: _year,
        userId: _selectedUserId == 'all' ? null : _selectedUserId,
      );
      _snack('Payroll generated successfully', Colors.green);
      await _loadPayroll();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _runningPayroll = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_statusFilter == 'all') return _records;
    return _records.where((r) {
      final s = (r['status'] ?? '').toString().toLowerCase();
      return s.contains(_statusFilter);
    }).toList();
  }

  // ── Stats helpers ────────────────────────────────────────────────────────────

  int get _approvedCount => _records.where((r) {
    final s = (r['status'] ?? '').toString().toLowerCase();
    return s.contains('approved') && !s.contains('pending');
  }).length;

  int get _pendingCount => _records.where((r) {
    final s = (r['status'] ?? '').toString().toLowerCase();
    return s.contains('pending');
  }).length;

  int get _rejectedCount => _records.where((r) {
    final s = (r['status'] ?? '').toString().toLowerCase();
    return s.contains('reject');
  }).length;

  double get _totalGross => _records.fold(0.0, (sum, r) {
    final v = r['grossSalary'] ?? r['gross'] ?? 0;
    return sum + (double.tryParse(v.toString()) ?? 0);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Payroll Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(onPressed: _loadPayroll, icon: const Icon(Icons.refresh, color: Colors.white70)),
        ],
      ),
      body: Column(
        children: [
          _buildTopFilter(),
          _buildStatCards(),
          _buildStatusTabs(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPayroll,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _payrollCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilter() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedUserId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  iconEnabledColor: Colors.white38,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Employees')),
                    ..._employees.map((e) {
                      final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                      return DropdownMenuItem(
                        value: e['id']?.toString() ?? '',
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (v) { if (v != null) { setState(() => _selectedUserId = v); _loadPayroll(); } },
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Month
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _month,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  iconEnabledColor: Colors.white38,
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_months[i]),
                  )),
                  onChanged: (v) { if (v != null) { setState(() => _month = v); _loadPayroll(); } },
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Year
          SizedBox(
            width: 72,
            child: TextField(
              controller: TextEditingController(text: _year.toString()),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white12)),
              ),
              onSubmitted: (v) {
                final y = int.tryParse(v);
                if (y != null && y > 2000) { setState(() => _year = y); _loadPayroll(); }
              },
            ),
          ),
          const SizedBox(width: 6),
          // Run Payroll
          ElevatedButton(
            onPressed: _runningPayroll ? null : _runPayroll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _runningPayroll
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Run Payroll',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final gross = _stats['totalGross'] ?? _totalGross;
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          _statCard('Total Gross', 'PKR ${_formatAmount(double.tryParse(gross.toString()) ?? 0)}',
              Colors.white, isLarge: true),
          const SizedBox(width: 6),
          _statCard('Approved', '${_stats['approved'] ?? _approvedCount}', Colors.green),
          const SizedBox(width: 6),
          _statCard('Pending', '${_stats['pending'] ?? _pendingCount}', Colors.orange),
          const SizedBox(width: 6),
          _statCard('Rejected', '${_stats['rejected'] ?? _rejectedCount}', Colors.red),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, {bool isLarge = false}) {
    return Expanded(
      flex: isLarge ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(color: color, fontSize: isLarge ? 12 : 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final tabs = [
      ('all', 'All (${_records.length})'),
      ('pending', 'Pending ($_pendingCount)'),
      ('approved', 'Approved ($_approvedCount)'),
      ('rejected', 'Rejected ($_rejectedCount)'),
    ];
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: tabs.map((t) {
          final selected = _statusFilter == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () { setState(() => _statusFilter = t.$1); },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(t.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.white38,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _payrollCard(Map<String, dynamic> r) {
    final name = r['userName'] ?? r['employeeName'] ??
        '${r['user']?['firstName'] ?? ''} ${r['user']?['lastName'] ?? ''}'.trim();
    final dept = r['department'] ?? r['departmentName'] ?? r['user']?['department']?['name'] ?? '';
    final empId = r['empId'] ?? r['employeeId'] ?? r['user']?['employeeId'] ?? '';
    final workingDays = r['workingDays'] ?? '—';
    final grossRaw = r['grossSalary'] ?? r['gross'] ?? 0;
    final gross = double.tryParse(grossRaw.toString()) ?? 0;
    final deductRaw = r['totalDeductions'] ?? r['deductions'] ?? 0;
    final deduct = double.tryParse(deductRaw.toString()) ?? 0;
    final netRaw = r['netSalary'] ?? r['net'] ?? (gross - deduct);
    final net = double.tryParse(netRaw.toString()) ?? 0;
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final id = r['id']?.toString() ?? '';
    final absentFine = r['absentFine'] ?? r['deductionBreakdown']?['absentFine'];
    final lateFine = r['lateFine'] ?? r['deductionBreakdown']?['lateFine'];

    final isPending = status.contains('pending');
    final isApproved = status.contains('approved') && !status.contains('pending');
    final statusColor = isApproved ? Colors.green : isPending ? Colors.orange : Colors.red;
    final statusLabel = isApproved ? 'approved'
        : isPending ? 'pending approval'
        : 'rejected';

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
          // Employee row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(dept.toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
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
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // Salary details row
          Row(
            children: [
              _infoCol('Working Days', '$workingDays'),
              _infoCol('Gross', 'PKR ${_formatAmount(gross)}'),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deductions',
                        style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    Text('PKR ${_formatAmount(deduct)}',
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (absentFine != null)
                      Text('Absent: PKR ${_formatAmount(double.tryParse(absentFine.toString()) ?? 0)}',
                          style: const TextStyle(color: Colors.red, fontSize: 9)),
                    if (lateFine != null)
                      Text('Late: PKR ${_formatAmount(double.tryParse(lateFine.toString()) ?? 0)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 9)),
                  ],
                ),
              ),
              _infoCol('Net Salary', 'PKR ${_formatAmount(net)}', color: Colors.green),
            ],
          ),
          const SizedBox(height: 10),

          // Status + Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (isPending) ...[
                _actionBtn('Approve', Colors.green,
                    () => _doAction(ApiService().approvePayroll(id), 'Approved')),
                const SizedBox(width: 4),
                _actionBtn('Reject', Colors.red,
                    () => _doAction(ApiService().rejectPayroll(id), 'Rejected')),
                const SizedBox(width: 4),
              ],
              _actionBtn('Edit Km', Colors.blueGrey, () => _showEditKm(r)),
              const SizedBox(width: 4),
              _actionBtn('View', const Color(0xFF3B82F6), () => _showPayslip(r)),
              const SizedBox(width: 4),
              _actionBtn('PDF', Colors.purple, () => _downloadPdf(id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _doAction(Future<void> action, String label) async {
    try {
      await action;
      _snack('$label successfully', Colors.green);
      await _loadPayroll();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    }
  }

  void _downloadPdf(String id) {
    if (id.isEmpty) return;
    final url = ApiService().getPayslipPdfUrl(id);
    html.window.open(url, '_blank');
  }

  void _showEditKm(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final kmCtrl = TextEditingController(
        text: (r['totalKm'] ?? r['kmTravelled'] ?? 0).toString());
    final rateCtrl = TextEditingController(
        text: (r['perKmRate'] ?? 0).toString());

    double fuelAmount = 0;
    double km = double.tryParse(kmCtrl.text) ?? 0;
    double rate = double.tryParse(rateCtrl.text) ?? 0;
    fuelAmount = km * rate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Edit Traveling (KM)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KM are auto-fetched from approved meetings. Adjust if needed and set the per-km rate to calculate fuel.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 14),
              const Text('Total KM Travelled', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: kmCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('0'),
                onChanged: (v) {
                  km = double.tryParse(v) ?? 0;
                  setLocal(() => fuelAmount = km * rate);
                },
              ),
              const SizedBox(height: 12),
              const Text('Per KM Rate (PKR)', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: rateCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDeco('0'),
                onChanged: (v) {
                  rate = double.tryParse(v) ?? 0;
                  setLocal(() => fuelAmount = km * rate);
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fuel Amount', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('PKR ${_formatAmount(fuelAmount)}',
                        style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiService().updatePayrollKm(id, km, rate);
                  _snack('KM updated', Colors.green);
                  await _loadPayroll();
                } catch (e) {
                  _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayslip(Map<String, dynamic> r) {
    final name = r['userName'] ?? r['employeeName'] ??
        '${r['user']?['firstName'] ?? ''} ${r['user']?['lastName'] ?? ''}'.trim();
    final empId = r['empId'] ?? r['employeeId'] ?? r['user']?['employeeId'] ?? '';
    final dept = r['department'] ?? r['departmentName'] ?? r['user']?['department']?['name'] ?? '';
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final present = r['presentDays'] ?? r['present'] ?? 0;
    final absent = r['absentDays'] ?? r['absent'] ?? 0;
    final monthStr = '${_monthsShort[_month - 1]} $_year';

    // Earnings
    final basic = double.tryParse((r['basicSalary'] ?? r['baseSalary'] ?? 0).toString()) ?? 0;
    final house = double.tryParse((r['houseAllowance'] ?? r['housingAllowance'] ?? 0).toString()) ?? 0;
    final transport = double.tryParse((r['transportAllowance'] ?? r['transport'] ?? 0).toString()) ?? 0;
    final medical = double.tryParse((r['medicalAllowance'] ?? r['medical'] ?? 0).toString()) ?? 0;
    final meal = double.tryParse((r['mealAllowance'] ?? r['meal'] ?? 0).toString()) ?? 0;
    final mobile = double.tryParse((r['mobileAllowance'] ?? r['mobile'] ?? 0).toString()) ?? 0;
    final commission = double.tryParse((r['commission'] ?? 0).toString()) ?? 0;
    final misc = double.tryParse((r['miscAllowance'] ?? r['misc'] ?? 0).toString()) ?? 0;
    final grossTotal = double.tryParse((r['grossSalary'] ?? r['gross'] ?? 0).toString()) ?? 0;

    // Deductions
    final tax = double.tryParse((r['incomeTax'] ?? r['tax'] ?? 0).toString()) ?? 0;
    final insurance = double.tryParse((r['insurance'] ?? 0).toString()) ?? 0;
    final advance = double.tryParse((r['advance'] ?? 0).toString()) ?? 0;
    final manualFine = double.tryParse((r['manualFine'] ?? 0).toString()) ?? 0;
    final otherDeduct = double.tryParse((r['otherDeduction'] ?? 0).toString()) ?? 0;
    final absentFine = double.tryParse((r['absentFine'] ?? 0).toString()) ?? 0;
    final totalDeduct = double.tryParse((r['totalDeductions'] ?? r['deductions'] ?? 0).toString()) ?? 0;
    final netSalary = double.tryParse((r['netSalary'] ?? r['net'] ?? 0).toString()) ?? 0;

    final statusColor = status.contains('approved') && !status.contains('pending')
        ? Colors.green
        : status.contains('pending') ? Colors.orange : Colors.red;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 8),
                              if (empId.toString().isNotEmpty)
                                Text('($empId)',
                                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status.contains('pending') ? 'pending approval' : status,
                                    style: TextStyle(color: statusColor, fontSize: 10)),
                              ),
                            ],
                          ),
                          Text(dept.toString(),
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          Text('$monthStr  ·  Present: $present / Absent: $absent',
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Earnings',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _slipRow('Basic Salary', basic),
                      _slipRow('House Allowance', house),
                      _slipRow('Transport', transport),
                      _slipRow('Medical', medical),
                      _slipRow('Meal / Lunch', meal),
                      _slipRow('Mobile Allowance', mobile),
                      _slipRow('Commission', commission),
                      _slipRow('Misc Allowance', misc),
                      const Divider(color: Colors.white12),
                      _slipRow('Gross Total', grossTotal, color: Colors.green, bold: true),
                      const SizedBox(height: 12),
                      const Text('Deductions',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _slipRow('Income Tax', tax, prefix: '–'),
                      _slipRow('Insurance', insurance, prefix: '–'),
                      _slipRow('Advance', advance, prefix: '–'),
                      _slipRow('Manual Fine', manualFine, prefix: '–'),
                      _slipRow('Other Deduction', otherDeduct, prefix: '–'),
                      _slipRow('Absent Fine', absentFine, prefix: '–'),
                      const Divider(color: Colors.white12),
                      _slipRow('Total Deductions', totalDeduct, color: Colors.red, bold: true, prefix: '–'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Net Salary',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('PKR ${_formatAmount(netSalary)}',
                                style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          final id = r['id']?.toString() ?? '';
                          Navigator.pop(context);
                          _downloadPdf(id);
                        },
                        icon: const Icon(Icons.download, color: Colors.white, size: 16),
                        label: const Text('Download PDF', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slipRow(String label, double value, {Color? color, bool bold = false, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text('$prefix PKR ${_formatAmount(value)}',
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF0F172A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          const Text('No payroll records found',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Press "Run Payroll" to generate records for this month.',
              style: TextStyle(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _formatAmount(double v) {
    if (v == 0) return '0.00';
    final str = v.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.$decPart';
  }
}
