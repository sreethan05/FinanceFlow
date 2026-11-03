import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class FinanceApi {
  FinanceApi._(this._dio, this._cookieJar);

  final Dio _dio;
  final CookieJar _cookieJar;

  static FinanceApi create({required String cookieDirectory}) {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    final baseUrl = configuredUrl.isEmpty
        ? 'http://10.0.2.2:3000'
        : configuredUrl;
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ));
    final cookieJar = PersistCookieJar(storage: FileStorage(cookieDirectory));
    dio.interceptors.add(CookieManager(cookieJar));
    return FinanceApi._(dio, cookieJar);
  }

  Future<bool> get hasSession async {
    final cookies = await _cookieJar.loadForRequest(Uri.parse(_dio.options.baseUrl));
    if (!cookies.any((cookie) => cookie.name.contains('session-token'))) return false;
    final response = await _dio.get<dynamic>('/api/auth/session');
    return response.statusCode == 200 && response.data is Map && (response.data as Map)['user'] is Map;
  }

  Future<void> login(String email, String password) async {
    final csrf = await _dio.get<Map<String, dynamic>>('/api/auth/csrf');
    final csrfToken = csrf.data?['csrfToken'] as String?;
    if (csrf.statusCode != 200 || csrfToken == null) {
      throw const FinanceApiException('Could not start secure sign in.');
    }

    final result = await _dio.post<dynamic>(
      '/api/auth/callback/credentials',
      data: {
        'csrfToken': csrfToken,
        'email': email.trim().toLowerCase(),
        'password': password,
        'callbackUrl': '/',
        'json': 'true',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    if (result.statusCode == null || result.statusCode! >= 400 || !await hasSession) {
      throw const FinanceApiException('Email or password is incorrect.');
    }
  }

  Future<void> register({required String name, required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/auth/register', data: {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    _check(response);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/analytics');
    _check(response);
    return _asMap(response.data?['data']);
  }

  Future<List<Map<String, dynamic>>> transactions() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/transactions', queryParameters: {'pageSize': 50});
    _check(response);
    final rows = response.data?['data'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> categories({String? type}) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/categories',
        queryParameters: type == null ? null : {'type': type});
    _check(response);
    final rows = response.data?['data'];
    if (rows is! List) return const [];
    final data = rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    return type == null ? data : data.where((category) => category['type'] == type).toList();
  }

  Future<void> createTransaction({
    required String amount,
    required String type,
    required String categoryId,
    required String description,
    required DateTime date,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/transactions', data: {
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'description': description.trim(),
      'transactionDate': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    _check(response);
  }

  Future<List<Map<String, dynamic>>> budgets() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/budgets');
    _check(response);
    final rows = response.data?['data'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> savingsGoals() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/savings');
    _check(response);
    final rows = response.data?['data'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> logout() async {
    try {
      final csrf = await _dio.get<Map<String, dynamic>>('/api/auth/csrf');
      final csrfToken = csrf.data?['csrfToken'];
      if (csrfToken is String) {
        await _dio.post<dynamic>('/api/auth/signout', data: {
          'csrfToken': csrfToken,
          'callbackUrl': '/login',
          'json': 'true',
        }, options: Options(contentType: Headers.formUrlEncodedContentType));
      }
    } finally {
      await _cookieJar.deleteAll();
    }
  }

  void _check(Response<dynamic> response) {
    if ((response.statusCode ?? 500) < 400) return;
    final body = response.data;
    final message = body is Map && body['error'] is Map
        ? (body['error'] as Map)['message']
        : null;
    throw FinanceApiException(message is String ? message : 'Request failed. Please try again.');
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

class FinanceApiException implements Exception {
  const FinanceApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
