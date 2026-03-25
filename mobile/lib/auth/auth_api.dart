import '../api/api_client.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final obj = await _client.postJson('/auth/register', {
      'email': email,
      'password': password,
    });
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirm2fa({
    required String email,
    required String password,
    required String otp,
  }) async {
    final obj = await _client.postJson('/auth/2fa/confirm', {
      'email': email,
      'password': password,
      'otp': otp,
    });
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final obj = await _client.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String twoFactorToken,
    required String otp,
  }) async {
    final obj = await _client.postJson('/auth/login/verify-otp', {
      'twoFactorToken': twoFactorToken,
      'otp': otp,
    });
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final obj = await _client.getJson('/auth/me');
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setup2fa() async {
    final obj = await _client.postJson('/auth/2fa/setup', {});
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enable2fa({required String otp}) async {
    final obj = await _client.postJson('/auth/2fa/enable', {'otp': otp});
    return obj as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> google({required String idToken}) async {
    final obj = await _client.postJson('/auth/google', {'idToken': idToken});
    return obj as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final obj = await _client.getJson('/auth/users');
    final list = obj as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> updateUserRole({required String userId, required String role}) async {
    await _client.putJson('/auth/users/$userId/role', {'role': role});
  }
}
