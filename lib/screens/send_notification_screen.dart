import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../services/api_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});
  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _type = 'notification';
  String _audience = 'employees';
  String _employeeTarget = 'all'; // 'all' or a specific userId
  String? _selectedDeptId;
  DateTime? _deadline;
  bool _sending = false;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final results = await Future.wait([ApiService().getEmployees(), ApiService().getDepartments()]);
    if (mounted) setState(() {
      _employees = results[0] as List<Map<String, dynamic>>;
      _departments = results[1] as List<Map<String, dynamic>>;
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final data = await ApiService().getSentNotifications();
    if (mounted) setState(() { _history = data; _loadingHistory = false; _showHistory = true; });
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _sending = true);
    try {
      final body = <String, dynamic>{
        'type': _type,
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      };
      if (_audience == 'employees') {
        if (_employeeTarget == 'all') {
          body['audience'] = 'all';
        } else {
          body['audience'] = 'individual';
          body['userId'] = _employeeTarget;
        }
      } else {
        body['audience'] = 'department';
        if (_selectedDeptId != null) body['departmentId'] = _selectedDeptId;
      }
      if (_type == 'task' && _deadline != null) body['deadline'] = _deadline!.toIso8601String();
      await ApiService().sendNotification(body);
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() { _deadline = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent'), backgroundColor: AppTheme.secondary));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Send Notification',
        actions: [
          _loadingHistory
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: AppTheme.textSecondary, strokeWidth: 2)))
              : TextButton.icon(
                  onPressed: _showHistory ? () => setState(() => _showHistory = false) : _loadHistory,
                  icon: Icon(_showHistory ? Icons.send_outlined : Icons.history,
                      color: AppTheme.textSecondary, size: 16),
                  label: Text(_showHistory ? 'Compose' : 'History',
                      style: AppTheme.label(12)),
                ),
        ],
      ),
      body: _showHistory ? _historyView() : _composeView(),
    );
  }

  Widget _composeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Compose Notification', style: AppTheme.heading(15)),
        const SizedBox(height: 4),
        Text('Notify employees individually, by department, or broadcast to all.',
            style: AppTheme.label(12)),
        const SizedBox(height: 20),

        // Type toggle
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Type', style: AppTheme.label(12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              _typeChip('notification', Icons.notifications_outlined, 'Notification'),
              const SizedBox(width: 10),
              _typeChip('task', Icons.task_alt_outlined, 'Task'),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // Audience toggle
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Audience', style: AppTheme.label(12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              _audienceChip('employees', 'Employees'),
              const SizedBox(width: 8),
              _audienceChip('department', 'Department'),
            ]),
            const SizedBox(height: 12),
            if (_audience == 'employees')
              _dropdown(
                value: _employeeTarget,
                hint: 'Select target',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Employees')),
                  ..._employees.map((e) {
                    final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                    final id = e['id']?.toString() ?? '';
                    return DropdownMenuItem(value: id, child: Text(name.isEmpty ? id : name, overflow: TextOverflow.ellipsis));
                  }),
                ],
                onChanged: (v) => setState(() => _employeeTarget = v ?? 'all'),
              ),
            if (_audience == 'department')
              _dropdown(
                value: _selectedDeptId,
                hint: 'Select department',
                items: _departments.map((d) => DropdownMenuItem(
                    value: d['id']?.toString() ?? '',
                    child: Text(d['name']?.toString() ?? '', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _selectedDeptId = v),
              ),
          ]),
        ),
        const SizedBox(height: 12),

        if (_type == 'task')
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Deadline (optional)', style: AppTheme.label(12, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (_, c) => Theme(
                      data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
                      child: c!,
                    ),
                  );
                  if (p != null) setState(() => _deadline = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(_deadline != null ? DateFormat('MMM d, yyyy').format(_deadline!) : 'Select deadline',
                        style: AppTheme.body(13, color: _deadline != null ? AppTheme.textPrimary : AppTheme.textSecondary)),
                  ]),
                ),
              ),
            ]),
          ),

        if (_type == 'task') const SizedBox(height: 12),

        // Title + Message
        SectionCard(
          child: Column(children: [
            _formField('Title', _titleCtrl, 'e.g. Submit weekly report'),
            const SizedBox(height: 14),
            _formField('Message', _messageCtrl, 'Write your message here...', maxLines: 5),
          ]),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, size: 18, color: Colors.white),
            label: Text('Send Now', style: AppTheme.label(15, color: Colors.white, weight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _historyView() {
    return Column(children: [
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.history, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text('${_history.length} sent notifications', style: AppTheme.label(12)),
        ]),
      ),
      Divider(height: 1, color: AppTheme.divider),
      Expanded(child: _history.isEmpty
          ? Center(child: Text('No notifications sent yet', style: AppTheme.label(13)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (_, i) => _histItem(_history[i]),
            )),
    ]);
  }

  Widget _histItem(Map<String, dynamic> n) {
    final title = n['title'] ?? '';
    final message = n['message'] ?? '';
    final type = n['type'] ?? 'notification';
    final audience = n['audience'] ?? 'all';
    final date = n['createdAt'] ?? n['sentAt'] ?? '';
    final isTask = type.toString().toLowerCase() == 'task';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (isTask ? AppTheme.warning : AppTheme.primary).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(isTask ? Icons.task_alt : Icons.notifications_outlined,
              color: isTask ? AppTheme.warning : AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title.toString(), style: AppTheme.body(13), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(6)),
              child: Text(audience.toString(), style: AppTheme.label(10)),
            ),
          ]),
          if (message.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message.toString(), style: AppTheme.label(11), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (date.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_fmtDate(date.toString()), style: AppTheme.label(10, color: AppTheme.primary)),
            ),
        ])),
      ]),
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final sel = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.label(12,
              color: sel ? AppTheme.primary : AppTheme.textSecondary,
              weight: sel ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _audienceChip(String value, String label) {
    final sel = _audience == value;
    return GestureDetector(
      onTap: () => setState(() => _audience = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppTheme.secondary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppTheme.secondary : AppTheme.divider),
        ),
        child: Text(label, style: AppTheme.label(12,
            color: sel ? AppTheme.secondary : AppTheme.textSecondary,
            weight: sel ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool hasNull = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppTheme.background, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.divider),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: AppTheme.label(13)),
        isExpanded: true,
        dropdownColor: AppTheme.surfaceElevated,
        style: AppTheme.body(13),
        iconEnabledColor: AppTheme.textSecondary,
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _formField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.label(12, color: AppTheme.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: AppTheme.body(13),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTheme.label(13),
          filled: true, fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary)),
        ),
      ),
    ],
  );

  String _fmtDate(String iso) {
    try { return DateFormat('MMM d, yyyy — hh:mm a').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return iso; }
  }
}
