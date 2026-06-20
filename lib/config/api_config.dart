class ApiConfig {
  // Backend URL — production mein apna server URL dalein
  static const String baseUrl = 'https://173.212.219.83.nip.io/api/v1';

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String myVisits = '/visits/my/all';

  static String visitStart(String meetingId) => '/visits/$meetingId/start';
  static String visitEnd(String meetingId) => '/visits/$meetingId/end';
  static String visitLocation(String meetingId) => '/visits/$meetingId/location';
  static String visitDetail(String meetingId) => '/visits/$meetingId';

  // GPS ping interval (seconds)
  static const int gpsPingIntervalSeconds = 30;
}
