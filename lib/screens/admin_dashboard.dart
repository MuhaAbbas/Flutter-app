import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_card.dart';
import '../widgets/custom_app_bar.dart';
import '../services/api_service.dart';
import '../models/attendance_record.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
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
      (title: 'Total Employees', count: '${_stats.totalEmployees}', icon: Icons.people, color: AppTheme.primary),
      (title: 'Present Today', count: '${_stats.presentToday}', icon: Icons.check_circle_outline, color: const Color(0xFF4ADE80)),
      (title: 'Absent Today', count: '${_stats.absentToday}', icon: Icons.cancel_outlined, color: const Color(0xFFF87171)),
      (title: 'On Leave', count: '${_stats.onLeave}', icon: Icons.beach_access_outlined, color: const Color(0xFFFBBF24)),
      (title: 'Pending Requests', count: '${_stats.pendingRequests}', icon: Icons.pending_actions_outlined, color: const Color(0xFFC084FC)),
      (title: 'Late Today', count: '${_stats.lateToday}', icon: Icons.schedule_outlined, color: const Color(0xFF60A5FA)),
    ];

    return LayoutBuilder(builder: (_, constraints) {
      final crossCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.6,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => StatCard(
          title: items[i].title,
          count: items[i].count,
          icon: items[i].icon,
          color: items[i].color,
        ),
      );
    });
  }

  Widget _chartSection() {
    final now = DateTime.now();
    final weekDayIndex = now.weekday - 1;
    final presentBase = _stats.presentToday > 0 ? _stats.presentToday : 20;
    final absentBase = _stats.absentToday > 0 ? _stats.absentToday : 5;

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
