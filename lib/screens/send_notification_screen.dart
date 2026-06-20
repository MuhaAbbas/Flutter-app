import 'package:flutter/material.dart';
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
  String _audience = 'all';
  String? _selectedUserId;
  DateTime? _deadline;
  bool _sending = false;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _sentHistory = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final data = await ApiService().getEmployees();
    if (mounted) setState(() => _employees = data);
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      _snack('Title and message are required', Colors.red);
      return;
    }
    setState(() => _sending = true);
    try {
      final body = <String, dynamic>{
        'type': _type,
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'audience': _audience,
      };
      if (_audience == 'individual' && _selectedUserId != null) {
        body['userId'] = _selectedUserId;
      }
      if (_type == 'task' && _deadline != null) {
        body['deadline'] = _deadline!.toIso8601String();
      }
      await ApiService().sendNotification(body);
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() { _deadline = null; });
      _snack('Notification sent successfully', Colors.green);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showHistory() async {
    setState(() => _loadingHistory = true);
    final data = await ApiService().getSentNotifications();
    if (mounted) setState(() { _sentHistory = data; _loadingHistory = false; });

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.white54, size: 18),
                  SizedBox(width: 8),
                  Text('Sent History',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            Expanded(
              child: _sentHistory.isEmpty
                  ? const Center(
                      child: Text('No sent notifications',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _sentHistory.length,
                      itemBuilder: (_, i) => _historyItem(_sentHistory[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> n) {
    final title = n['title'] ?? '';
    final message = n['message'] ?? '';
    final type = n['type'] ?? 'notification';
    final audience = n['audience'] ?? 'all';
    final date = n['createdAt'] ?? n['sentAt'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                type == 'task' ? Icons.task_alt : Icons.notifications_outlined,
                color: type == 'task' ? Colors.orange : const Color(0xFF3B82F6),
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                audience == 'all' ? 'All' : 'Individual',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message.toString(),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (date.isNotEmpty)
            Text(_formatDate(date),
                style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Send Notification',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          _loadingHistory
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)))
              : TextButton.icon(
                  onPressed: _showHistory,
                  icon: const Icon(Icons.history, color: Colors.white54, size: 16),
                  label: const Text('Sent history',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notify employees individually, all employees, or every user.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),

            // Type toggle
            _field(
              label: 'Type',
              child: Row(
                children: [
                  _typeChip('notification', Icons.notifications_outlined, 'Notification'),
                  const SizedBox(width: 8),
                  _typeChip('task', Icons.task_alt_outlined, 'Task'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Audience toggle
            _field(
              label: 'Audience',
              child: Row(
                children: [
                  _audienceChip('all', 'All Employees'),
                  const SizedBox(width: 8),
                  _audienceChip('individual', 'Individual'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Individual employee picker
            if (_audience == 'individual') ...[
              _field(
                label: 'Select Employee',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUserId,
                      hint: const Text('Choose employee',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      iconEnabledColor: Colors.white38,
                      items: _employees.map((e) {
                        final name = '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'.trim();
                        final id = e['id']?.toString() ?? '';
                        return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedUserId = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Task deadline
            if (_type == 'task') ...[
              _field(
                label: 'Deadline (optional)',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(primary: Color(0xFF3B82F6))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                          _deadline != null
                              ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                              : 'Select deadline',
                          style: TextStyle(
                              color: _deadline != null ? Colors.white : Colors.white38,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Title
            _field(
              label: 'Title',
              child: TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDeco('Submit weekly report'),
              ),
            ),
            const SizedBox(height: 14),

            // Message
            _field(
              label: 'Message',
              child: TextField(
                controller: _messageCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 5,
                decoration: _inputDeco('Please submit your weekly activity report by EOD'),
              ),
            ),
            const SizedBox(height: 24),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                label: const Text('Send',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF3B82F6) : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: selected ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
    );
  }

  Widget _audienceChip(String value, String label) {
    final selected = _audience == value;
    return GestureDetector(
      onTap: () => setState(() => _audience = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF0F766E) : Colors.white12),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.white38,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
    filled: true,
    fillColor: const Color(0xFF1E293B),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
  );

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return iso; }
  }
}
