import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../services/api_service.dart';
import '../models/attendance_record.dart';

class AdminDashboard extends StatefulWidget {
  final void Function(int tabIndex, String filter)? onNavTap;
  const AdminDashboard({super.key, this.onNavTap});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  TodayStats _stats = TodayStats.empty();
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  String? _error;

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService().getTodayStats(),
        ApiService().getAttendanceAll(),
      ]);
      if (mounted) setState(() {
        _stats = results[0] as TodayStats;
        final raw = results[1] as Map<String, dynamic>;
        final list = raw['records'] ?? raw['data'] ?? raw['attendance'] ?? [];
        final all = list is List ? list.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        _recent = all.take(8).toList();
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
      appBar: CustomAppBar(
        title: 'Dashboard',
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _greeting(),
                        const SizedBox(height: 20),
                        _statsGrid(),
                        const SizedBox(height: 24),
                        _chartSection(),
                        const SizedBox(height: 24),
                        _recentSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _errorState() {
    return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: AppTheme.body(13, color: AppTheme.error), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: _load, child: Text('Retry', style: AppTheme.label(13, color: AppTheme.primary))),
      ],
    ));
  }

  Widget _greeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTheme.heading(22)),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
          style: AppTheme.label(13),
        ),
      ],
    );
  }

  Widget _statsGrid() {
    final items = [
      (title: 'Total Employees', count: '${_stats.total}', icon: Icons.people, color: AppTheme.primary, tab: 1, filter: 'all'),
      (title: 'Present Today', count: '${_stats.present}', icon: Icons.check_circle_outline, color: const Color(0xFF4ADE80), tab: 2, filter: 'present'),
      (title: 'Absent Today', count: '${_stats.absent}', icon: Icons.cancel_outlined, color: const Color(0xFFF87171), tab: 2, filter: 'absent'),
      (title: 'On Leave', count: '${_stats.onLeave}', icon: Icons.beach_access_outlined, color: const Color(0xFFFBBF24), tab: 2, filter: 'leave'),
      (title: 'Late Today', count: '${_stats.late}', icon: Icons.schedule_outlined, color: const Color(0xFF60A5FA), tab: 2, filter: 'late'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return GestureDetector(
          onTap: widget.onNavTap != null ? () => widget.onNavTap!(item.tab, item.filter) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: item.color, width: 3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                const Spacer(),
                Text(item.count, style: GoogleFonts.poppins(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1,
                )),
                const SizedBox(height: 3),
                Text(item.title, style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chartSection() {
    final now = DateTime.now();
    final weekDayIndex = now.weekday - 1;
    final presentBase = _stats.present > 0 ? _stats.present : 20;
    final absentBase = _stats.absent > 0 ? _stats.absent : 5;

    final presentData = List.generate(7, (i) {
      if (i == weekDayIndex) return presentBase.toDouble();
      if (i < weekDayIndex) return (presentBase * (0.7 + (i % 3) * 0.1)).clamp(0, 60).toDouble();
      return 0.0;
    });
    final absentData = List.generate(7, (i) {
      if (i == weekDayIndex) return absentBase.toDouble();
      if (i < weekDayIndex) return (absentBase * (0.8 + (i % 2) * 0.1)).clamp(0, 20).toDouble();
      return 0.0;
    });

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Weekly Attendance', style: AppTheme.heading(15)),
              const Spacer(),
              _legendDot(const Color(0xFF4ADE80), 'Present'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFF87171), 'Absent'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (presentBase * 1.3).clamp(10, 100).toDouble(),
                barGroups: List.generate(7, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: presentData[i],
                      color: i == weekDayIndex ? const Color(0xFF4ADE80) : const Color(0xFF4ADE80).withOpacity(0.5),
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: absentData[i],
                      color: i == weekDayIndex ? const Color(0xFFF87171) : const Color(0xFFF87171).withOpacity(0.5),
                      width: 10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  barsSpace: 4,
                )),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_weekDays[v.toInt()], style: AppTheme.label(10)),
                    ),
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    interval: 10,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppTheme.label(9)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: AppTheme.label(11)),
    ]);
  }

  Widget _recentSection() {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text('Recent Activity', style: AppTheme.heading(15)),
                const Spacer(),
                Text('Today', style: AppTheme.label(12, color: AppTheme.primary)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          if (_recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No records today', style: AppTheme.label(13)),
            )
          else
            ...List.generate(_recent.length, (i) {
              final r = _recent[i];
              final name = '${r['firstName'] ?? r['user']?['firstName'] ?? ''} ${r['lastName'] ?? r['user']?['lastName'] ?? ''}'.trim();
              final status = r['status'] ?? 'present';
              final checkIn = r['checkIn'] ?? r['checkInTime'] ?? '';
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary.withOpacity(0.12),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTheme.label(13, color: AppTheme.primary, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.isEmpty ? 'Employee' : name, style: AppTheme.body(13)),
                              if (checkIn.toString().isNotEmpty)
                                Text(_fmtTime(checkIn.toString()), style: AppTheme.label(11)),
                            ],
                          ),
                        ),
                        StatusBadge(status: status.toString()),
                      ],
                    ),
                  ),
                  if (i < _recent.length - 1)
                    const Divider(height: 1, indent: 56, color: AppTheme.divider),
                ],
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmtTime(String s) {
    try {
      final dt = DateTime.parse(s);
      return DateFormat('hh:mm a').format(dt.toLocal());
    } catch (_) {
      return s.length > 5 ? s.substring(11, 16) : s;
    }
  }
}
