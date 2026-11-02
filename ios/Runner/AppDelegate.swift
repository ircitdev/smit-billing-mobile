import Flutter
import Security
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Канал виджетов главного экрана — тот же, что у Android (lib/services/home_widgets.dart).
  private var widgetChannel: FlutterMethodChannel?
  /// Вкладка, которую попросил открыть виджет, пока Flutter ещё не запущен.
  private var launchTarget: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let url = launchOptions?[.url] as? URL { launchTarget = Self.widgetTarget(url) }
    if let reg = registrar(forPlugin: "SmitHomeWidgets") {
      let ch = FlutterMethodChannel(name: "ru.smit34.smit_billing/widgets", binaryMessenger: reg.messenger())
      ch.setMethodCallHandler { [weak self] call, result in self?.handleWidgets(call, result: result) }
      widgetChannel = ch
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let target = Self.widgetTarget(url) {
      launchTarget = target
      widgetChannel?.invokeMethod("open", arguments: target)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  /// smitbilling://widget/balance → "balance". Остальные адреса схемы — вход через OAuth.
  private static func widgetTarget(_ url: URL) -> String? {
    guard url.scheme == "smitbilling", url.host == "widget" else { return nil }
    let t = url.lastPathComponent
    return t.isEmpty || t == "/" ? nil : t
  }

  private func handleWidgets(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      let args = call.arguments as? [String: Any]
      if let base = args?["base"] as? String, let token = args?["token"] as? String {
        WidgetKeychain.save(base: base, token: token)
        reloadWidgets()
      }
      result(nil)
    case "clear":
      WidgetKeychain.clear()
      reloadWidgets()
      result(nil)
    case "takeLaunchTarget":
      result(launchTarget)
      launchTarget = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func reloadWidgets() {
    if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
  }
}

/// Ключ виджета в общей связке ключей приложения и расширения SmitWidgets
/// (keychain-access-groups в обоих .entitlements). Читает ios/SmitWidgets/WidgetData.swift.
enum WidgetKeychain {
  static let accessGroup = "6LX2W6558K.ru.smit34.smitBilling.shared"
  static let service = "ru.smit34.smitBilling.widget"

  private static var query: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "config",
      kSecAttrAccessGroup as String: accessGroup,
    ]
  }

  static func save(base: String, token: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: ["base": base, "token": token]) else { return }
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    // виджет обновляется и на заблокированном телефоне — после первой разблокировки
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(add as CFDictionary, nil)
  }

  static func clear() {
    SecItemDelete(query as CFDictionary)
  }
}
