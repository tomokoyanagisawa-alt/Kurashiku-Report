class StationRoute {
  final String routeId;
  final String fromStation;
  final String toStation;
  final num roundTripFare;
  final bool confirmed;

  StationRoute({
    required this.routeId,
    required this.fromStation,
    required this.toStation,
    required this.roundTripFare,
    required this.confirmed,
  });

  factory StationRoute.fromJson(Map<String, dynamic> json) {
    return StationRoute(
      routeId: json['routeId']?.toString() ?? '',
      fromStation: json['fromStation']?.toString() ?? '',
      toStation: json['toStation']?.toString() ?? '',
      roundTripFare: json['roundTripFare'] ?? 0,
      confirmed: json['confirmed'] == true,
    );
  }

  String get label => '$fromStation ⇄ $toStation (往復${roundTripFare.toStringAsFixed(0)}円)';
}
