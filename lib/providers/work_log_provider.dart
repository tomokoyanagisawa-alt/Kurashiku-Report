import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/station_route.dart';
import '../models/work_log.dart';
import '../services/api_service.dart';

class WorkLogProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<StationRoute> _stationRoutes = [];
  List<WorkLog> _myWorkLogs = [];

  bool _isLoadingCustomers = false;
  bool _isLoadingRoutes = false;
  bool _isLoadingLogs = false;
  String? _errorMessage;

  List<Customer> get customers => _customers;
  List<StationRoute> get stationRoutes => _stationRoutes;
  List<WorkLog> get myWorkLogs => _myWorkLogs;
  bool get isLoadingCustomers => _isLoadingCustomers;
  bool get isLoadingRoutes => _isLoadingRoutes;
  bool get isLoadingLogs => _isLoadingLogs;
  String? get errorMessage => _errorMessage;

  Future<void> loadCustomers() async {
    _isLoadingCustomers = true;
    notifyListeners();
    final result = await ApiService.callList('staff.getCustomers');
    if (result.ok && result.data != null) {
      _customers = result.data!
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _errorMessage = result.error;
    }
    _isLoadingCustomers = false;
    notifyListeners();
  }

  Future<void> loadStationRoutes() async {
    _isLoadingRoutes = true;
    notifyListeners();
    final result = await ApiService.callList('staff.getStationRoutes');
    if (result.ok && result.data != null) {
      _stationRoutes = result.data!
          .map((e) => StationRoute.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _errorMessage = result.error;
    }
    _isLoadingRoutes = false;
    notifyListeners();
  }

  /// [oneWayFare] 片道金額(Yahoo!路線情報に表示される片道料金をそのまま入力できる)。
  /// サーバー側で自動的に2倍にして往復金額として保存する(手計算による2倍間違いを防止)。
  Future<bool> addStationRoute(
      String fromStation, String toStation, num oneWayFare) async {
    final result = await ApiService.call('staff.addStationRoute', params: {
      'fromStation': fromStation,
      'toStation': toStation,
      'oneWayFare': oneWayFare,
    });
    if (result.ok) {
      await loadStationRoutes();
      return true;
    }
    _errorMessage = result.error;
    notifyListeners();
    return false;
  }

  Future<bool> deleteStationRoute(String routeId) async {
    final result = await ApiService.call('staff.deleteStationRoute',
        params: {'routeId': routeId});
    if (result.ok) {
      await loadStationRoutes();
      return true;
    }
    _errorMessage = result.error;
    notifyListeners();
    return false;
  }

  Future<Map<String, dynamic>?> addWorkLog({
    required String workDate,
    required String customerId,
    required String startTime,
    required String endTime,
    required num breakHours,
    required num extraHours,
    required num roundTripFare,
    String fromStation = '',
    String toStation = '',
    String note = '',
  }) async {
    final result = await ApiService.call('staff.addWorkLog', params: {
      'workDate': workDate,
      'customerId': customerId,
      'startTime': startTime,
      'endTime': endTime,
      'breakHours': breakHours,
      'extraHours': extraHours,
      'roundTripFare': roundTripFare,
      'fromStation': fromStation,
      'toStation': toStation,
      'note': note,
    });
    if (result.ok) {
      return result.data;
    }
    _errorMessage = result.error;
    notifyListeners();
    return null;
  }

  Future<void> loadMyWorkLogs({String? yearMonth}) async {
    _isLoadingLogs = true;
    notifyListeners();
    final result = await ApiService.callList('staff.getMyWorkLogs', params: {
      if (yearMonth != null) 'yearMonth': yearMonth,
    });
    if (result.ok && result.data != null) {
      _myWorkLogs = result.data!
          .map((e) => WorkLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _errorMessage = result.error;
    }
    _isLoadingLogs = false;
    notifyListeners();
  }

  Future<bool> deleteWorkLog(String workId) async {
    final result =
        await ApiService.call('staff.deleteWorkLog', params: {'workId': workId});
    if (result.ok) {
      await loadMyWorkLogs();
      return true;
    }
    _errorMessage = result.error;
    notifyListeners();
    return false;
  }

  Future<bool> updateWorkLog({
    required String workId,
    String? customerId,
    String? startTime,
    String? endTime,
    num? breakHours,
    num? extraHours,
    num? roundTripFare,
    String? fromStation,
    String? toStation,
    String? note,
  }) async {
    final params = <String, dynamic>{'workId': workId};
    if (customerId != null) params['customerId'] = customerId;
    if (startTime != null) params['startTime'] = startTime;
    if (endTime != null) params['endTime'] = endTime;
    if (breakHours != null) params['breakHours'] = breakHours;
    if (extraHours != null) params['extraHours'] = extraHours;
    if (roundTripFare != null) params['roundTripFare'] = roundTripFare;
    if (fromStation != null) params['fromStation'] = fromStation;
    if (toStation != null) params['toStation'] = toStation;
    if (note != null) params['note'] = note;

    final result = await ApiService.call('staff.updateWorkLog', params: params);
    if (result.ok) {
      await loadMyWorkLogs();
      return true;
    }
    _errorMessage = result.error;
    notifyListeners();
    return false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
