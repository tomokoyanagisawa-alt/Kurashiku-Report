class Customer {
  final String customerId;
  final String name;

  Customer({required this.customerId, required this.name});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
