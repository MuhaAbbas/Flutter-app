import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  String? _accessToken;
  User? _currentUser;

  String? get accessToken => _accessToken;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _accessToken != null;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(ApiConfig.login, data: {
        'email': email,
        'password': password,
      });

      final data = response.data['data'];
      _accessToken = data['accessToken'];
      _currentUser = User.fromJson(data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', data['refreshToken'] ?? '');
      // Persist user fields so we can restore without hitting the API on next launch
      await prefs.setString('u_id', _currentUser!.id);
      await prefs.setString('u_email', _currentUser!.email);
      await prefs.setString('u_firstName', _currentUser!.firstName);
      await prefs.setString('u_lastName', _currentUser!.lastName);
      await prefs.setString('u_role', _currentUser!.role);

      return true;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Login failed');
    }
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return false;

    _accessToken = token;

    // Restore user from prefs so routing works immediately without API round-trip
    final savedId = prefs.getString('u_id');
    final savedRole = prefs.getString('u_role');
    if (savedId != null && savedRole != null) {
      _currentUser = User(
        id: savedId,
        email: prefs.getString('u_email') ?? '',
        firstName: prefs.getString('u_firstName') ?? '',
        lastName: prefs.getString('u_lastName') ?? '',
        role: savedRole,
        permissions: [],
      );
    }

    // Try to refresh user from the server (non-blocking on failure)
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get(ApiConfig.me);
      final raw = response.data?['data'] ?? response.data;
      if (raw is Map<String, dynamic>) {
        _currentUser = User.fromJson(raw);
        // Keep saved role in sync
        await prefs.setString('u_role', _currentUser!.role);
        await prefs.setString('u_firstName', _currentUser!.firstName);
        await prefs.setString('u_lastName', _currentUser!.lastName);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await logout();
        return false;
      }
      // Network/timeout — use restored user from prefs
    } catch (_) {
      // Parse error — use restored user from prefs
    }

    return _currentUser != null;
  }

  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('u_id');
    await prefs.remove('u_email');
    await prefs.remove('u_firstName');
    await prefs.remove('u_lastName');
    await prefs.remove('u_role');
  }
}
