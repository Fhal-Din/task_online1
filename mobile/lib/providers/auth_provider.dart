import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../auth/auth_api.dart';
import '../storage.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _client;
  final AppStorage _storage;
  late final AuthApi _authApi;

  String? _token;
  String? _email;
  String? _role;
  bool _isLoading = false;

  AuthProvider({
    required ApiClient client,
    required AppStorage storage,
  })  : _client = client,
        _storage = storage {
    _authApi = AuthApi(_client);
  }

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get email => _email;
  String? get token => _token;
  String? get role => _role;

  Future<void> bootstrap() async {
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      _token = token;
      _client.setToken(token);
      try {
        final me = await _authApi.me();
        _email = me['email'] as String?;
        _role = me['role'] as String?;
      } catch (_) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _authApi.register(email: email, password: password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirm2fa({
    required String email,
    required String password,
    required String otp,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _authApi.confirm2fa(email: email, password: password, otp: otp);
      await _setToken(resp['accessToken'] as String);
      final me = await _authApi.me();
      _email = me['email'] as String?;
      _role = me['role'] as String?;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _authApi.login(email: email, password: password);
      if (resp['accessToken'] is String) {
        await _setToken(resp['accessToken'] as String);
        final me = await _authApi.me();
        _email = me['email'] as String?;
        _role = me['role'] as String?;
      }
      return resp;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String twoFactorToken,
    required String otp,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _authApi.verifyOtp(twoFactorToken: twoFactorToken, otp: otp);
      await _setToken(resp['accessToken'] as String);
      final me = await _authApi.me();
      _email = me['email'] as String?;
      _role = me['role'] as String?;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final acc = await googleSignIn.signIn();
      if (acc == null) {
        return;
      }
      final auth = await acc.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google idToken unavailable');
      }
      final resp = await _authApi.google(idToken: idToken);
      await _setToken(resp['accessToken'] as String);
      final me = await _authApi.me();
      _email = me['email'] as String?;
      _role = me['role'] as String?;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    _role = null;
    _client.setToken(null);
    await _storage.clearToken();
    notifyListeners();
  }

  Future<Map<String, dynamic>> setup2fa() async {
    return _authApi.setup2fa();
  }

  Future<void> enable2fa({required String otp}) async {
    await _authApi.enable2fa(otp: otp);
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final list = await _authApi.listUsers();
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateUserRole({required String userId, required String role}) async {
    await _authApi.updateUserRole(userId: userId, role: role);
  }

  Future<void> _setToken(String token) async {
    _token = token;
    _client.setToken(token);
    await _storage.writeToken(token);
  }
}
