import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _meetings = [];
  List<Map<String, dynamic>> _activeVisits = [];
  bool _loading = true;
  String _statusFilter = 'all';

  static const _statuses = ['all', 'pending', 'approved', 'rejected'];
  static const _statusLabels = {
    'all': 'All Statuses',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadTab(_tabController.index);
    });
    _loadTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(int tab) async {
    setState(() => _loading = true);
    if (tab == 0) {
      final data = await ApiService().getMeetingsAll(status: _statusFilter);
      if (mounted) setState(() { _meetings = data; _loading = false; });
    } else {
      final data = await ApiService().getActiveVisits();
      if (mounted) setState(() { _activeVisits = data; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Meetings & Visits',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => _loadTab(_tabController.index),
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF3B82F6),
          tabs: [
            const Tab(text: 'All Meetings'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('Live Tracking'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllMeetings(),
          _buildLiveTracking(),
        ],
      ),
    );
  }

  // ── ALL MEETINGS ────────────────────────────────────────────────────────────

  Widget _buildAllMeetings() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
              : _meetings.isEmpty
                  ? _emptyState('No meetings found', Icons.location_off_outlined)
                  : RefreshIndicator(
                      onRefresh: () => _loadTab(0),
                      child: _buildGroupedList(_meetings),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          const Text('Filter:', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  iconEnabledColor: Colors.white38,
                  items: _statuses.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_statusLabels[s]!),
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                    _loadTab(0);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Map<String, dynamic>> meetings) {
    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final m in meetings) {
      final dateStr = _formatDateKey(m['date'] ?? m['visitDate'] ?? m['createdAt'] ?? '');
      grouped.putIfAbsent(dateStr, () => []).add(m);
    }

    final sections = grouped.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(section.key.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ),
            ...section.value.map(_meetingCard),
          ],
        );
      },
    );
  }

  Widget _meetingCard(Map<String, dynamic> m) {
    final empName = m['userName'] ?? m['employeeName'] ??
        '${m['user']?['firstName'] ?? ''} ${m['user']?['lastName'] ?? ''}'.trim();
    final empId = m['empId'] ?? m['employeeId'] ?? m['user']?['employeeId'] ?? '';
    final from = m['from'] ?? m['fromLocation'] ?? 'Office';
    final to = m['to'] ?? m['toLocation'] ?? m['destination'] ?? '';
    final distance = m['distance'] ?? m['totalKm'];
    final plan = m['plan'] ?? m['planType'] ?? 'On the spot';
    final status = (m['status'] ?? 'pending').toString().toLowerCase();
    final purpose = m['purpose'] ?? m['title'] ?? '';
    final date = m['date'] ?? m['visitDate'] ?? m['createdAt'] ?? '';
    final dayAbbr = _dayAbbr(date);
    final assignedBy = m['approvedBy'] ?? m['assignedBy'];

    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Text(dayAbbr,
                    style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const Text('—', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Employee
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            child: Text(
              empName.isNotEmpty ? empName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(empName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
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
                const SizedBox(height: 4),
                Text('$from → $to',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (distance != null) ...[
                      const Icon(Icons.directions_car, color: Colors.white38, size: 11),
                      const SizedBox(width: 3),
                      Text('${distance} km',
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    Text(plan.toString(),
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status[0].toUpperCase() + status.substring(1),
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          if (assignedBy != null)
                            Text('assigned by $assignedBy',
                                style: TextStyle(color: statusColor.withValues(alpha: 0.7), fontSize: 9)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (purpose.toString().isNotEmpty)
                      Expanded(
                        child: Text(purpose.toString(),
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LIVE TRACKING ───────────────────────────────────────────────────────────

  Widget _buildLiveTracking() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }
    if (_activeVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_outlined, size: 56, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            const Text('No employees currently on a visit',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _loadTab(1),
              icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF3B82F6)),
              label: const Text('Refresh', style: TextStyle(color: Color(0xFF3B82F6))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadTab(1),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _activeVisits.length,
        itemBuilder: (_, i) => _liveVisitCard(_activeVisits[i]),
      ),
    );
  }

  Widget _liveVisitCard(Map<String, dynamic> v) {
    final name = v['userName'] ?? '';
    final status = (v['status'] ?? '').toString().replaceAll('_', ' ');
    final liveKm = v['liveKm'] != null
        ? '${double.tryParse(v['liveKm'].toString())?.toStringAsFixed(1) ?? 0} km'
        : '0 km';
    final dest = v['toLocation'] ?? v['destination'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                if (dest.isNotEmpty)
                  Text(dest, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(status,
                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.gps_fixed, color: Colors.green, size: 14),
              Text(liveKm,
                  style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDateKey(String isoDate) {
    if (isoDate.isEmpty) return 'Unknown Date';
    try {
      final dt = DateTime.parse(isoDate);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }

  String _dayAbbr(String isoDate) {
    if (isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return days[dt.weekday - 1];
    } catch (_) {
      return '—';
    }
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}
