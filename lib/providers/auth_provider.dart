import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// スタッフのログイン状態を管理するProvider
/// 自動ログイン(保存したID/PWで再ログイン)にも対応
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; // 起動時の自動ログイン確認中
  String? _staffId;
  String? _staffName;
  String? _loginId;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get staffId => _staffId;
  String? get staffName => _staffName;
  String? get loginId => _loginId;
  String? get errorMessage => _errorMessage;

  /// アプリ起動時に呼び出す:保存済みトークン or ID/PWで自動ログインを試みる
  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(StorageKeys.token);
    final savedRole = prefs.getString(StorageKeys.role);
    final savedLoginId = prefs.getString(StorageKeys.savedLoginId);
    final savedPassword = prefs.getString(StorageKeys.savedPassword);

    // 保存済みトークンがあり、role=staffなら、まず有効性をプロフィール取得で確認
    if (savedToken != null && savedRole == 'staff') {
      ApiService.setToken(savedToken);
      final result = await ApiService.call('staff.getProfile');
      if (result.ok && result.data != null) {
        _isLoggedIn = true;
        _staffId = result.data!['staffId']?.toString();
        _staffName = result.data!['name']?.toString();
        _loginId = result.data!['loginId']?.toString();
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    // トークンが無効・期限切れの場合、保存済みID/PWで再ログイン
    if (savedLoginId != null && savedPassword != null) {
      final success = await login(savedLoginId, savedPassword, remember: true, silent: true);
      if (success) {
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    _isLoading = false;
    _isLoggedIn = false;
    notifyListeners();
  }

  /// ログイン処理
  Future<bool> login(String loginId, String password,
      {bool remember = true, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await ApiService.call(
      'staff.login',
      params: {'loginId': loginId, 'password': password},
      requireAuth: false,
    );

    if (result.ok && result.data != null) {
      final token = result.data!['token']?.toString();
      ApiService.setToken(token);

      _isLoggedIn = true;
      _staffId = result.data!['userId']?.toString();
      _staffName = result.data!['name']?.toString();
      _loginId = result.data!['loginId']?.toString();
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.token, token ?? '');
      await prefs.setString(StorageKeys.role, 'staff');
      if (remember) {
        await prefs.setString(StorageKeys.savedLoginId, loginId);
        await prefs.setString(StorageKeys.savedPassword, password);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.error ?? 'ログインに失敗しました';
      _isLoading = false;
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }

  /// ログアウト(保存情報もすべて削除)
  Future<void> logout() async {
    await ApiService.call('logout', requireAuth: true);
    ApiService.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.role);
    await prefs.remove(StorageKeys.savedLoginId);
    await prefs.remove(StorageKeys.savedPassword);

    _isLoggedIn = false;
    _staffId = null;
    _staffName = null;
    _loginId = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
