import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});
  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('My Attendance',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'My Calendar'),
            Tab(text: 'Attendance\nRequests'),
            Tab(text: 'Leave\nRequests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MyCalendarTab(),
          _AttendanceRequestsTab(),
          _LeaveRequestsTab(),
        ],
      ),
    );
  }
}

// ─── MY CALENDAR TAB ──────────────────────────────────────────────────────────

class _MyCalendarTab extends StatefulWidget {
  const _MyCalendarTab();
  @override
  State<_MyCalendarTab> createState() => _MyCalendarTabState();
}

class _MyCalendarTabState extends State<_MyCalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _records = [];
  List<String> _publicHolidayDates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService().getMyMonthlyStats(month: _month.month, year: _month.year),
      ApiService().getMyAttendanceHistory(month: _month.month, year: _month.year),
    ]);
    setState(() {
      _stats = results[0] as Map<String, dynamic>;
      final historyData = results[1] as Map<String, dynamic>;
      _records = historyData['records'] as List<Map<String, dynamic>>;
      _publicHolidayDates = (historyData['publicHolidayDates'] as List).cast<String>();
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month >= now.month) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const mNames = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final present = _stats['present'] ?? _stats['presentDays'] ?? 0;
    final absent = _stats['absent'] ?? _stats['absentDays'] ?? 0;
    final late = _stats['late'] ?? _stats['lateDays'] ?? 0;
    final workingMins = _stats['totalMinutes'] ?? _stats['workingMinutes'] ?? 0;
    final wh = workingMins ~/ 60;
    final wm = workingMins % 60;
    final lateFine = (_stats['lateFine'] ?? 0.0).toDouble();
    final absentFine = (_stats['absentFine'] ?? 0.0).toDouble();

    final presentDates = <int>{};
    final lateDates = <int>{};
    final absentDates = <int>{};
    final holidayDates = <int>{};
    for (final r in _records) {
      final dateStr = r['date'] ?? r['checkIn'] ?? '';
      try {
        final d = DateTime.parse(dateStr);
        if (d.month == _month.month && d.year == _month.year) {
          final status = (r['status'] ?? 'present').toString().toLowerCase();
          if (status == 'late') lateDates.add(d.day);
          else if (status == 'absent') absentDates.add(d.day);
          else presentDates.add(d.day);
        }
      } catch (_) {}
    }
    for (final dateStr in _publicHolidayDates) {
      try {
        final d = DateTime.parse(dateStr);
        if (d.month == _month.month && d.year == _month.year) {
          holidayDates.add(d.day);
          absentDates.remove(d.day);
        }
      } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Month nav
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left, color: Color(0xFF374151)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Expanded(
                  child: Center(
                    child: Text('${mNames[_month.month - 1]} ${_month.year}',
                        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF374151)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats row
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            )
          else ...[
            Row(children: [
              _statBox('$present', 'Present', const Color(0xFF059669), const Color(0xFFF0FDF4)),
              const SizedBox(width: 10),
              _statBox('$absent', 'Absent', const Color(0xFFEF4444), const Color(0xFFFFF5F5)),
              const SizedBox(width: 10),
              _statBox('$late', 'Late', const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
              const SizedBox(width: 10),
              _statBox('${wh}h ${wm}m', 'Working Hours', const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _fineCard('PKR ${_fmtAmt(lateFine)}', 'Late Fine (est.)', const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fineCard('PKR ${_fmtAmt(absentFine)}', 'Absent Fine (est.)', const Color(0xFFEF4444), const Color(0xFFFFF5F5)),
              ),
            ]),
            const SizedBox(height: 12),

            // Calendar grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  // Day headers
                  Row(
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: const TextStyle(
                                        color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  _buildCalendarDays(presentDates, lateDates, absentDates, holidayDates),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(const Color(0xFF059669), 'Present'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFFF59E0B), 'Late'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFFEF4444), 'Absent'),
                      const SizedBox(width: 14),
                      _legendDot(const Color(0xFF8B5CF6), 'Holiday'),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCalendarDays(Set<int> present, Set<int> late, Set<int> absent, Set<int> holidays) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final today = DateTime.now();
    final isCurrentMonth = today.month == _month.month && today.year == _month.year;

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final isToday = isCurrentMonth && d == today.day;
      final isPresent = present.contains(d);
      final isLate = late.contains(d);
      final isAbsent = absent.contains(d);
      final isHoliday = holidays.contains(d);
      final isFuture = isCurrentMonth ? d > today.day : _month.isAfter(today);

      Color dotColor = Colors.transparent;
      Color textColor = isFuture ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
      if (isPresent) dotColor = const Color(0xFF059669);
      if (isLate) dotColor = const Color(0xFFF59E0B);
      if (isAbsent) dotColor = const Color(0xFFEF4444);
      if (isHoliday) dotColor = const Color(0xFF8B5CF6);

      cells.add(Container(
        height: 40,
        decoration: isToday
            ? BoxDecoration(
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$d', style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
            if (dotColor != Colors.transparent)
              Container(
                width: 5, height: 5,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
          ],
        ),
      ));
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      final rowCells = cells.sublist(i, i + 7 > cells.length ? cells.length : i + 7);
      while (rowCells.length < 7) rowCells.add(const SizedBox());
      rows.add(Row(children: rowCells.map((c) => Expanded(child: c)).toList()));
      if (i + 7 < cells.length) rows.add(const SizedBox(height: 4));
    }
    return Column(children: rows);
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
    ]);
  }

  Widget _statBox(String value, String label, Color textColor, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: textColor.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _fineCard(String amount, String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(amount, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
      ]),
    );
  }

  String _fmtAmt(double amt) {
    if (amt == 0) return '0';
    return amt.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

// ─── ATTENDANCE REQUESTS TAB ──────────────────────────────────────────────────

class _AttendanceRequestsTab extends StatefulWidget {
  const _AttendanceRequestsTab();
  @override
  State<_AttendanceRequestsTab> createState() => _AttendanceRequestsTabState();
}

class _AttendanceRequestsTabState extends State<_AttendanceRequestsTab> {
  final _dateCtrl = TextEditingController();
  final _inCtrl = TextEditingController();
  final _outCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String _filterStatus = 'all';
  List<Map<String, dynamic>> _requests = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _inCtrl.dispose();
    _outCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    final list = await ApiService().getMyAttendanceRequests(status: _filterStatus);
    setState(() { _requests = list; _loading = false; });
  }

  Future<void> _submit() async {
    if (_dateCtrl.text.isEmpty || _reasonCtrl.text.isEmpty) {
      _snack('Date and Reason are required', Colors.red);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService().submitAttendanceRequest({
        'date': _dateCtrl.text,
        'checkIn': _inCtrl.text,
        'checkOut': _outCtrl.text,
        'reason': _reasonCtrl.text,
      });
      _dateCtrl.clear(); _inCtrl.clear(); _outCtrl.clear(); _reasonCtrl.clear();
      _snack('Request submitted successfully', Colors.green);
      _loadRequests();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Submit form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submit Attendance Request',
                    style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 14),
                _label('DATE'),
                const SizedBox(height: 6),
                TextField(
                  controller: _dateCtrl,
                  readOnly: true,
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                  decoration: _inputDeco('mm/dd/yyyy', suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF))),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      _dateCtrl.text = '${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}/${d.year}';
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('IN'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _inCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                        decoration: _inputDeco('--:-- --', suffix: const Icon(Icons.access_time, size: 16, color: Color(0xFF9CA3AF))),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) _inCtrl.text = t.format(context);
                        },
                      ),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('OUT'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _outCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                        decoration: _inputDeco('--:-- --', suffix: const Icon(Icons.access_time, size: 16, color: Color(0xFF9CA3AF))),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) _outCtrl.text = t.format(context);
                        },
                      ),
                    ])),
                  ],
                ),
                const SizedBox(height: 10),
                _label('REASON', color: const Color(0xFF8B5CF6)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                  decoration: _inputDeco('Reason'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Attendance Request',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
                Expanded(
                  child: DropdownButton<String>(
                    value: _filterStatus,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    onChanged: (v) {
                      setState(() => _filterStatus = v!);
                      _loadRequests();
                    },
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All statuses')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // List
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF3B82F6))))
          else if (_requests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(child: Text('No attendance requests yet',
                  style: TextStyle(color: Color(0xFF9CA3AF)))),
            )
          else
            ..._requests.map((r) => _requestCard(r)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    Color sBg = const Color(0xFFFEF3C7);
    Color sText = const Color(0xFFF59E0B);
    if (status == 'approved') { sBg = const Color(0xFFD1FAE5); sText = const Color(0xFF059669); }
    if (status == 'rejected') { sBg = const Color(0xFFFFE4E6); sText = const Color(0xFFEF4444); }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r['date'] ?? '', style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: TextStyle(color: sText, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (r['checkIn'] != null || r['checkOut'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${r['checkIn'] ?? '--'} → ${r['checkOut'] ?? '--'}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ),
        if (r['reason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(r['reason'], style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ),
        if (r['rejectionReason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Rejected: ${r['rejectionReason']}',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _label(String t, {Color color = const Color(0xFF3B82F6)}) =>
      Text(t, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5));

  InputDecoration _inputDeco(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
    filled: true, fillColor: Colors.white,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );
}

// ─── LEAVE REQUESTS TAB ────────────────────────────────────────────────────────

class _LeaveRequestsTab extends StatefulWidget {
  const _LeaveRequestsTab();
  @override
  State<_LeaveRequestsTab> createState() => _LeaveRequestsTabState();
}

class _LeaveRequestsTabState extends State<_LeaveRequestsTab> {
  String _leaveType = 'Casual Leave';
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _submitting = false;
  String _filterStatus = 'all';
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = false;

  final _leaveTypes = ['Casual Leave', 'Sick Leave', 'Emergency Leave', 'Annual Leave', 'Half Day'];
  static const _leaveTypeApi = {
    'Casual Leave': 'casual', 'Sick Leave': 'sick', 'Emergency Leave': 'emergency',
    'Annual Leave': 'annual', 'Half Day': 'other',
  };

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    setState(() => _loading = true);
    final list = await ApiService().getMyLeaveRequests(status: _filterStatus);
    setState(() { _leaves = list; _loading = false; });
  }

  Future<void> _submit() async {
    if (_fromDate == null || _toDate == null || _reasonCtrl.text.isEmpty) {
      _snack('All fields are required', Colors.red);
      return;
    }
    setState(() => _submitting = true);
    try {
      final isoFrom = '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2,'0')}-${_fromDate!.day.toString().padLeft(2,'0')}';
      final isoTo   = '${_toDate!.year}-${_toDate!.month.toString().padLeft(2,'0')}-${_toDate!.day.toString().padLeft(2,'0')}';
      await ApiService().submitLeaveRequest({
        'leaveType': _leaveTypeApi[_leaveType] ?? 'casual',
        'startDate': isoFrom,
        'endDate': isoTo,
        'reason': _reasonCtrl.text,
      });
      _fromCtrl.clear(); _toCtrl.clear(); _reasonCtrl.clear();
      setState(() { _fromDate = null; _toDate = null; });
      _snack('Leave request submitted', Colors.green);
      _loadLeaves();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl, bool isFrom) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      ctrl.text = '${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}/${d.year}';
      setState(() { if (isFrom) _fromDate = d; else _toDate = d; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Submit form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Leave Request',
                    style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 14),
                _label('LEAVE TYPE', color: const Color(0xFF3B82F6)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _leaveType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    onChanged: (v) => setState(() => _leaveType = v!),
                    items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('FROM', color: const Color(0xFF059669)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _fromCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                        decoration: _inputDeco('mm/dd/yyyy', suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF))),
                        onTap: () => _pickDate(_fromCtrl, true),
                      ),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('TO', color: const Color(0xFFEF4444)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _toCtrl,
                        readOnly: true,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                        decoration: _inputDeco('mm/dd/yyyy', suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF))),
                        onTap: () => _pickDate(_toCtrl, false),
                      ),
                    ])),
                  ],
                ),
                const SizedBox(height: 10),
                _label('REASON', color: const Color(0xFF8B5CF6)),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                  decoration: _inputDeco('Briefly explain the reason for your leave...'),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Request',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Status filter chips
          Row(
            children: const [
              Text('Filter: ', style: TextStyle(color: Color(0xFF374151), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ['all', 'pending', 'approved', 'rejected'])
                GestureDetector(
                  onTap: () { setState(() => _filterStatus = s); _loadLeaves(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _filterStatus == s ? const Color(0xFF3B82F6) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _filterStatus == s ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB)),
                    ),
                    child: Text(
                      s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                      style: TextStyle(
                        color: _filterStatus == s ? Colors.white : const Color(0xFF374151),
                        fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Leave list
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF3B82F6))))
          else if (_leaves.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(child: Text('No leave requests yet',
                  style: TextStyle(color: Color(0xFF9CA3AF)))),
            )
          else
            ..._leaves.map((r) => _leaveCard(r)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    Color sBg = const Color(0xFFFEF3C7);
    Color sText = const Color(0xFFF59E0B);
    if (status == 'approved') { sBg = const Color(0xFFD1FAE5); sText = const Color(0xFF059669); }
    if (status == 'rejected') { sBg = const Color(0xFFFFE4E6); sText = const Color(0xFFEF4444); }

    final leaveType = r['leaveType'] ?? r['type'] ?? 'Leave';
    final from = r['from'] ?? r['startDate'] ?? '';
    final to = r['to'] ?? r['endDate'] ?? '';
    final days = r['days'] ?? r['totalDays'];
    String dateRange = from;
    if (to.isNotEmpty && to != from) dateRange += '  -  $to';
    if (days != null) dateRange += '  ($days day${days == 1 ? '' : 's'})';
    final reason = r['reason'] ?? '';
    final rejection = r['rejectionReason'] ?? r['adminComment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(leaveType,
              style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
            child: Text(status[0].toUpperCase() + status.substring(1),
                style: TextStyle(color: sText, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (dateRange.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(dateRange, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ),
        if (reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(reason, style: const TextStyle(color: Color(0xFF374151), fontSize: 12)),
          ),
        if (rejection.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Rejected: $rejection',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _label(String t, {Color color = const Color(0xFF3B82F6)}) =>
      Text(t, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5));

  InputDecoration _inputDeco(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
    filled: true, fillColor: Colors.white,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );
}
