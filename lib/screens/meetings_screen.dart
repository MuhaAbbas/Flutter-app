import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_tab_bar.dart';
import '../services/api_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: CustomAppBar(
        title: 'Meetings',
        bottomHeight: 44,
        bottom: CustomTabBar(tabs: const ['All Meetings', 'Live Tracking'], controller: _tab),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_AllMeetingsTab(), _LiveTrackingTab()],
      ),
    );
  }
}

// ── All Meetings Tab ──────────────────────────────────────────────────────────

class _AllMeetingsTab extends StatefulWidget {
  const _AllMeetingsTab();
  @override
  State<_AllMeetingsTab> createState() => _AllMeetingsTabState();
}

class _AllMeetingsTabState extends State<_AllMeetingsTab> {
  List<Map<String, dynamic>> _meetings = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService().getMeetingsAll();
      if (mounted) setState(() { _meetings = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService().approveLeaveRequest(id);
      _load();
    } catch (_) {}
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService().cancelMeeting(id);
      _load();
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _meetings
      : _meetings.where((m) {
          final s = (m['status'] ?? '').toString().toLowerCase();
          return s == _filter;
        }).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filterBar(),
      Expanded(child: _body()),
    ]);
  }

  Widget _filterBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final f in ['all', 'upcoming', 'ongoing', 'completed', 'cancelled'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == f ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _filter == f ? AppTheme.primary : AppTheme.divider),
                ),
                child: Text(
                  '${f[0].toUpperCase()}${f.substring(1)}',
                  style: AppTheme.label(12,
                    color: _filter == f ? AppTheme.primary : AppTheme.textSecondary,
                    weight: _filter == f ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
          ),
      ]),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    if (_visible.isEmpty) return _emptyWidget('No meetings found');
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visible.length,
        itemBuilder: (_, i) => _card(_visible[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> m) {
    final title = m['title'] ?? m['purpose'] ?? m['subject'] ?? 'Meeting';
    final status = (m['status'] ?? 'upcoming').toString();
    final startTime = _fmtTime(m['startTime'] ?? m['date'] ?? m['meetingDate'] ?? '');
    final endTime = _fmtTime(m['endTime'] ?? '');
    final location = m['location'] ?? m['venue'] ?? m['link'] ?? '';
    final participants = m['participants'] as List? ?? m['attendees'] as List? ?? [];
    final id = m['id']?.toString() ?? '';
    final _u = m['employee'] ?? m['user'] ?? m['requestedBy'] ?? m['organizer'] ?? m['createdBy'] ?? {};
    final empName = () {
      final fn = (m['firstName'] ?? _u['firstName'] ?? '').toString();
      final ln = (m['lastName'] ?? _u['lastName'] ?? '').toString();
      if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
      return (_u['name'] ?? _u['fullName'] ?? m['name'] ?? m['employeeName'] ?? '').toString();
    }();
    final empId = (_u['employeeId'] ?? m['employeeId'] ?? '').toString();

    return GestureDetector(
      onTap: () => _showDetail(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title.toString(), style: AppTheme.body(14, color: AppTheme.textPrimary))),
            StatusBadge(status: status),
          ]),
          if (empName.isNotEmpty || empId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.person_outline, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                if (empName.isNotEmpty)
                  Text(empName, style: AppTheme.label(11)),
                if (empId.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(empId, style: AppTheme.label(9, color: AppTheme.primary, weight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            if (startTime.isNotEmpty) ...[
              const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('$startTime${endTime.isNotEmpty ? ' → $endTime' : ''}', style: AppTheme.label(11)),
              const SizedBox(width: 12),
            ],
            if (location.toString().isNotEmpty) ...[
              const Icon(Icons.place_outlined, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(location.toString(), style: AppTheme.label(11), overflow: TextOverflow.ellipsis)),
            ],
          ]),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 10),
            _avatarStack(participants),
          ],
          if (status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => _reject(id),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), padding: const EdgeInsets.symmetric(vertical: 8)),
                child: Text('Reject', style: AppTheme.label(12, color: AppTheme.error)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => _approve(id),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, padding: const EdgeInsets.symmetric(vertical: 8)),
                child: Text('Approve', style: AppTheme.label(12, color: Colors.white)),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _avatarStack(List participants) {
    final shown = participants.take(4).toList();
    return Row(children: [
      ...shown.asMap().entries.map((e) {
        final p = e.value;
        final name = '${p['firstName'] ?? p['name'] ?? '?'}';
        final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
        final color = colors[e.key % colors.length];
        return Transform.translate(
          offset: Offset(-e.key * 8.0, 0),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.surface, width: 2),
            ),
            child: Center(child: Text(name[0].toUpperCase(),
                style: AppTheme.label(10, color: color, weight: FontWeight.w700))),
          ),
        );
      }),
      if (participants.length > 4)
        Transform.translate(
          offset: Offset(-shown.length * 8.0 + 4, 0),
          child: Text('+${participants.length - 4}', style: AppTheme.label(11)),
        ),
    ]);
  }

  void _showDetail(Map<String, dynamic> m) {
    final title = m['title'] ?? m['purpose'] ?? 'Meeting';
    final purpose = m['purpose'] ?? m['description'] ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.5, maxChildSize: 0.85,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
          Text(title.toString(), style: AppTheme.heading(16)),
          const SizedBox(height: 12),
          if (purpose.toString().isNotEmpty)
            Text(purpose.toString(), style: AppTheme.label(13)),
        ]),
      ),
    );
  }

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try { return DateFormat('MMM d, hh:mm a').format(DateTime.parse(v.toString()).toLocal()); }
    catch (_) { return v.toString(); }
  }
}

// ── Live Tracking Tab ─────────────────────────────────────────────────────────

class _LiveTrackingTab extends StatefulWidget {
  const _LiveTrackingTab();
  @override
  State<_LiveTrackingTab> createState() => _LiveTrackingTabState();
}

class _LiveTrackingTabState extends State<_LiveTrackingTab> {
  List<Map<String, dynamic>> _active = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await ApiService().getMeetingsAll();
      if (mounted) setState(() {
        _active = all.where((m) =>
          (m['status'] ?? '').toString().toLowerCase() == 'ongoing').toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _errWidget(_error!, _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: Column(children: [
                    _liveHeader(),
                    Expanded(child: _active.isEmpty
                        ? _emptyWidget('No meetings currently ongoing')
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _active.length,
                            itemBuilder: (_, i) => _liveCard(_active[i]),
                          )),
                  ]),
                ),
    );
  }

  Widget _liveHeader() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: Row(children: [
      _pulseDot(),
      const SizedBox(width: 10),
      Text('${_active.length} Meeting${_active.length == 1 ? '' : 's'} Live',
          style: AppTheme.body(14, color: AppTheme.textPrimary)),
      const Spacer(),
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20)),
    ]),
  );

  Widget _pulseDot() => Container(
    width: 10, height: 10,
    decoration: const BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
  ).animate(onPlay: (c) => c.repeat()).scale(
    begin: const Offset(1, 1),
    end: const Offset(1.6, 1.6),
    duration: 900.ms,
    curve: Curves.easeInOut,
  ).then().scale(
    begin: const Offset(1.6, 1.6),
    end: const Offset(1, 1),
    duration: 900.ms,
    curve: Curves.easeInOut,
  );

  Widget _liveCard(Map<String, dynamic> m) {
    final title = m['title'] ?? m['purpose'] ?? 'Meeting';
    final participants = m['participants'] as List? ?? m['attendees'] as List? ?? [];
    final location = m['location'] ?? m['venue'] ?? '';
    final startTime = _fmtTime(m['startTime'] ?? m['date'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.secondary.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pulseDot(),
          const SizedBox(width: 10),
          Expanded(child: Text(title.toString(), style: AppTheme.body(14))),
          StatusBadge(status: 'ongoing'),
        ]),
        const SizedBox(height: 10),
        if (startTime.isNotEmpty)
          Row(children: [
            const Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('Started $startTime', style: AppTheme.label(11)),
          ]),
        if (location.toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.place_outlined, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(location.toString(), style: AppTheme.label(11)),
          ]),
        ],
        if (participants.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Participants (${participants.length})', style: AppTheme.label(12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: participants.take(6).map((p) {
              final name = '${p['firstName'] ?? p['name'] ?? ''}';
              final status = (p['attendanceStatus'] ?? p['status'] ?? 'present').toString();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: status.toLowerCase() == 'present' ? AppTheme.secondary : AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(name.isNotEmpty ? name : 'Unknown', style: AppTheme.label(11)),
                ]),
              );
            }).toList(),
          ),
        ],
      ]),
    );
  }

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try { return DateFormat('hh:mm a').format(DateTime.parse(v.toString()).toLocal()); }
    catch (_) { return v.toString(); }
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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
