import 'package:flutter/material.dart';
import '../models/account_status.dart';
import '../models/tariff.dart';
import '../models/finance_operation.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class AccountProvider extends ChangeNotifier {
  ApiClient? _api;
  AccountStatus? _status;
  List<Tariff> _tariffs = [];
  List<FinanceOperation> _history = [];
  int _historyTotal = 0;
  bool _isLoading = false;
  String? _error;

  AccountStatus? get status => _status;
  List<Tariff> get tariffs => _tariffs;
  List<FinanceOperation> get history => _history;
  int get historyTotal => _historyTotal;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    _api = auth.api;
  }

  /// Public API access for screens that need custom endpoints.
  Future<dynamic> apiGet(String path) async => _api?.get(path);
  Future<dynamic> apiPost(String path, Map<String, dynamic> body) async => _api?.post(path, body);

  Future<void> loadStatus() async {
    if (_api == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api!.get('/account/status');
      _status = AccountStatus.fromJson(data);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Ошибка загрузки';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTariffs() async {
    if (_api == null) return;
    try {
      final data = await _api!.get('/account/tariffs');
      _tariffs = (data as List).map((t) => Tariff.fromJson(t)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> changeTariff(int tariffId) async {
    if (_api == null) return 'Не авторизован';
    try {
      await _api!.post('/account/tariff', {'tariff_id': tariffId});
      await loadStatus();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> loadHistory({String period = '', int page = 1}) async {
    if (_api == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      String query = '?page=$page&per_page=25';
      if (period.isNotEmpty) query += '&period=$period';
      final data = await _api!.get('/finance/history$query');
      _history = (data['items'] as List)
          .map((o) => FinanceOperation.fromJson(o))
          .toList();
      _historyTotal = data['total'] ?? 0;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getPromisePay() async {
    if (_api == null) return {};
    return await _api!.get('/finance/promise_pay');
  }

  Future<String?> activatePromisePay() async {
    try {
      await _api!.post('/finance/promise_pay');
      await loadStatus();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> cancelPromisePay() async {
    try {
      await _api!.delete('/finance/promise_pay');
      await loadStatus();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<Map<String, dynamic>?> createPayment(double amount) async {
    try {
      final data = await _api!.post('/finance/pay', {
        'amount': amount.toStringAsFixed(2),
        'system': 'yookassa',
      });
      return data;
    } on ApiException {
      return null;
    }
  }

  // Voluntary block
  Future<Map<String, dynamic>> getVoluntaryBlock() async {
    if (_api == null) return {};
    return await _api!.get('/account/voluntary_block');
  }

  Future<String?> toggleVoluntaryBlock(String action) async {
    try {
      final data = await _api!.post('/account/voluntary_block', {'action': action});
      await loadStatus();
      return data['detail'];
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // Support tickets
  Future<List<Map<String, dynamic>>> loadTickets() async {
    if (_api == null) return [];
    try {
      final data = await _api!.get('/support/tickets');
      return ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getTicketDetail(int ticketId) async {
    if (_api == null) return {};
    return await _api!.get('/support/tickets/$ticketId');
  }

  Future<String?> replyTicket(int ticketId, String body) async {
    try {
      final data = await _api!.post('/support/tickets/$ticketId', {'body': body});
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
