import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exceptions.dart';
import 'config.dart';
import '../models/app_user.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._prefs, this._dio);

  static const _kAccess = 'auth_access_token';
  static const _kUser = 'auth_user_json';
  static const _kSessionStarted = 'auth_session_started_ms';

  static const _authWithPassword =
      '/collections/$usersCollection/auth-with-password';
  static const _authRefresh = '/collections/$usersCollection/auth-refresh';
  static const _records = '/collections/$usersCollection/records';

  final SharedPreferences _prefs;
  final Dio _dio;

  AppUser? _user;
  String? _accessToken;
  bool _restoring = false;
  DateTime? _sessionStartedAt;
  DateTime _lastActivityAt = DateTime.now();
  bool _loggingOut = false;

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null;
  bool get isRestoring => _restoring;
  DateTime? get sessionStartedAt => _sessionStartedAt;
  DateTime get lastActivityAt => _lastActivityAt;

  bool has(UserRole role) => _user != null && _user!.role.level >= role.level;

  void seedForTest(AppUser user, {String accessToken = 'test-token'}) {
    _user = user;
    _accessToken = accessToken;
    _sessionStartedAt = DateTime.now();
    _lastActivityAt = DateTime.now();
    notifyListeners();
  }

  void touchActivity() {
    if (!isAuthenticated) return;
    _lastActivityAt = DateTime.now();
  }

  Future<void> spoofUiRole(UserRole role) async {
    final current = _user;
    if (current == null) return;
    _user = current.copyWith(role: role);
    await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<bool> reloadUserFromLocalStorage() async {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return false;
    try {
      _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  //восстановление сессии после перезагрузки страницы.
  Future<void> restore() async {
    _restoring = true;
    notifyListeners();
    try {
      final access = _prefs.getString(_kAccess);
      if (access == null || access.isEmpty) return;

      _accessToken = access;
      _sessionStartedAt = _readSessionStarted() ?? DateTime.now();
      _lastActivityAt = DateTime.now();

      final cached = _prefs.getString(_kUser);
      if (cached != null && cached.isNotEmpty) {
        try {
          _user = AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {}
      }

      try {
        await refreshTokens();
      } on UnauthorizedException {
        await logout(reason: 'токен недействителен');
      } catch (_) {}
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    await guard(() async {
      final response = await _dio.post(
        _authWithPassword,
        data: {'identity': email.trim(), 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      await _applyAuthPayload(data, startNewSession: true);
    });
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await guard(() async {
      await _dio.post(
        _records,
        data: {
          'email': email.trim(),
          'password': password,
          'passwordConfirm': password,
          'fullName': fullName.trim(),
          'role': UserRole.client.apiValue,
          'emailVisibility': true,
        },
      );
    });
  }

  Future<void> logout({String? reason}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    _user = null;
    _accessToken = null;
    _sessionStartedAt = null;
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kSessionStarted);
    notifyListeners();
    _loggingOut = false;
    if (reason != null && kDebugMode) {
      debugPrint('[Auth] выход: $reason');
    }
  }

  Future<void> refreshOrLogin(Dio dio) => refreshTokens(client: dio);

  Future<void> refreshTokens({Dio? client}) async {
    final current = _accessToken ?? _prefs.getString(_kAccess);
    if (current == null || current.isEmpty) {
      throw const UnauthorizedException('Сессия истекла. Войдите снова.');
    }
    final http = client ?? _dio;
    await guard(() async {
      final response = await http.post(
        _authRefresh,
        options: Options(headers: {'Authorization': current}),
      );
      final data = response.data as Map<String, dynamic>;
      await _applyAuthPayload(data, startNewSession: false);
    });
    notifyListeners();
  }

  Future<void> _applyAuthPayload(
    Map<String, dynamic> data, {
    required bool startNewSession,
  }) async {
    _accessToken = data['token'] as String?;
    final record = data['record'];
    if (record is Map<String, dynamic>) {
      _user = AppUser.fromJson(record);
    }
    if (_accessToken != null) {
      await _prefs.setString(_kAccess, _accessToken!);
    }
    if (_user != null) {
      await _prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    }
    if (startNewSession || _sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      await _prefs.setInt(
        _kSessionStarted,
        _sessionStartedAt!.millisecondsSinceEpoch,
      );
    }
    _lastActivityAt = DateTime.now();
  }

  DateTime? _readSessionStarted() {
    final ms = _prefs.getInt(_kSessionStarted);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

typedef AuthSession = AuthNotifier;
