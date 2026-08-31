class WorkLog {
  final String workId;
  final String staffId;
  final String yearMonth;
  final String workDate; // 'yyyy-MM-dd'
  final String customerId;
  final String customerName;
  final String startTime; // 'HH:mm'
  final String endTime; // 'HH:mm'
  final num breakHours;
  final num extraHours;
  final num workHours;
  final num roundTripFare;
  final String fromStation;
  final String toStation;
  final String note;

  WorkLog({
    required this.workId,
    required this.staffId,
    required this.yearMonth,
    required this.workDate,
    required this.customerId,
    required this.customerName,
    required this.startTime,
    required this.endTime,
    required this.breakHours,
    required this.extraHours,
    required this.workHours,
    required this.roundTripFare,
    required this.fromStation,
    required this.toStation,
    required this.note,
  });

  factory WorkLog.fromJson(Map<String, dynamic> json) {
    return WorkLog(
      workId: json['workId']?.toString() ?? '',
      staffId: json['staffId']?.toString() ?? '',
      yearMonth: json['yearMonth']?.toString() ?? '',
      workDate: json['workDate']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      breakHours: json['breakHours'] ?? 0,
      extraHours: json['extraHours'] ?? 0,
      workHours: json['workHours'] ?? 0,
      roundTripFare: json['roundTripFare'] ?? 0,
      fromStation: json['fromStation']?.toString() ?? '',
      toStation: json['toStation']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}
