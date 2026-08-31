/// アプリ全体で使う定数
///
/// ⚠️ 重要: GAS_WEB_APP_URL は、Google Apps Scriptを
/// 「ウェブアプリとしてデプロイ」した後に発行されるURLに置き換えてください。
/// デプロイ手順は SETUP_GUIDE.md を参照してください。
class ApiConstants {
  static const String gasWebAppUrl =
      'https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec';

  static const Duration requestTimeout = Duration(seconds: 20);
}

class StorageKeys {
  static const String token = 'auth_token';
  static const String role = 'auth_role';
  static const String userId = 'auth_user_id';
  static const String userName = 'auth_user_name';
  static const String loginId = 'auth_login_id';
  static const String savedLoginId = 'saved_login_id';
  static const String savedPassword = 'saved_password';
}

class AppColors {
  static const int primaryValue = 0xFF4A86E8;
}
