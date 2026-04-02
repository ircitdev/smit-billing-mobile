class AccountStatus {
  final int abonentId;
  final String name;
  final String contractNumber;
  final double balance;
  final String? tariffName;
  final int? tariffId;
  final int? speedMbit;
  final double monthlyCost;
  final bool isBlocked;
  final String blockReason;
  final bool hasPromisePay;
  final String? promisePayEnd;
  final double? promisePayAmount;
  final String? balanceUntilDate;
  final String address;
  final String email;
  final String sms;
  final String notification;
  final Map<String, dynamic>? lastPayment;
  final String? paymentSystemName;
  final String? paymentSystemLabel;

  AccountStatus({
    required this.abonentId,
    required this.name,
    required this.contractNumber,
    required this.balance,
    this.tariffName,
    this.tariffId,
    this.speedMbit,
    required this.monthlyCost,
    required this.isBlocked,
    required this.blockReason,
    required this.hasPromisePay,
    this.promisePayEnd,
    this.promisePayAmount,
    this.balanceUntilDate,
    required this.address,
    required this.email,
    required this.sms,
    required this.notification,
    this.lastPayment,
    this.paymentSystemName,
    this.paymentSystemLabel,
  });

  factory AccountStatus.fromJson(Map<String, dynamic> json) {
    return AccountStatus(
      abonentId: json['abonent_id'],
      name: json['name'] ?? '',
      contractNumber: json['contract_number'] ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      tariffName: json['tariff_name'],
      tariffId: json['tariff_id'],
      speedMbit: json['speed_mbit'],
      monthlyCost: double.tryParse(json['monthly_cost']?.toString() ?? '0') ?? 0,
      isBlocked: json['is_blocked'] ?? false,
      blockReason: json['block_reason'] ?? '',
      hasPromisePay: json['has_promise_pay'] ?? false,
      promisePayEnd: json['promise_pay_end'],
      promisePayAmount: double.tryParse(json['promise_pay_amount']?.toString() ?? ''),
      balanceUntilDate: json['balance_until_date'],
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      sms: json['sms'] ?? '',
      notification: json['notification'] ?? '',
      lastPayment: json['last_payment'],
      paymentSystemName: json['payment_system']?['name'],
      paymentSystemLabel: json['payment_system']?['label'],
    );
  }
}
