import 'package:flutter/material.dart';
import '../models/meeting_request.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'active_visit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MeetingRequest> _visits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() { _loading = true; _error = null; });
    try {
      final visits = await ApiService().getMyVisits();
      setState(() { _visits = visits; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.fullName ?? 'Employee', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(user?.designation ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(onPressed: _loadVisits, icon: const Icon(Icons.refresh, color: Colors.white70)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.white70)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadVisits, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_visits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('No assigned visits', style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 8),
            Text('Admin se visit assign karwain', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisits,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _visits.length,
        itemBuilder: (_, i) => _VisitCard(visit: _visits[i], onTap: () => _openVisit(_visits[i])),
      ),
    );
  }

  void _openVisit(MeetingRequest visit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActiveVisitScreen(meeting: visit)),
    ).then((_) => _loadVisits());
  }
}

class _VisitCard extends StatelessWidget {
  final MeetingRequest visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = visit.isApproved ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha:0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visit.destinationName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha:0.4)),
                  ),
                  child: Text(
                    visit.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (visit.purpose != null) ...[
              const SizedBox(height: 8),
              Text(visit.purpose!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(visit.meetingDate, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (visit.meetingTime != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, color: Colors.white38, size: 13),
                  const SizedBox(width: 4),
                  Text(visit.meetingTime!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
