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
class ApiService {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  static String? get token => _token;

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

      final response = await http
          .post(
            Uri.parse(ApiConstants.gasWebAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConstants.requestTimeout);

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

      final response = await http
          .post(
            Uri.parse(ApiConstants.gasWebAppUrl),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConstants.requestTimeout);

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
