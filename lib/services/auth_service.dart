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
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get(ApiConfig.me);
      final data = response.data?['data'] ?? response.data;
      if (data is Map<String, dynamic>) {
        _currentUser = User.fromJson(data);
      }
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only clear token on explicit auth rejection; network/timeout keeps session alive
      if (status == 401 || status == 403) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      // Parse error or other — keep token, proceed as logged in
      return true;
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}
