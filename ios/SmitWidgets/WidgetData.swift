// Виджеты главного экрана «Баланс» и «Видеонаблюдение» (iOS 17+): ключ и загрузка данных.
// Ключ только для чтения выдаёт сервер (mobile-api/v1/widget/token), приложение кладёт его
// в общую связку ключей (AppDelegate.swift, группа ru.smit34.smitBilling.shared). Виджет сам
// ходит за сводкой (widget/summary), кадрами камер (widget/camera/<id>/frame) и логотипом —
// так же, как Android-виджеты (smit_billing_app/android/.../widget/WidgetData.kt).
import Foundation
import Security
import UIKit

enum WidgetStore {
    static let accessGroup = "6LX2W6558K.ru.smit34.smitBilling.shared"
    static let service = "ru.smit34.smitBilling.widget"

    /// Адрес API и ключ виджета или nil, если в приложение не входили (или вышли).
    static func config() -> (base: String, token: String)? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "config",
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let base = json["base"], let token = json["token"], !token.isEmpty
        else { return nil }
        return (base.hasSuffix("/") ? String(base.dropLast()) : base, token)
    }
}

/// Что показать: нет входа, загрузили, не удалось (тогда — последняя удачная сводка).
enum SummaryState {
    case noLogin
    case ok([String: Any])
    case failed
}

enum WidgetApi {
    private static let cacheKey = "smit_widget_summary"

    static func get(_ url: String, token: String) async -> (Int, Data?) {
        guard let u = URL(string: url) else { return (0, nil) }
        var r = URLRequest(url: u, timeoutInterval: 10)
        r.setValue(token, forHTTPHeaderField: "X-Widget-Token")
        r.setValue("application/json, image/*", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: r)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            return (code, code == 200 ? data : nil)
        } catch {
            return (0, nil)
        }
    }

    /// Сводка: баланс, тариф, «хватит на», сессия, камеры. Нет сети — последняя удачная.
    static func summary() async -> SummaryState {
        guard let cfg = WidgetStore.config() else { return .noLogin }
        let (code, data) = await get(cfg.base + "/widget/summary", token: cfg.token)
        if code == 403 { return .noLogin }   // ключ отозван или истёк — до следующего входа
        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            UserDefaults.standard.set(data, forKey: cacheKey)
            return .ok(json)
        }
        if let cached = UserDefaults.standard.data(forKey: cacheKey),
           let json = try? JSONSerialization.jsonObject(with: cached) as? [String: Any] {
            return .ok(json)
        }
        return .failed
    }

    static func cameras(_ s: [String: Any]) -> [[String: Any]] {
        (s["cameras"] as? [[String: Any]]) ?? []
    }

    /// Картинка, уменьшенная под виджет: у виджета мало памяти.
    static func image(_ url: String, maxSide: CGFloat) async -> UIImage? {
        guard let cfg = WidgetStore.config() else { return nil }
        let (code, data) = await get(url, token: cfg.token)
        guard code == 200, let data, let img = UIImage(data: data) else { return nil }
        let k = min(1, maxSide / max(img.size.width, img.size.height))
        if k >= 1 { return img }
        return await img.byPreparingThumbnail(ofSize: CGSize(width: img.size.width * k, height: img.size.height * k)) ?? img
    }

    static func frame(cameraId: Int) async -> UIImage? {
        guard let cfg = WidgetStore.config() else { return nil }
        return await image(cfg.base + "/widget/camera/\(cameraId)/frame", maxSide: 720)
    }

    /// Логотип провайдера (PNG/JPEG; SVG виджет не покажет — тогда значок).
    static func logo(_ s: [String: Any]) async -> UIImage? {
        guard let url = s["logo_url"] as? String, !url.isEmpty else { return nil }
        return await image(url, maxSide: 160)
    }
}

enum Fmt {
    private static let ru = Locale(identifier: "ru_RU")

    static func money(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = ru
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 2
        return (f.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)) + " ₽"
    }

    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }

    /// «2026-11-02T13:05:10» → «13:05» сегодня, иначе «02.11 13:05».
    static func time(_ iso: String?) -> String? {
        guard let iso, iso.count >= 16 else { return nil }
        let p = DateFormatter()
        p.locale = ru
        p.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let d = p.date(from: String(iso.prefix(16))) else { return nil }
        let out = DateFormatter()
        out.locale = ru
        out.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "dd.MM HH:mm"
        return out.string(from: d)
    }

    static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s) }
        return nil
    }
}
