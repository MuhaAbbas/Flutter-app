import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/meeting_request.dart';
import '../models/visit_tracking.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class ActiveVisitScreen extends StatefulWidget {
  final MeetingRequest meeting;

  const ActiveVisitScreen({super.key, required this.meeting});

  @override
  State<ActiveVisitScreen> createState() => _ActiveVisitScreenState();
}

class _ActiveVisitScreenState extends State<ActiveVisitScreen> {
  VisitTracking? _tracking;
  bool _loading = false;
  String? _error;
  Position? _currentPosition;

  bool get _visitStarted => _tracking != null && _tracking!.isActive;
  bool get _visitCompleted => _tracking != null && _tracking!.isCompleted;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // Screen se bahar jaen to tracking band mat karo — background mein chalta rahe
    super.dispose();
  }

  Future<void> _init() async {
    // Permission check
    final granted = await LocationService().requestPermission();
    if (!granted && mounted) {
      setState(() { _error = 'Location permission required. Please allow in settings.'; });
      return;
    }

    // Existing visit status check karo
    setState(() { _loading = true; });
    final existing = await ApiService().getVisitStatus(widget.meeting.id);
    final pos = await LocationService().getCurrentPosition();
    setState(() {
      _tracking = existing;
      _currentPosition = pos;
      _loading = false;

      // Agar visit already active hai to tracking resume karo
      if (existing != null && existing.isActive) {
        LocationService().startTracking(widget.meeting.id);
      }
    });
  }

  Future<void> _startVisit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) throw Exception('GPS location nahi mili. Location on karo.');

      final tracking = await ApiService().startVisit(widget.meeting.id, pos.latitude, pos.longitude);
      LocationService().startTracking(widget.meeting.id);

      setState(() { _tracking = tracking; _currentPosition = pos; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _startMeeting() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) throw Exception('GPS location nahi mili. Location on karo.');
      final tracking = await ApiService().startMeeting(widget.meeting.id, pos.latitude, pos.longitude);
      setState(() { _tracking = tracking; _currentPosition = pos; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _endMeeting() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) throw Exception('GPS location nahi mili.');
      final tracking = await ApiService().endMeeting(widget.meeting.id, pos.latitude, pos.longitude);
      setState(() { _tracking = tracking; _currentPosition = pos; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _endVisit() async {
    final confirm = await _showConfirmDialog();
    if (!confirm) return;

    setState(() { _loading = true; _error = null; });
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos == null) throw Exception('GPS location nahi mili.');

      final tracking = await ApiService().endVisit(widget.meeting.id, pos.latitude, pos.longitude);
      LocationService().stopTracking();

      setState(() { _tracking = tracking; _currentPosition = pos; });

      if (mounted) {
        _showCompletionDialog(tracking);
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Visit End?', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Kya aap visit end karna chahte hain?\nTotal KM calculate ho jayega.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('End Visit', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showCompletionDialog(VisitTracking tracking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Visit Complete!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('Total KM', '${tracking.totalKm?.toStringAsFixed(2) ?? "0"} km'),
            _summaryRow('Duration', '${tracking.visitDurationMinutes ?? 0} min'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Visit', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading && _tracking == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDestinationCard(),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  if (_error != null) _buildErrorBanner(),
                  if (!_visitCompleted) _buildActionButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDestinationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha:0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destination', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            widget.meeting.destinationName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.meeting.purpose != null) ...[
            const SizedBox(height: 6),
            Text(widget.meeting.purpose!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(widget.meeting.meetingDate, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              if (widget.meeting.meetingTime != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.access_time, color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(widget.meeting.meetingTime!, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_tracking == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white38),
            SizedBox(width: 10),
            Text('Visit abhi start nahi hua', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_visitCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha:0.3)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Visit Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            _summaryRow('Total KM', '${_tracking!.totalKm?.toStringAsFixed(2) ?? "0"} km'),
            _summaryRow('Duration', '${_tracking!.visitDurationMinutes ?? 0} min'),
          ],
        ),
      );
    }

    // Active visit
    final liveKm = _tracking!.liveKm ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _PulsingDot(),
              SizedBox(width: 8),
              Text('Visit Active — GPS Tracking', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('Live KM', '${liveKm.toStringAsFixed(2)} km'),
          if (_currentPosition != null)
            _summaryRow(
              'Current Location',
              '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha:0.3)),
      ),
      child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
    );
  }

  Widget _buildActionButton() {
    final status = _tracking?.status ?? '';
    final spinner = SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const pad = EdgeInsets.symmetric(vertical: 18);
    const txtStyle = TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold);

    // Step 2: traveling → arrived at client → Start Meeting (blue)
    if (status == 'started') {
      return ElevatedButton.icon(
        onPressed: _loading ? null : _startMeeting,
        icon: _loading ? spinner : const Icon(Icons.people_outline, color: Colors.white),
        label: Text(_loading ? 'Starting...' : 'Start Meeting', style: txtStyle),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          padding: pad, shape: btnShape,
        ),
      );
    }

    // Step 3: meeting in progress → End Meeting (blue)
    if (status == 'meeting_started') {
      return ElevatedButton.icon(
        onPressed: _loading ? null : _endMeeting,
        icon: _loading ? spinner : const Icon(Icons.meeting_room_outlined, color: Colors.white),
        label: Text(_loading ? 'Ending...' : 'End Meeting', style: txtStyle),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          padding: pad, shape: btnShape,
        ),
      );
    }

    // Step 4: meeting done → End Visit (red)
    if (status == 'meeting_ended' || status == 'traveling_next') {
      return ElevatedButton.icon(
        onPressed: _loading ? null : _endVisit,
        icon: _loading ? spinner : const Icon(Icons.stop_circle_outlined, color: Colors.white),
        label: Text(_loading ? 'Ending...' : 'End Visit', style: txtStyle),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: pad, shape: btnShape,
        ),
      );
    }

    // Step 1: not started → Start Visit (green)
    return ElevatedButton.icon(
      onPressed: _loading ? null : _startVisit,
      icon: _loading ? spinner : const Icon(Icons.play_circle_outlined, color: Colors.white),
      label: Text(_loading ? 'Starting...' : 'Start Visit', style: txtStyle),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22C55E),
        padding: pad, shape: btnShape,
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
      ),
    );
  }
}
