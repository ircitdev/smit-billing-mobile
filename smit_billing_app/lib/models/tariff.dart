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
      id: json['id'],
      name: json['name'] ?? '',
      monthlyCost: double.tryParse(json['monthly_cost']?.toString() ?? '0') ?? 0,
      speedMbit: json['speed_mbit'],
      description: json['description'] ?? '',
      isCurrent: json['is_current'] ?? false,
      canSwitch: json['can_switch'] ?? false,
    );
  }
}
