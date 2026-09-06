import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/work_log_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

// アプリ全体でナビゲーションを行うためのグローバルキー。
// パスワード変更等によるセッション強制終了(SESSION_EXPIRED)を検知した際に、
// 画面のどこにいても Navigator にアクセスしてログイン画面へ強制的に戻すために使用する。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja_JP');
  runApp(const KurashikuReportApp());
}

class KurashikuReportApp extends StatefulWidget {
  const KurashikuReportApp({super.key});

  @override
  State<KurashikuReportApp> createState() => _KurashikuReportAppState();
}

class _KurashikuReportAppState extends State<KurashikuReportApp> {
  final AuthProvider _authProvider = AuthProvider();

  @override
  void initState() {
    super.initState();
    // パスワード変更等によりサーバー側でセッションが強制的に無効化された場合、
    // どの画面を表示中でも即座にログイン画面へ強制的に戻す。
    ApiService.onSessionExpired = _handleSessionExpired;
  }

  void _handleSessionExpired() {
    // アプリ起動直後の自動ログイン確認(SplashScreen)中に無効なトークンが検出された場合は、
    // SplashScreen 自身が既にログイン画面への遷移を行うため、ここでは何もしない
    // (二重に画面遷移してしまうのを防ぐ)。
    if (_authProvider.isRestoring) return;

    // ローカルの保存トークン・保存ID/PW・ログイン状態をクリア
    // (サーバー側は既に無効化済みなので logout API は呼ばない)。
    _authProvider.forceLogoutLocally();

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          sessionExpiredMessage: 'パスワードが変更されたため、ログアウトされました。再度ログインしてください',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4A86E8);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'くらしくレポート',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
