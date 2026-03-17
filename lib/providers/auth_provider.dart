import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricEnabled => _biometricEnabled;

  Future<void> tryAutoLogin() async {
    await api.loadTokens();
    await _checkBiometric();

    if (api.isAuthenticated) {
      _isAuthenticated = true;
      _initPush();
      notifyListeners();
    }
  }

  Future<void> _checkBiometric() async {
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      final enabled = await _storage.read(key: 'biometric_enabled');
      _biometricEnabled = enabled == 'true';
    } catch (_) {
      _biometricAvailable = false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    if (!_biometricAvailable) return false;
    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Войдите с помощью биометрии',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (success) {
        // Load saved credentials
        await api.loadTokens();
        if (api.isAuthenticated) {
          _isAuthenticated = true;
          _initPush();
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
    _biometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> login(String contract, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await api.login(contract, password);
      // Save credentials for biometric re-auth
      await _storage.write(key: 'saved_contract', value: contract);
      await _storage.write(key: 'saved_password', value: password);
      _isAuthenticated = true;
      _isLoading = false;
      _initPush();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Ошибка подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.clearTokens();
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<String?> changePassword(String current, String newPwd, String confirm) async {
    try {
      final data = await api.post('/account/change_password', {
        'current_password': current,
        'new_password': newPwd,
        'confirm_password': confirm,
      });
      return null; // success
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void _initPush() {
    try {
      PushService(api).init();
    } catch (_) {}
  }
}
