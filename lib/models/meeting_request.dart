class MeetingRequest {
  final String id;
  final String userId;
  final String destinationName;
  final double destinationLatitude;
  final double destinationLongitude;
  final String meetingDate;
  final String? meetingTime;
  final String? purpose;
  final double distanceKm;
  final String status;
  final String planType;

  MeetingRequest({
    required this.id,
    required this.userId,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.meetingDate,
    this.meetingTime,
    this.purpose,
    required this.distanceKm,
    required this.status,
    required this.planType,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get canStart => isApproved || isPending;

  factory MeetingRequest.fromJson(Map<String, dynamic> json) {
    return MeetingRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      destinationName: json['destinationName'] ?? json['destinationLocationId'] ?? 'Visit',
      destinationLatitude: (json['destinationLatitude'] ?? 0).toDouble(),
      destinationLongitude: (json['destinationLongitude'] ?? 0).toDouble(),
      meetingDate: json['meetingDate'] ?? '',
      meetingTime: json['meetingTime'],
      purpose: json['purpose'],
      distanceKm: (json['distanceKm'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      planType: json['planType'] ?? 'scheduled',
    );
  }
}
