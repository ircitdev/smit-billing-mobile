class Tariff {
  final int id;
  final String name;
  final double monthlyCost;
  final int? speedMbit;
  final String description;
  final bool isCurrent;
  final bool canSwitch;

  Tariff({
    required this.id,
    required this.name,
    required this.monthlyCost,
    this.speedMbit,
    required this.description,
    required this.isCurrent,
    required this.canSwitch,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    return Tariff(
      id: _asInt(json['id']),
      name: json['name'] ?? '',
      monthlyCost: double.tryParse(json['monthly_cost']?.toString() ?? '0') ?? 0,
      speedMbit: json['speed_mbit'],
      description: json['description'] ?? '',
      isCurrent: json['is_current'] ?? false,
      canSwitch: json['can_switch'] ?? false,
    );
  }

  /// Безопасное приведение к int: переживает null / строку / double из JSON.
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
