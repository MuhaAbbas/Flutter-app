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

  // ── Response parsing helpers ─────────────────────────────────────────────────

  // Unwraps {data: ...} or returns raw if no wrapper
  dynamic _d(dynamic raw) {
    if (raw is! Map) return raw;
    return raw['data'] ?? raw;
  }

  // Extracts a List from wrapped/unwrapped response trying multiple key names
  List<Map<String, dynamic>> _list(dynamic raw, List<String> keys) {
    final d = _d(raw);
    if (d is List) {
      try { return d.cast<Map<String, dynamic>>(); } catch (_) { return []; }
    }
    if (d is Map) {
      for (final k in keys) {
        final v = d[k];
        if (v is List) {
          try { return v.cast<Map<String, dynamic>>(); } catch (_) {}
        }
      }
      // Last resort: any non-empty List value in the map
      for (final v in d.values) {
        if (v is List && v.isNotEmpty) {
          try { return v.cast<Map<String, dynamic>>(); } catch (_) {}
        }
      }
    }
    return [];
  }

  // Clean error message from DioException or generic exception
  String _err(dynamic e) {
    if (e is DioException) {
      return e.response?.data?['message']?.toString()
          ?? e.response?.data?['error']?.toString()
          ?? 'HTTP ${e.response?.statusCode ?? 'error'}';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

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

  Future<VisitTracking> startMeeting(String meetingId, double lat, double lng) async {
    final response = await _dio.post(ApiConfig.visitMeetingStart(meetingId),
        data: {'latitude': lat, 'longitude': lng});
    return VisitTracking.fromJson(response.data['data'] ?? response.data);
  }

  Future<VisitTracking> endMeeting(String meetingId, double lat, double lng) async {
    final response = await _dio.post(ApiConfig.visitMeetingEnd(meetingId),
        data: {'latitude': lat, 'longitude': lng});
    return VisitTracking.fromJson(response.data['data'] ?? response.data);
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
      final response = await _dio.get('/users', queryParameters: {'limit': 200, 'page': 1});
      final result = _list(response.data,
          ['users', 'employees', 'items', 'members', 'records', 'data', 'rows', 'results', 'list']);
      if (result.isEmpty) {
        // Surface the raw response structure so we know which key to add
        final raw = response.data;
        final hint = raw is Map ? 'keys=${(raw as Map).keys.toList()}'
            : 'type=${raw.runtimeType}';
        throw Exception('No employees found. Response: $hint');
      }
      return result;
    } catch (e) {
      throw Exception('${_err(e)}');
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
      final result = _list(response.data,
          ['departments', 'items', 'records', 'data', 'rows', 'results', 'list']);
      if (result.isEmpty) {
        final raw = response.data;
        final hint = raw is Map ? 'keys=${(raw as Map).keys.toList()}'
            : 'type=${raw.runtimeType}';
        throw Exception('No departments found. Response: $hint');
      }
      return result;
    } catch (e) {
      throw Exception('${_err(e)}');
    }
  }

  Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/departments/$id', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update department');
    }
  }

  Future<void> createDepartment(Map<String, dynamic> data) async {
    try {
      await _dio.post('/departments', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create department');
    }
  }

  Future<void> deleteDepartment(String id) async {
    try {
      await _dio.delete('/departments/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete department');
    }
  }

  // ── ROLES ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _dio.get('/roles');
      return _list(response.data, ['roles', 'items', 'records']);
    } catch (_) {
      return [];
    }
  }

  // ── EMPLOYEE CRUD ────────────────────────────────────────────────────────────

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/users/$id', data: data);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update employee');
    }
  }

  Future<void> deleteEmployee(String id) async {
    try {
      await _dio.delete('/users/$id');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete employee');
    }
  }

  Future<void> setEmployeeActive(String id, bool active) async {
    try {
      await _dio.patch('/users/$id', data: {'isActive': active});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update status');
    }
  }

  Future<void> resetEmployeePassword(String id, String newPassword) async {
    // Try PATCH /users/:id with password field (most common admin override pattern)
    try {
      await _dio.patch('/users/$id', data: {'password': newPassword});
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404 && e.response?.statusCode != 422) {
        throw Exception(e.response?.data?['message'] ?? 'Failed to change password');
      }
    }
    // Fallback: dedicated set-password endpoint
    try {
      await _dio.post('/users/$id/set-password', data: {'password': newPassword});
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        throw Exception(e.response?.data?['message'] ?? 'Failed to change password');
      }
    }
    // Fallback: change-password endpoint
    try {
      await _dio.patch('/users/$id/change-password', data: {'newPassword': newPassword});
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to change password');
    }
  }

  // ── ATTENDANCE ALL (Admin) ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAttendanceAll({String? from, String? to, String? status}) async {
    final params = <String, dynamic>{};
    // Send multiple param name variants so the server picks what it understands
    if (from != null) { params['from'] = from; params['startDate'] = from; params['date'] = from; }
    if (to != null)   { params['to'] = to;   params['endDate'] = to; }
    if (status != null && status != 'all') params['status'] = status;
    final response = await _dio.get('/attendance', queryParameters: params);
    final d = _d(response.data);
    if (d is List) return {'records': d.cast<Map<String, dynamic>>(), 'stats': {}};
    if (d is Map) {
      final records = d['records'] ?? d['attendance'] ?? d['data'] ?? d['items'] ?? [];
      return {
        'records': records is List ? records.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[],
        'stats':   d['stats'] ?? d['summary'] ?? {},
      };
    }
    return {'records': <Map<String, dynamic>>[], 'stats': {}};
  }

  // ── ATTENDANCE REQUESTS ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAttendanceRequests({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null && status != 'all') params['status'] = status;
      final response = await _dio.get('/attendance-requests', queryParameters: params);
      return _list(response.data, ['requests', 'attendanceRequests', 'items', 'records']);
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
      return _list(response.data, ['leaves', 'leaveRequests', 'items', 'records']);
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
      return _list(response.data, ['meetings', 'requests', 'items', 'records', 'data']);
    } catch (e) {
      throw Exception('Failed to load meetings: ${_err(e)}');
    }
  }

  // ── ACTIVITY LOGS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId, String? departmentId, int? month, int? year,
  }) async {
    try {
      return await getActivityLogsWithError(
        userId: userId, departmentId: departmentId, month: month, year: year);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActivityLogsWithError({
    String? userId, String? departmentId, int? month, int? year,
  }) async {
    final params = <String, dynamic>{};
    if (userId != null && userId != 'all') params['userId'] = userId;
    if (departmentId != null && departmentId != 'all') { params['department'] = departmentId; params['departmentId'] = departmentId; }
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    final response = await _dio.get('/activities', queryParameters: params);
    return _list(response.data, ['activities', 'activityLogs', 'logs', 'items', 'records']);
  }

  // ── PAYROLL ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPayroll({
    String? userId, int? month, int? year, String? status,
  }) async {
    final params = <String, dynamic>{};
    if (userId != null && userId != 'all') params['userId'] = userId;
    if (month != null) params['month'] = month.toString();
    if (year != null) params['year'] = year.toString();
    if (status != null && status != 'all') params['status'] = status;
    final response = await _dio.get('/payroll', queryParameters: params);
    final d = _d(response.data);
    if (d is List) return {'records': d.cast<Map<String, dynamic>>(), 'stats': {}};
    if (d is Map) {
      final records = d['records'] ?? d['payrolls'] ?? d['data'] ?? d['items'] ?? [];
      return {
        'records': records is List ? records.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[],
        'stats':   d['stats'] ?? d['summary'] ?? {},
      };
    }
    return {'records': <Map<String, dynamic>>[], 'stats': {}};
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
      return await getSalarySetupsWithError(search: search);
    } catch (_) {
      return [];
    }
  }

  // Tries every plausible salary endpoint; stops at first 200, throws on last 404.
  // When found, caches the working path so subsequent calls skip the probe loop.
  static String? _salaryEndpoint;

  Future<List<Map<String, dynamic>>> getSalarySetupsWithError({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;

    final endpoints = _salaryEndpoint != null
        ? [_salaryEndpoint!]
        : [
            '/salary-setups',
            '/salary-setup',
            '/salaries/setup',
            '/salary',
            '/salaries',
            '/payroll/setup',
            '/payroll-setup',
            '/salary-structures',
            '/employee-salaries',
            '/payroll/salary-setup',
          ];

    dynamic lastErr;
    for (final ep in endpoints) {
      try {
        final response = await _dio.get(ep, queryParameters: params);
        _salaryEndpoint = ep; // cache working endpoint
        return _list(response.data,
            ['setups', 'salarySetups', 'salaries', 'items', 'records', 'data', 'structures']);
      } catch (e) {
        lastErr = e;
        if (e is DioException) {
          final s = e.response?.statusCode ?? 0;
          // 404 = wrong path, 401/403 = not applicable endpoint — skip and try next
          if (s == 404 || s == 401 || s == 403) continue;
          rethrow;
        }
      }
    }
    throw Exception(
        'Salary setup not available on this server (all endpoints returned 404). '
        'Please check with your backend developer which route to use.');
  }

  Future<Map<String, dynamic>> getSalarySetupByUser(String userId) async {
    final base = _salaryEndpoint ?? '/salary-setup';
    try {
      final response = await _dio.get('$base/$userId');
      final d = _d(response.data);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSalarySetup(String userId, Map<String, dynamic> data) async {
    final base = _salaryEndpoint ?? '/salary-setup';
    try {
      // POST to base (creates) or PATCH to base/userId (updates)
      try {
        await _dio.patch('$base/$userId', data: data);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await _dio.post(base, data: {...data, 'userId': userId});
        } else rethrow;
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to save salary setup');
    }
  }

  Future<void> deleteSalarySetup(String id) async {
    final base = _salaryEndpoint ?? '/salary-setup';
    try {
      await _dio.delete('$base/$id');
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

  Future<Map<String, dynamic>> getMyLiveFines({required String month}) async {
    try {
      final response = await _dio.get('/payroll/me/live-fines', queryParameters: {'month': month});
      final data = response.data['data'];
      return data is Map<String, dynamic> ? data : {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getMyAttendanceHistory({int? month, int? year}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month.toString();
      if (year != null) params['year'] = year.toString();
      final response = await _dio.get('/attendance/my', queryParameters: params);
      final data = response.data['data'];
      final List recordList = data is List ? data : (data?['records'] ?? data?['items'] ?? []);
      final List holidayList = data is Map ? (data['publicHolidayDates'] ?? []) : [];
      final Map<String, dynamic> summary = data is Map ? (data['summary'] ?? {}) as Map<String, dynamic> : {};
      return {
        'records': recordList.cast<Map<String, dynamic>>(),
        'publicHolidayDates': holidayList.cast<String>(),
        'summary': summary,
      };
    } catch (_) {
      return {'records': <Map<String, dynamic>>[], 'publicHolidayDates': <String>[], 'summary': <String, dynamic>{}};
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
