import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import 'api_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _pingTimer;
  String? _activeMeetingId;

  bool get isTracking => _pingTimer != null && _activeMeetingId != null;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  void startTracking(String meetingId) {
    _activeMeetingId = meetingId;
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      Duration(seconds: ApiConfig.gpsPingIntervalSeconds),
      (_) => _sendPing(),
    );
  }

  void stopTracking() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _activeMeetingId = null;
  }

  Future<void> _sendPing() async {
    if (_activeMeetingId == null) return;
    final pos = await getCurrentPosition();
    if (pos == null) return;
    await ApiService().pingLocation(_activeMeetingId!, pos.latitude, pos.longitude);
  }
}
