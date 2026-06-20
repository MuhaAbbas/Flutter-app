import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmployeeMeetingsScreen extends StatefulWidget {
  const EmployeeMeetingsScreen({super.key});
  @override
  State<EmployeeMeetingsScreen> createState() => _EmployeeMeetingsScreenState();
}

class _EmployeeMeetingsScreenState extends State<EmployeeMeetingsScreen> {
  final _fromCtrl = TextEditingController(text: 'Home');
  final _toCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _stopsCtrl = TextEditingController();
  bool _submitting = false;
  String _filterStatus = 'all';
  List<Map<String, dynamic>> _meetings = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateCtrl.text = '${now.month.toString().padLeft(2,'0')}/${now.day.toString().padLeft(2,'0')}/${now.year}';
    _loadMeetings();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _purposeCtrl.dispose();
    _stopsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    setState(() => _loading = true);
    final list = await ApiService().getMyMeetings(status: _filterStatus);
    setState(() { _meetings = list; _loading = false; });
  }

  Future<void> _submit() async {
    if (_toCtrl.text.isEmpty || _dateCtrl.text.isEmpty) {
      _snack('Destination and Date are required', Colors.red);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService().submitVisitRequest({
        'from': _fromCtrl.text.trim(),
        'to': _toCtrl.text.trim(),
        'date': _dateCtrl.text,
        'time': _timeCtrl.text,
        'purpose': _purposeCtrl.text.trim(),
        'plannedStops': int.tryParse(_stopsCtrl.text) ?? 0,
      });
      _toCtrl.clear(); _timeCtrl.clear(); _purposeCtrl.clear(); _stopsCtrl.clear();
      _snack('Visit request submitted', Colors.green);
      _loadMeetings();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Meetings & Visits',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request a visit to another site (home → site, or office → site). '
              'Distance and time are calculated automatically.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 14),

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
                  const Text('Submit a meeting/visit request',
                      style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('FROM', color: const Color(0xFF059669)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _fromCtrl,
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                          decoration: _inputDeco('Home'),
                        ),
                      ])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('TO', color: const Color(0xFFEF4444)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _toCtrl,
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                          decoration: _inputDeco('e.g. Gulshan branch'),
                        ),
                      ])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('DATE', color: const Color(0xFF3B82F6)),
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
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (d != null) {
                              _dateCtrl.text = '${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}/${d.year}';
                            }
                          },
                        ),
                      ])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('TIME', color: const Color(0xFFF59E0B)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _timeCtrl,
                          readOnly: true,
                          style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                          decoration: _inputDeco('--:-- --', suffix: const Icon(Icons.access_time, size: 16, color: Color(0xFF9CA3AF))),
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (t != null) _timeCtrl.text = t.format(context);
                          },
                        ),
                      ])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _label('PURPOSE (OPTIONAL)', color: const Color(0xFF8B5CF6)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _purposeCtrl,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    decoration: _inputDeco('e.g. Inventory audit at the shop'),
                  ),
                  const SizedBox(height: 10),
                  _label('PLANNED STOPS', color: const Color(0xFF059669)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _stopsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    decoration: _inputDeco('e.g. 3'),
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
                          : const Text('Submit Request',
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
                      onChanged: (v) { setState(() => _filterStatus = v!); _loadMeetings(); },
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
            const SizedBox(height: 12),

            // Meetings table
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF3B82F6))))
            else if (_meetings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(child: Text('No visits found',
                    style: TextStyle(color: Color(0xFF9CA3AF)))),
              )
            else
              _buildMeetingsTable(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsTable() {
    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _meetings) {
      final date = m['date'] ?? m['meetingDate'] ?? m['createdAt'] ?? '';
      String key = date;
      try {
        final d = DateTime.parse(date);
        const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
        const months = ['January','February','March','April','May','June',
          'July','August','September','October','November','December'];
        key = '${days[d.weekday - 1].substring(0,3).toUpperCase()}, ${months[d.month - 1].toUpperCase()} ${d.day}, ${d.year}';
      } catch (_) {}
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 60, child: Text('DATE', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(child: Text('FROM → TO / DISTANCE / STATUS', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...grouped.entries.map((e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFFF3F4F6),
                child: Text(e.key,
                    style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              ...e.value.map((m) => _meetingRow(m)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _meetingRow(Map<String, dynamic> m) {
    final stops = m['stops'] as List? ?? m['visitStops'] as List? ?? [];
    final from = m['from'] ?? m['fromLocation'] ?? 'Office';
    final to = m['to'] ?? m['destination'] ?? m['destinationName'] ?? '';
    final status = (m['status'] ?? 'pending').toString().toLowerCase();
    final purpose = m['purpose'] ?? '';
    final plan = m['plan'] ?? m['meetingPlan'] ?? '';
    final totalKm = (m['totalKm'] ?? m['totalDistance'] ?? 0.0).toDouble();
    final totalTime = m['totalDuration'] ?? m['visitDuration'] ?? '';
    final date = m['date'] ?? m['meetingDate'] ?? '';
    String timeStr = '';
    try {
      final d = DateTime.parse(date);
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      timeStr = '${days[d.weekday-1]}\n${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) {}

    Color sBg = const Color(0xFFFEF3C7);
    Color sText = const Color(0xFFF59E0B);
    if (status == 'approved') { sBg = const Color(0xFFD1FAE5); sText = const Color(0xFF059669); }
    if (status == 'rejected') { sBg = const Color(0xFFFFE4E6); sText = const Color(0xFFEF4444); }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: Text(timeStr,
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route stops
                    if (stops.isNotEmpty)
                      ...stops.map<Widget>((s) {
                        final sf = s['from'] ?? '';
                        final st = s['to'] ?? '';
                        final km = (s['km'] ?? s['distance'] ?? 0.0).toDouble();
                        final dur = s['duration'] ?? s['time'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$sf → $st', style: const TextStyle(color: Color(0xFF374151), fontSize: 12)),
                            Text('${km.toStringAsFixed(2)} km${dur.isNotEmpty ? ' · $dur' : ''}',
                                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11)),
                          ]),
                        );
                      })
                    else
                      Text('$from → $to', style: const TextStyle(color: Color(0xFF374151), fontSize: 12)),
                    if (totalKm > 0 || totalTime.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Total: ${totalKm.toStringAsFixed(2)} km${totalTime.isNotEmpty ? ' · $totalTime' : ''}',
                          style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (plan.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Text(plan, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(12)),
                          child: Text(status[0].toUpperCase() + status.substring(1),
                              style: TextStyle(color: sText, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        if (purpose.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(purpose, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                          ),
                        const Spacer(),
                        if (status == 'approved')
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text('Track Visit', style: TextStyle(color: Color(0xFF374151), fontSize: 11)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
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
