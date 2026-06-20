import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmployeeActivityLogsScreen extends StatefulWidget {
  const EmployeeActivityLogsScreen({super.key});
  @override
  State<EmployeeActivityLogsScreen> createState() => _EmployeeActivityLogsScreenState();
}

class _EmployeeActivityLogsScreenState extends State<EmployeeActivityLogsScreen> {
  // Form state
  bool _isToday = true;
  final _titleCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '8');
  final _descCtrl = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _submitting = false;
  bool _alreadySubmitted = false;

  // History state
  DateTime _historyMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;

  final _allTags = [
    '#Recovery', '#Followup', '#NewClient', '#Payment', '#Demo',
    '#Complaint', '#Order', '#Quote', '#Meeting', '#Proposal',
    '#Delivery', '#Return', '#Urgent', '#CNCsale', '#FICOsale',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _projectCtrl.dispose();
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final list = await ApiService().getMyActivityLogs(
        month: _historyMonth.month, year: _historyMonth.year);
    setState(() { _history = list; _loadingHistory = false; });

    // Check if today/yesterday already submitted
    final targetDate = _isToday ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1));
    final submitted = list.any((r) {
      try {
        final d = DateTime.parse(r['date'] ?? r['createdAt'] ?? '');
        return d.day == targetDate.day && d.month == targetDate.month && d.year == targetDate.year;
      } catch (_) { return false; }
    });
    setState(() => _alreadySubmitted = submitted);
  }

  Future<void> _submitReport() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Activity title is required', Colors.red);
      return;
    }
    setState(() => _submitting = true);
    try {
      final targetDate = _isToday
          ? DateTime.now()
          : DateTime.now().subtract(const Duration(days: 1));
      await ApiService().submitActivityLog({
        'title': _titleCtrl.text.trim(),
        'project': _projectCtrl.text.trim(),
        'hoursSpent': double.tryParse(_hoursCtrl.text) ?? 8.0,
        'tags': _selectedTags.toList(),
        'description': _descCtrl.text.trim(),
        'date': targetDate.toIso8601String().split('T')[0],
        'isYesterday': !_isToday,
      });
      _titleCtrl.clear(); _projectCtrl.clear(); _descCtrl.clear();
      _hoursCtrl.text = '8';
      _selectedTags.clear();
      _snack('Activity report submitted!', Colors.green);
      _loadHistory();
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
    final now = DateTime.now();
    final targetDate = _isToday ? now : now.subtract(const Duration(days: 1));
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final dateStr = '${dayNames[targetDate.weekday - 1]}, ${monthNames[targetDate.month - 1]} ${targetDate.day}, ${targetDate.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Activity Logs',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Track your daily work activities",
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 14),

            // Today's Activity card
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
                  const Text("Today's Activity",
                      style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Today/Yesterday toggle
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _toggleBtn('Today', _isToday, () { setState(() { _isToday = true; }); _loadHistory(); }),
                            _toggleBtn('Yesterday', !_isToday, () { setState(() { _isToday = false; }); _loadHistory(); }),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _alreadySubmitted ? const Color(0xFFD1FAE5) : const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _alreadySubmitted ? 'Submitted' : 'Not submitted',
                          style: TextStyle(
                            color: _alreadySubmitted ? const Color(0xFF059669) : const Color(0xFF92400E),
                            fontSize: 11, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(dateStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  const SizedBox(height: 14),

                  _label('ACTIVITY TITLE'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    decoration: _inputDeco('What did you work on today?'),
                  ),
                  const SizedBox(height: 10),

                  _label('PROJECT NAME (OPTIONAL)', color: const Color(0xFF8B5CF6)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _projectCtrl,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    decoration: _inputDeco('Project or team name'),
                  ),
                  const SizedBox(height: 10),

                  _label('HOURS SPENT (8H)', color: const Color(0xFF059669)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _hoursCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                      decoration: _inputDeco('8'),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _label('DESCRIPTION', color: const Color(0xFFF59E0B)),
                  const SizedBox(height: 8),

                  // Hashtag chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allTags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) _selectedTags.remove(tag); else _selectedTags.add(tag);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB)),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF374151),
                                fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFF111827), fontSize: 13),
                    decoration: _inputDeco('Describe your tasks, progress, and blockers...'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(height: 16, width: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Report',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Activity History
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: const Text('Activity History',
                        style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(height: 10),
                  // Month nav
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _historyMonth = DateTime(_historyMonth.year, _historyMonth.month - 1));
                            _loadHistory();
                          },
                          icon: const Icon(Icons.chevron_left, size: 16),
                          label: const Text('Prev', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _monthLabel(_historyMonth),
                              style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            final now = DateTime.now();
                            if (_historyMonth.year == now.year && _historyMonth.month >= now.month) return;
                            setState(() => _historyMonth = DateTime(_historyMonth.year, _historyMonth.month + 1));
                            _loadHistory();
                          },
                          icon: const Icon(Icons.chevron_right, size: 16),
                          label: const Text('Next', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
                    )
                  else if (_history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No activity logs for this month',
                          style: TextStyle(color: Color(0xFF9CA3AF)))),
                    )
                  else
                    ..._history.map((r) => _historyItem(r)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> r) {
    final title = r['title'] ?? r['activityTitle'] ?? 'Activity';
    final project = r['project'] ?? r['projectName'] ?? '';
    final hours = r['hoursSpent'] ?? r['hours'] ?? 8;
    final tags = (r['tags'] as List?)?.cast<String>() ?? [];
    final desc = r['description'] ?? '';
    final dateStr = _fmtDate(r['date'] ?? r['createdAt'] ?? '');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Text('$hours h', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('submitted', style: TextStyle(color: Color(0xFF059669), fontSize: 10)),
                  ),
                ],
              ),
              if (dateStr.isNotEmpty || project.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('$dateStr${project.isNotEmpty ? ' · $project' : ''}',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                ),
              if (desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(desc,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(t, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10)),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF6B7280),
              fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _label(String t, {Color color = const Color(0xFF3B82F6)}) =>
      Text(t, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5));

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );

  String _monthLabel(DateTime dt) {
    const months = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${days[d.weekday-1]}, ${months[d.month-1]} ${d.day}';
    } catch (_) { return iso; }
  }
}
