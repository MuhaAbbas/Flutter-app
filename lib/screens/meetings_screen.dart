import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
        // Prevent horizontal swipe from switching tabs — conflicts with table scroll
        physics: const NeverScrollableScrollPhysics(),
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
  Map<String, Map<String, dynamic>> _empById = {};
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  // Synced horizontal scroll controllers
  late final ScrollController _hHeader;
  late final ScrollController _hBody;
  bool _hSyncing = false;

  @override
  void initState() {
    super.initState();
    _hHeader = ScrollController();
    _hBody   = ScrollController();
    _hHeader.addListener(_onHeaderScroll);
    _hBody.addListener(_onBodyScroll);
    _load();
  }

  void _onHeaderScroll() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hBody.hasClients) _hBody.jumpTo(_hHeader.offset.clamp(_hBody.position.minScrollExtent, _hBody.position.maxScrollExtent));
    _hSyncing = false;
  }

  void _onBodyScroll() {
    if (_hSyncing) return;
    _hSyncing = true;
    if (_hHeader.hasClients) _hHeader.jumpTo(_hBody.offset.clamp(_hHeader.position.minScrollExtent, _hHeader.position.maxScrollExtent));
    _hSyncing = false;
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService().getMeetingsAll(),
        ApiService().getEmployees(),
      ]);
      final meetings = results[0] as List<Map<String, dynamic>>;
      final employees = results[1] as List<Map<String, dynamic>>;
      final empById = <String, Map<String, dynamic>>{};
      for (final e in employees) {
        final id = (e['id'] ?? e['_id'] ?? '').toString();
        if (id.isNotEmpty) empById[id] = e;
      }
      if (mounted) setState(() { _meetings = meetings; _empById = empById; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cancel(String id) async {
    try { await ApiService().cancelMeeting(id); _load(); } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  List<Map<String, dynamic>> get _visible => _statusFilter == 'all'
      ? _meetings
      : _meetings.where((m) => (m['status'] ?? '').toString().toLowerCase() == _statusFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filterBar(),
      Expanded(child: _body()),
    ]);
  }

  Widget _filterBar() => Container(
    color: AppTheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(children: [
      Text('Meetings & Visits', style: AppTheme.heading(16)),
      const Spacer(),
      SizedBox(width: 180, child: _dropFilter(
        value: _statusFilter,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Status')),
          DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
          DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
          DropdownMenuItem(value: 'completed', child: Text('Completed')),
          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
          DropdownMenuItem(value: 'pending', child: Text('Pending')),
        ],
        onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
      )),
      const SizedBox(width: 10),
      IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20), padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
    ]),
  );

  Widget _dropFilter({required String value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 40,
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.divider)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: AppTheme.surfaceElevated, style: AppTheme.body(12), iconEnabledColor: AppTheme.textSecondary, items: items, onChanged: onChanged),
      ),
    );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_error != null) return _errWidget(_error!, _load);
    final shown = _visible;
    if (shown.isEmpty) return _emptyWidget('No meetings found');

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in shown) {
      final raw = m['date'] ?? m['meetingDate'] ?? m['startTime'] ?? m['visitDate'] ?? '';
      String key = '—';
      try { key = DateFormat('yyyy-MM-dd').format(DateTime.parse(raw.toString())); } catch (_) {}
      (grouped[key] ??= []).add(m);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('Showing ${shown.length} record${shown.length == 1 ? '' : 's'}', style: AppTheme.label(12, color: AppTheme.textSecondary))),
      ),
      Container(
        color: AppTheme.background,
        child: SingleChildScrollView(controller: _hHeader, scrollDirection: Axis.horizontal, child: _tableHeader()),
      ),
      Divider(color: AppTheme.divider, height: 1),
      Expanded(child: RefreshIndicator(
        onRefresh: _load, color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SingleChildScrollView(
            controller: _hBody,
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final date in dates) ...[
                _dateGroupHeader(date),
                ...grouped[date]!.asMap().entries.map((e) => _meetingRow(e.value, e.key.isOdd)),
              ],
            ]),
          ),
        ),
      )),
    ]);
  }

  Widget _tableHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      _th(130, 'Date'),
      _th(200, 'Employee'),
      _th(90, 'Emp. ID'),
      _th(180, 'From → To'),
      _th(130, 'Distance/Time'),
      _th(130, 'Plan'),
      _th(100, 'Status', center: true),
      _th(200, 'Purpose'),
      _th(90, 'Actions', center: true),
    ]),
  );

  Widget _dateGroupHeader(String date) {
    String label = date;
    try {
      final dt = DateTime.parse(date);
      label = DateFormat('EEEE, MMMM d, yyyy').format(dt).toUpperCase();
    } catch (_) {}
    return Container(
      width: 1250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Text(label, style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w700)),
    );
  }

  Widget _meetingRow(Map<String, dynamic> m, bool alt) {
    // Try inline nested user object first, then fall back to employee lookup by userId
    final u = m['employee'] is Map ? m['employee'] as Map
        : (m['user'] is Map ? m['user'] as Map
        : (m['createdBy'] is Map ? m['createdBy'] as Map : <String, dynamic>{}));
    final userId = (m['userId'] ?? m['user_id'] ?? u['id'] ?? u['_id'] ?? '').toString();
    final lookedUp = _empById[userId] ?? {};
    final firstName = (m['firstName'] ?? u['firstName'] ?? lookedUp['firstName'] ?? '').toString();
    final lastName  = (m['lastName']  ?? u['lastName']  ?? lookedUp['lastName']  ?? '').toString();
    String name = '$firstName $lastName'.trim();
    if (name.isEmpty) name = (u['name'] ?? u['fullName'] ?? lookedUp['name'] ?? m['employeeName'] ?? '').toString();
    final email = (m['email'] ?? u['email'] ?? lookedUp['email'] ?? '').toString();
    final empId = (m['employeeId'] ?? u['employeeId'] ?? lookedUp['employeeId'] ?? m['userEmployeeId'] ?? '').toString();
    final status = (m['status'] ?? 'upcoming').toString();
    final dateRaw = m['date'] ?? m['meetingDate'] ?? m['startTime'] ?? m['visitDate'] ?? '';
    String dateStr = '—';
    try { dateStr = DateFormat('MMM d').format(DateTime.parse(dateRaw.toString())); } catch (_) {}
    final startTime = _fmtTime(m['startTime'] ?? m['checkIn'] ?? m['fromTime'] ?? '');
    final endTime = _fmtTime(m['endTime'] ?? m['checkOut'] ?? m['toTime'] ?? '');
    final distance = m['distance'] ?? m['totalDistance'] ?? '';
    final duration = m['duration'] ?? m['totalTime'] ?? m['travelTime'] ?? '';
    final distStr = [
      if (distance.toString().isNotEmpty && distance.toString() != 'null') '${distance}km',
      if (duration.toString().isNotEmpty && duration.toString() != 'null') '${duration}m',
    ].join(' / ');
    final plan = m['plan'] ?? m['visitPlan'] ?? m['agenda'] ?? '—';
    final purpose = m['purpose'] ?? m['title'] ?? m['subject'] ?? m['description'] ?? '—';
    final id = (m['id'] ?? m['_id'] ?? '').toString();
    final cs = [AppTheme.primary, AppTheme.secondary, const Color(0xFFC084FC), const Color(0xFFFBBF24)];
    final ac = cs[name.isNotEmpty ? name.codeUnitAt(0) % cs.length : 0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: alt ? AppTheme.background.withOpacity(0.5) : AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 130, child: Text(dateStr, style: AppTheme.label(12))),
        SizedBox(width: 200, child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: ac.withOpacity(0.15),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTheme.label(11, color: ac, weight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isNotEmpty ? name : '—', style: AppTheme.body(12), overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty) Text(email, style: AppTheme.label(9), overflow: TextOverflow.ellipsis),
          ])),
        ])),
        SizedBox(width: 90, child: Text(empId.isNotEmpty ? empId : '—', style: AppTheme.label(11, color: AppTheme.primary, weight: FontWeight.w600))),
        SizedBox(width: 180, child: Text(startTime.isNotEmpty ? '$startTime${endTime.isNotEmpty ? " → $endTime" : ""}' : '—', style: AppTheme.label(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 130, child: Text(distStr.isNotEmpty ? distStr : '—', style: AppTheme.label(12))),
        SizedBox(width: 130, child: Text(plan.toString().isNotEmpty ? plan.toString() : '—', style: AppTheme.label(12), overflow: TextOverflow.ellipsis)),
        SizedBox(width: 100, child: Center(child: StatusBadge(status: status, fontSize: 10))),
        SizedBox(width: 200, child: Text(purpose.toString(), style: AppTheme.label(12), overflow: TextOverflow.ellipsis, maxLines: 2)),
        SizedBox(width: 90, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () => _showDetail(m),
            borderRadius: BorderRadius.circular(6),
            child: Padding(padding: const EdgeInsets.all(5), child: Icon(Icons.visibility_outlined, size: 15, color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 2),
          if (status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'completed')
            InkWell(
              onTap: () => _cancel(id),
              borderRadius: BorderRadius.circular(6),
              child: Padding(padding: const EdgeInsets.all(5), child: Icon(Icons.cancel_outlined, size: 15, color: AppTheme.error)),
            ),
        ]))),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> m) {
    final title = m['title'] ?? m['purpose'] ?? m['subject'] ?? 'Meeting';
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
          if (purpose.toString().isNotEmpty) Text(purpose.toString(), style: AppTheme.label(13)),
        ]),
      ),
    );
  }

  String _fmtTime(dynamic v) {
    if (v == null || v.toString().isEmpty || v.toString() == 'null') return '';
    try { return DateFormat('h:mm a').format(DateTime.parse(v.toString()).toLocal()); }
    catch (_) { return v.toString().length > 5 ? v.toString().substring(0, 5) : v.toString(); }
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
      IconButton(onPressed: _load, icon: Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20)),
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
            Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('Started $startTime', style: AppTheme.label(11)),
          ]),
        if (location.toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.place_outlined, size: 12, color: AppTheme.textSecondary),
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

Widget _th(double w, String label, {bool center = false}) => SizedBox(
  width: w,
  child: Align(
    alignment: center ? Alignment.center : Alignment.centerLeft,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
  ),
);

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
