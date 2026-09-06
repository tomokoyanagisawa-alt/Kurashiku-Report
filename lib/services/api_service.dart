import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// API呼び出し結果を表すラッパークラス
class ApiResult<T> {
  final bool ok;
  final T? data;
  final String? error;
  final String? code;

  ApiResult.success(this.data)
      : ok = true,
        error = null,
        code = null;

  ApiResult.failure(this.error, this.code)
      : ok = false,
        data = null;
}

/// Google Apps Script Web App と通信する共通サービス
///
/// すべてのAPIは POST で以下の形式のJSONを送信する:
/// { "action": "staff.login", "token": "...", "params": {...} }
///
/// ⚠️ 重要な注意事項:
/// 1) Google Apps Script の Web App (doPost) は、レスポンスを直接返さず、
///    必ず一度 302 リダイレクトを返し、実際のレスポンス本文は
///    リダイレクト先の script.googleusercontent.com への GET リクエストで
///    取得する必要がある仕組みになっている。
///    Dartの http パッケージ(dart:io実装/Android等)は、安全性の観点から
///    POST リクエストに対する 301/302/303 リダイレクトを自動追従しないため、
///    ここで明示的にリダイレクトを追従する処理を実装している。
/// 2) Web(ブラウザ)環境では、Content-Type: application/json を付けると
///    ブラウザが「非シンプルリクエスト」と判断してCORSプリフライト
///    (OPTIONSメソッド)を自動送信するが、GASはOPTIONSリクエストに
///    対応していないため、ブラウザ側でCORSエラーとしてブロックされ、
///    "ネットワークエラー"になってしまう。
///    これを避けるため、Content-Type は "text/plain;charset=utf-8" を
///    使用する(GAS側は postData.contents を単純にJSON.parseしているため、
///    Content-Typeが何であっても問題なく処理できる)。
class ApiService {
  static String? _token;

  // パスワード変更等によりサーバー側でセッションが強制的に無効化された(SESSION_EXPIRED)
  // ことを検知した際に呼び出されるコールバック。main.dart 側で登録し、
  // アプリ内のどの画面からでもログイン画面へ強制的に戻す処理を行う。
  static void Function()? onSessionExpired;

  // 同じセッション切れを何度も通知して多重にログイン画面へ遷移させないためのフラグ。
  // 新しいトークンがセットされた(再ログインした)タイミングでリセットする。
  static bool _sessionExpiredNotified = false;

  static void setToken(String? token) {
    _token = token;
    if (token != null) {
      _sessionExpiredNotified = false;
    }
  }

  static String? get token => _token;

  static void _notifySessionExpiredIfNeeded(String? code) {
    if (code == 'SESSION_EXPIRED' && !_sessionExpiredNotified) {
      _sessionExpiredNotified = true;
      onSessionExpired?.call();
    }
  }

  /// POSTでリクエストし、302リダイレクトが返ってきた場合は
  /// Location先へGETリクエストして最終的なレスポンスを取得する
  static Future<http.Response> _postFollowingRedirect(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final client = http.Client();
    try {
      var response = await client
          .post(uri, headers: headers, body: body)
          .timeout(ApiConstants.requestTimeout);

      int redirectCount = 0;
      while ((response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303) &&
          redirectCount < 5) {
        final location = response.headers['location'];
        if (location == null || location.isEmpty) break;
        response = await client
            .get(Uri.parse(location))
            .timeout(ApiConstants.requestTimeout);
        redirectCount++;
      }
      return response;
    } finally {
      client.close();
    }
  }

  /// GASにactionとparamsを送信し、レスポンスをMapとして返す
  static Future<ApiResult<Map<String, dynamic>>> call(
    String action, {
    Map<String, dynamic> params = const {},
    bool requireAuth = true,
  }) async {
    try {
      final body = jsonEncode({
        'action': action,
        'token': requireAuth ? _token : null,
        'params': params,
      });

      final response = await _postFollowingRedirect(
        Uri.parse(ApiConstants.gasWebAppUrl),
        {'Content-Type': 'text/plain;charset=utf-8'},
        body,
      );

      if (response.statusCode != 200) {
        return ApiResult.failure(
          'サーバーとの通信でエラーが発生しました(${response.statusCode})',
          'HTTP_ERROR',
        );
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['ok'] == true) {
        return ApiResult.success(json['data'] as Map<String, dynamic>?);
      } else {
        final code = json['code']?.toString();
        _notifySessionExpiredIfNeeded(code);
        return ApiResult.failure(
          json['error']?.toString() ?? '不明なエラーが発生しました',
          code,
        );
      }
    } on FormatException {
      return ApiResult.failure(
        'サーバーからの応答が正しくありません。URLの設定を確認してください',
        'PARSE_ERROR',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API call error: $e');
      }
      return ApiResult.failure(
        'ネットワークエラーが発生しました。通信環境を確認してください',
        'NETWORK_ERROR',
      );
    }
  }

  /// リストデータを期待するAPI呼び出し(dataがList形式で返る場合)
  static Future<ApiResult<List<dynamic>>> callList(
    String action, {
    Map<String, dynamic> params = const {},
    bool requireAuth = true,
  }) async {
    try {
      final body = jsonEncode({
        'action': action,
        'token': requireAuth ? _token : null,
        'params': params,
      });

      final response = await _postFollowingRedirect(
        Uri.parse(ApiConstants.gasWebAppUrl),
        {'Content-Type': 'text/plain;charset=utf-8'},
        body,
      );

      if (response.statusCode != 200) {
        return ApiResult.failure(
          'サーバーとの通信でエラーが発生しました(${response.statusCode})',
          'HTTP_ERROR',
        );
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['ok'] == true) {
        return ApiResult.success(json['data'] as List<dynamic>? ?? []);
      } else {
        final code = json['code']?.toString();
        _notifySessionExpiredIfNeeded(code);
        return ApiResult.failure(
          json['error']?.toString() ?? '不明なエラーが発生しました',
          code,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('API call error: $e');
      }
      return ApiResult.failure(
        'ネットワークエラーが発生しました。通信環境を確認してください',
        'NETWORK_ERROR',
      );
    }
  }
}
