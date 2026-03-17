class FinanceOperation {
  final int id;
  final String date;
  final double amount;
  final String description;
  final String typeName;

  FinanceOperation({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.typeName,
  });

  factory FinanceOperation.fromJson(Map<String, dynamic> json) {
    return FinanceOperation(
      id: json['id'],
      date: json['date'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description'] ?? '',
      typeName: json['type_name'] ?? '',
    );
  }

  bool get isIncome => amount > 0;
}
