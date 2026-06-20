class AttendanceRecord {
  final String id;
  final String userId;
  final String date;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? duration;
  final bool isWithinRadius;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.duration,
    required this.isWithinRadius,
  });

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;
  bool get isCheckedOut => checkInTime != null && checkOutTime != null;

  String get checkInTimeStr {
    if (checkInTime == null) return '--:--';
    final t = checkInTime!.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get checkOutTimeStr {
    if (checkOutTime == null) return '--:--';
    final t = checkOutTime!.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get statusLabel {
    switch (status) {
      case 'present': return 'Present';
      case 'late': return 'Late';
      case 'absent': return 'Absent';
      case 'leave': return 'On Leave';
      case 'half_day': return 'Half Day';
      default: return status;
    }
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'absent',
      checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime']) : null,
      checkOutTime: json['checkOutTime'] != null ? DateTime.parse(json['checkOutTime']) : null,
      duration: json['duration'],
      isWithinRadius: json['isWithinRadius'] == 1 || json['isWithinRadius'] == true,
    );
  }
}

class TodayStats {
  final int present;
  final int late;
  final int absent;
  final int onLeave;
  final int total;

  TodayStats({
    required this.present,
    required this.late,
    required this.absent,
    required this.onLeave,
    required this.total,
  });

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    return TodayStats(
      present: json['present'] ?? 0,
      late: json['late'] ?? 0,
      absent: json['absent'] ?? 0,
      onLeave: json['onLeave'] ?? json['leave'] ?? 0,
      total: json['total'] ?? 0,
    );
  }

  factory TodayStats.empty() =>
      TodayStats(present: 0, late: 0, absent: 0, onLeave: 0, total: 0);
}
