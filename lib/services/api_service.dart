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
/// Google Apps Script の Web App (doPost) は、レスポンスを直接返さず、
/// 必ず一度 302 リダイレクトを返し、実際のレスポンス本文は
/// リダイレクト先の script.googleusercontent.com への GET リクエストで
/// 取得する必要がある仕組みになっている。
/// Dartの http パッケージは、安全性の観点から POST リクエストに対する
/// 301/302/303 リダイレクトを自動追従しないため、
/// ここで明示的にリダイレクトを追従する処理を実装している。
class ApiService {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? get token => _token;

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
        {'Content-Type': 'application/json'},
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
        return ApiResult.failure(
          json['error']?.toString() ?? '不明なエラーが発生しました',
          json['code']?.toString(),
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
        {'Content-Type': 'application/json'},
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
        return ApiResult.failure(
          json['error']?.toString() ?? '不明なエラーが発生しました',
          json['code']?.toString(),
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
