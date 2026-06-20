import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/meeting_request.dart';
import '../models/visit_tracking.dart';
import '../models/attendance_record.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio get _dio => Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {
          'Authorization': 'Bearer ${AuthService().accessToken}',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

  // ── VISITS ──────────────────────────────────────────────────────────────────

  Future<List<MeetingRequest>> getMyVisits() async {
    try {
      final response = await _dio.get(ApiConfig.myVisits);
      final List data = response.data['data'] ?? [];
      return data
          .map((e) => MeetingRequest.fromJson(e))
          .where((m) => m.canStart)
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load visits');
    }
  }

  Future<VisitTracking> startVisit(String meetingId, double lat, double lng) async {
    try {
      final response = await _dio.post(ApiConfig.visitStart(meetingId),
          data: {'latitude': lat, 'longitude': lng});
      return VisitTracking.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to start visit');
    }
  }

  Future<VisitTracking> endVisit(String meetingId, double lat, double lng) async {
    try {
      final response = await _dio.post(ApiConfig.visitEnd(meetingId),
          data: {'latitude': lat, 'longitude': lng});
      return VisitTracking.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to end visit');
    }
  }

  Future<void> pingLocation(String meetingId, double lat, double lng) async {
    try {
      await _dio.patch(ApiConfig.visitLocation(meetingId),
          data: {'latitude': lat, 'longitude': lng});
    } catch (_) {}
  }

  Future<VisitTracking?> getVisitStatus(String meetingId) async {
    try {
      final response = await _dio.get(ApiConfig.visitDetail(meetingId));
      final data = response.data['data'];
      if (data == null) return null;
      return VisitTracking.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ── ATTENDANCE (Employee) ────────────────────────────────────────────────────

  Future<AttendanceRecord?> getMyTodayAttendance() async {
    try {
      final response = await _dio.get('/attendance/my/today');
      final data = response.data['data'];
      if (data == null) return null;
      return AttendanceRecord.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<AttendanceRecord> checkIn(double lat, double lng) async {
    try {
      final response = await _dio.post('/attendance/check-in',
          data: {'latitude': lat, 'longitude': lng});
      return AttendanceRecord.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Check-in failed');
    }
  }

  Future<AttendanceRecord> checkOut(double lat, double lng) async {
    try {
      final response = await _dio.post('/attendance/check-out',
          data: {'latitude': lat, 'longitude': lng});
      return AttendanceRecord.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Check-out failed');
    }
  }

  // ── ADMIN / HOD ──────────────────────────────────────────────────────────────

  Future<TodayStats> getTodayStats() async {
    try {
      final response = await _dio.get('/attendance/today/stats');
      final data = response.data['data'];
      if (data == null) return TodayStats.empty();
      return TodayStats.fromJson(data);
    } catch (_) {
      return TodayStats.empty();
    }
  }

  Future<List<Map<String, dynamic>>> getActiveVisits() async {
    try {
      final response = await _dio.get('/visits/active-all');
      final List data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final response = await _dio.get('/users?limit=100');
      final data = response.data['data'];
      final List list = data is List ? data : (data?['users'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAbsentToday() async {
    try {
      final response = await _dio.get('/attendance/today/absent-employees');
      final List data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── DEPARTMENTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final response = await _dio.get('/departments');
      final List data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── ROLES ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _dio.get('/roles');
      final List data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── ATTENDANCE ALL (Admin) ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAttendanceAll({String? from, String? to, String? status}) async {
    try {
      final params = <String, String>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/attendance', queryParameters: params);
      final data = response.data['data'];
      if (data is List) return {'records': data};
      return data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── ATTENDANCE REQUESTS ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAttendanceRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/attendance-requests', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['requests'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> approveAttendanceRequest(String id) async {
    try {
      await _dio.patch('/attendance-requests/$id/approve');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to approve');
    }
  }

  Future<void> rejectAttendanceRequest(String id) async {
    try {
      await _dio.patch('/attendance-requests/$id/reject');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to reject');
    }
  }

  // ── LEAVE REQUESTS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaveRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/leaves', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['leaves'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> approveLeaveRequest(String id) async {
    try {
      await _dio.patch('/leaves/$id/approve');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to approve');
    }
  }

  Future<void> rejectLeaveRequest(String id) async {
    try {
      await _dio.patch('/leaves/$id/reject');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to reject');
    }
  }

  // ── PUBLIC HOLIDAYS ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHolidays({int? year}) async {
    try {
      final params = <String, String>{};
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/holidays', queryParameters: params);
      final List data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> addHoliday(Map<String, dynamic> data) async {
    try {
      await _dio.post('/holidays', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to add holiday');
    }
  }

  Future<void> deleteHoliday(String id) async {
    try {
      await _dio.delete('/holidays/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete');
    }
  }

  // ── EMPLOYEE MANAGEMENT ──────────────────────────────────────────────────────

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/users/$id', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update employee');
    }
  }

  Future<void> deactivateEmployee(String id) async {
    try {
      await _dio.patch('/users/$id/deactivate');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to deactivate');
    }
  }

  Future<void> resetEmployeePassword(String id, String newPassword) async {
    try {
      await _dio.patch('/users/$id/reset-password', data: {'newPassword': newPassword});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to reset password');
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      await _dio.delete('/users/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete employee');
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeTravelHistory(String userId) async {
    try {
      final response = await _dio.get('/visits', queryParameters: {'userId': userId, 'limit': 50});
      final data = response.data['data'];
      final List list = data is List ? data : (data?['visits'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── PROFILE ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> updateMyProfile(Map<String, dynamic> data) async {
    try {
      await _dio.patch('/auth/profile', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update profile');
    }
  }

  Future<void> changeMyPassword(String current, String newPwd, String confirm) async {
    try {
      await _dio.patch('/auth/change-password', data: {
        'currentPassword': current,
        'newPassword': newPwd,
        'confirmPassword': confirm,
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to change password');
    }
  }

  // ── CANCEL MEETING ────────────────────────────────────────────────────────────

  Future<void> cancelMeeting(String id) async {
    try {
      await _dio.patch('/meetings/$id/cancel');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to cancel meeting');
    }
  }

  // ── MEETINGS (Admin) ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMeetingsAll({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/meetings', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['meetings'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── ACTIVITY LOGS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId, String? departmentId, int? month, int? year,
  }) async {
    try {
      final params = <String, String>{};
      if (userId != null && userId != 'all') params['userId'] = userId;
      if (departmentId != null && departmentId != 'all') params['departmentId'] = departmentId;
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/activities', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['activities'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── PAYROLL ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPayroll({
    String? userId, int? month, int? year, String? status,
  }) async {
    try {
      final params = <String, String>{};
      if (userId != null && userId != 'all') params['userId'] = userId;
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/payroll', queryParameters: params);
      final data = response.data['data'];
      if (data is List) return {'records': data, 'stats': {}};
      return data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> runPayroll({int? month, int? year, String? userId}) async {
    try {
      final body = <String, dynamic>{};
      if (month != null) body['month'] = month;
      if (year != null) body['year'] = year;
      if (userId != null) body['userId'] = userId;
      await _dio.post('/payroll/run', data: body);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to run payroll');
    }
  }

  Future<void> approvePayroll(String id) async {
    try {
      await _dio.patch('/payroll/$id/approve');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to approve');
    }
  }

  Future<void> rejectPayroll(String id) async {
    try {
      await _dio.patch('/payroll/$id/reject');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to reject');
    }
  }

  Future<void> updatePayrollKm(String id, double totalKm, double perKmRate) async {
    try {
      await _dio.patch('/payroll/$id/km', data: {'totalKm': totalKm, 'perKmRate': perKmRate});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update KM');
    }
  }

  Future<Map<String, dynamic>> getPayslip(String id) async {
    try {
      final response = await _dio.get('/payroll/$id/payslip');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  String getPayslipPdfUrl(String id) =>
      '${ApiConfig.baseUrl}/payroll/$id/pdf';

  // ── SALARY SETUP ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSalarySetups({String? search}) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      final response = await _dio.get('/salary-setup', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['setups'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getSalarySetupByUser(String userId) async {
    try {
      final response = await _dio.get('/salary-setup/$userId');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSalarySetup(String userId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/salary-setup/$userId', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to save salary setup');
    }
  }

  Future<void> deleteSalarySetup(String id) async {
    try {
      await _dio.delete('/salary-setup/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete');
    }
  }

  // ── NOTIFICATIONS ─────────────────────────────────────────────────────────────

  Future<void> sendNotification(Map<String, dynamic> data) async {
    try {
      await _dio.post('/notifications', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to send notification');
    }
  }

  Future<List<Map<String, dynamic>>> getSentNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      final data = response.data['data'];
      final List list = data is List ? data : (data?['notifications'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── EMPLOYEE SELF-SERVICE ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyMonthlyStats({int? month, int? year}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/attendance/my/stats', queryParameters: params);
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getMyAttendanceHistory({int? month, int? year}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/attendance/my', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['records'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> submitAttendanceRequest(Map<String, dynamic> data) async {
    try {
      await _dio.post('/attendance-requests', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to submit request');
    }
  }

  Future<List<Map<String, dynamic>>> getMyAttendanceRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/attendance-requests/my', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['requests'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    try {
      await _dio.post('/leaves', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to submit leave request');
    }
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/leaves/my', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['leaves'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> submitVisitRequest(Map<String, dynamic> data) async {
    try {
      await _dio.post('/meetings', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to submit visit request');
    }
  }

  Future<List<Map<String, dynamic>>> getMyMeetings({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/meetings/my', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['meetings'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyActivityLogs({int? month, int? year}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/activities/my', queryParameters: params);
      final data = response.data['data'];
      final List list = data is List ? data : (data?['activities'] ?? data?['items'] ?? []);
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> submitActivityLog(Map<String, dynamic> data) async {
    try {
      await _dio.post('/activities', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to submit activity log');
    }
  }

  // ── SETTINGS ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _dio.get('/settings');
      return response.data['data'] ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    try {
      await _dio.patch('/settings', data: data);
    } catch (_) {}
  }
}
