class VisitTracking {
  final String id;
  final String meetingRequestId;
  final String userId;
  final String status;
  final double? totalKm;
  final double? liveKm;
  final DateTime? startVisitAt;
  final DateTime? endVisitAt;
  final int? visitDurationMinutes;

  VisitTracking({
    required this.id,
    required this.meetingRequestId,
    required this.userId,
    required this.status,
    this.totalKm,
    this.liveKm,
    this.startVisitAt,
    this.endVisitAt,
    this.visitDurationMinutes,
  });

  bool get isActive => status == 'started' || status == 'meeting_started' || status == 'meeting_ended' || status == 'traveling_next';
  bool get isCompleted => status == 'completed';

  factory VisitTracking.fromJson(Map<String, dynamic> json) {
    return VisitTracking(
      id: json['id'] ?? '',
      meetingRequestId: json['meetingRequestId'] ?? '',
      userId: json['userId'] ?? '',
      status: json['status'] ?? '',
      totalKm: json['totalKm'] != null ? (json['totalKm'] as num).toDouble() : null,
      liveKm: json['liveKm'] != null ? (json['liveKm'] as num).toDouble() : null,
      startVisitAt: json['startVisitAt'] != null ? DateTime.parse(json['startVisitAt']) : null,
      endVisitAt: json['endVisitAt'] != null ? DateTime.parse(json['endVisitAt']) : null,
      visitDurationMinutes: json['visitDurationMinutes'],
    );
  }
}
