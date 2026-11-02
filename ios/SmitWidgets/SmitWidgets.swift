// Виджеты «Баланс» и «Видеонаблюдение» для iOS 17+ (как Android 1.5.2–1.5.3):
// баланс, на сколько дней хватит, тариф, сессия; свежий кадр выбранной камеры.
// Камера и частота обновления — в настройках виджета (долгое нажатие → «Изменить виджет»).
// iOS обновляет виджет не чаще, чем позволяет система (обычно раз в 15–30 минут).
// Нажатие открывает приложение: smitbilling://widget/balance | video (AppDelegate.swift).
import AppIntents
import SwiftUI
import WidgetKit

private let bg = Color(red: 0x0D / 255, green: 0x1B / 255, blue: 0x20 / 255)
private let textC = Color(red: 0xE6 / 255, green: 0xF2 / 255, blue: 0xF4 / 255)
private let muted = Color(red: 0x93 / 255, green: 0xA3 / 255, blue: 0xAD / 255)
private let brand = Color(red: 0x5B / 255, green: 0xA8 / 255, blue: 0x9D / 255)
private let amber = Color(red: 0xE0 / 255, green: 0xA0 / 255, blue: 0x3C / 255)
private let red = Color(red: 0xE5 / 255, green: 0x60 / 255, blue: 0x5A / 255)

/// Кнопка ⟳: после неё WidgetKit сам перечитывает данные виджета.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Обновить"
    func perform() async throws -> some IntentResult { .result() }
}

private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(muted)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - «Баланс»

struct BalanceEntry: TimelineEntry {
    let date: Date
    let state: SummaryState
    let logo: UIImage?
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: Date(), state: .ok(["balance": 1250.0, "days_left": 14, "tariff": "Домашний 100"]), logo: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        Task {
            let e = await load()
            completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }

    private func load() async -> BalanceEntry {
        let s = await WidgetApi.summary()
        var logo: UIImage?
        if case .ok(let json) = s { logo = await WidgetApi.logo(json) }
        return BalanceEntry(date: Date(), state: s, logo: logo)
    }
}

struct BalanceView: View {
    let entry: BalanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let logo = entry.logo {
                    Image(uiImage: logo).resizable().scaledToFit().frame(height: 18)
                } else {
                    Image(systemName: "wallet.pass.fill").foregroundStyle(brand).font(.system(size: 13))
                    Text("Баланс").font(.system(size: 13, weight: .semibold)).foregroundStyle(muted)
                }
                Spacer(minLength: 0)
                RefreshButton()
            }
            switch entry.state {
            case .ok(let s): filled(s)
            case .noLogin: empty("Войдите в приложение")
            case .failed: empty("Нет связи с сервером")
            }
        }
        .containerBackground(bg, for: .widget)
        .widgetURL(URL(string: "smitbilling://widget/balance"))
    }

    private func empty(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text("—").font(.system(size: 28, weight: .bold)).foregroundStyle(textC)
            Text(text).font(.system(size: 12)).foregroundStyle(muted)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func filled(_ s: [String: Any]) -> some View {
        let bal = Fmt.number(s["balance"]) ?? 0
        let blocked = (s["blocked"] as? Bool) ?? false
        let days = s["days_left"] as? Int
        Spacer(minLength: 0)
        Text(Fmt.money(bal))
            .font(.system(size: family == .systemSmall ? 24 : 28, weight: .bold))
            .foregroundStyle(bal < 0 ? red : textC)
            .minimumScaleFactor(0.6).lineLimit(1)
        Text(daysText(s, days: days, blocked: blocked))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(blocked || (days.map { $0 <= 3 } ?? false) ? amber : muted)
            .lineLimit(2)
        if family != .systemSmall, let tariff = s["tariff"] as? String, !tariff.isEmpty {
            Text(tariff).font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
        }
        Spacer(minLength: 0)
        HStack(spacing: 5) {
            let ses = s["session"] as? [String: Any]
            let online = ses?["online"] as? Bool
            Circle().fill(online == true ? brand : muted.opacity(0.6)).frame(width: 7, height: 7)
            Text(sessionText(ses, online: online)).font(.system(size: 11)).foregroundStyle(muted).lineLimit(1)
            Spacer(minLength: 0)
            if family != .systemSmall {
                if let c = s["contract"] as? String, !c.isEmpty {
                    Text("№ \(c)").font(.system(size: 11)).foregroundStyle(muted)
                }
                if let t = Fmt.time(s["updated"] as? String) {
                    Text("· \(t)").font(.system(size: 11)).foregroundStyle(muted)
                }
            }
        }
    }

    private func daysText(_ s: [String: Any], days: Int?, blocked: Bool) -> String {
        if blocked { return "Доступ ограничен — пополните баланс" }
        if let d = days, d > 0 {
            var t = "Хватит на \(d) \(Fmt.plural(d, "день", "дня", "дней"))"
            if let u = s["until"] as? String, u.count >= 10 {
                let a = Array(u)
                t += " · до \(a[8])\(a[9]).\(a[5])\(a[6])"
            }
            return t
        }
        if days == 0 { return "Пора пополнить баланс" }
        return "Абонплата \(Fmt.money(Fmt.number(s["monthly"]) ?? 0))/мес"
    }

    private func sessionText(_ ses: [String: Any]?, online: Bool?) -> String {
        guard let online else { return "Сессия: нет данных" }
        if online {
            if let since = Fmt.time(ses?["since"] as? String) { return "В сети с \(since)" }
            return "В сети"
        }
        return "Не в сети"
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SmitBalance", provider: BalanceProvider()) { BalanceView(entry: $0) }
            .configurationDisplayName("Баланс")
            .description("Баланс, на сколько дней хватит и состояние подключения")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - «Видеонаблюдение»

struct CameraEntity: AppEntity {
    let id: Int
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Камера"
    static var defaultQuery = CameraQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct CameraQuery: EntityQuery {
    private func all() async -> [CameraEntity] {
        guard case .ok(let s) = await WidgetApi.summary() else { return [] }
        return WidgetApi.cameras(s).compactMap { c in
            guard let id = c["id"] as? Int else { return nil }
            return CameraEntity(id: id, name: (c["name"] as? String) ?? "Камера \(id)")
        }
    }

    func entities(for identifiers: [Int]) async throws -> [CameraEntity] {
        await all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CameraEntity] { await all() }
}

enum RefreshEvery: Int, AppEnum {
    case m15 = 15, m30 = 30, m60 = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Как часто обновлять"
    static var caseDisplayRepresentations: [RefreshEvery: DisplayRepresentation] = [
        .m15: "Раз в 15 минут", .m30: "Раз в 30 минут", .m60: "Раз в час",
    ]
}

struct VideoConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Видеонаблюдение"
    static var description = IntentDescription("Какую камеру показывать и как часто обновлять кадр")

    @Parameter(title: "Камера")
    var camera: CameraEntity?

    @Parameter(title: "Обновлять", default: .m30)
    var every: RefreshEvery
}

struct VideoEntry: TimelineEntry {
    let date: Date
    let state: SummaryState
    let camera: [String: Any]?
    let index: Int
    let total: Int
    let frame: UIImage?
    let every: Int
}

struct VideoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VideoEntry {
        VideoEntry(date: Date(), state: .ok([:]), camera: ["name": "Подъезд", "viewable": true], index: 0, total: 2, frame: nil, every: 30)
    }

    func snapshot(for configuration: VideoConfigIntent, in context: Context) async -> VideoEntry {
        context.isPreview ? placeholder(in: context) : await load(configuration)
    }

    func timeline(for configuration: VideoConfigIntent, in context: Context) async -> Timeline<VideoEntry> {
        let e = await load(configuration)
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(Double(configuration.every.rawValue) * 60)))
    }

    private func load(_ cfg: VideoConfigIntent) async -> VideoEntry {
        let every = cfg.every.rawValue
        let s = await WidgetApi.summary()
        guard case .ok(let json) = s else {
            return VideoEntry(date: Date(), state: s, camera: nil, index: 0, total: 0, frame: nil, every: every)
        }
        let cams = WidgetApi.cameras(json)
        // камера виджета: выбранная, иначе первая с кадром, иначе первая
        var idx = cams.firstIndex { ($0["id"] as? Int) == cfg.camera?.id }
            ?? cams.firstIndex { ($0["viewable"] as? Bool) == true }
        if idx == nil && !cams.isEmpty { idx = 0 }
        guard let i = idx else {
            return VideoEntry(date: Date(), state: s, camera: nil, index: 0, total: 0, frame: nil, every: every)
        }
        let cam = cams[i]
        var frame: UIImage?
        if (cam["viewable"] as? Bool) == true, let id = cam["id"] as? Int {
            frame = await WidgetApi.frame(cameraId: id)
        }
        return VideoEntry(date: Date(), state: s, camera: cam, index: i, total: cams.count, frame: frame, every: every)
    }
}

struct VideoView: View {
    let entry: VideoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                RefreshButton()
            }
            Spacer(minLength: 0)
            if entry.frame == nil {
                Text(emptyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text((entry.camera?["name"] as? String) ?? "Видеонаблюдение")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(textC).lineLimit(1)
                if !subText.isEmpty {
                    Text(subText).font(.system(size: 10)).foregroundStyle(textC.opacity(0.75)).lineLimit(1)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45)))
        }
        .containerBackground(for: .widget) {
            if let img = entry.frame {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                bg
            }
        }
        .widgetURL(URL(string: "smitbilling://widget/video"))
    }

    private var emptyText: String {
        switch entry.state {
        case .noLogin: return "Войдите в приложение"
        case .failed: return "Нет связи с сервером"
        case .ok:
            guard let cam = entry.camera else { return "Камер пока нет" }
            return (cam["viewable"] as? Bool) == true ? "Нет кадра" : "Камера недоступна"
        }
    }

    private var subText: String {
        var parts: [String] = []
        if let o = entry.camera?["object"] as? String, !o.isEmpty { parts.append(o) }
        if entry.total > 1 { parts.append("\(entry.index + 1) из \(entry.total)") }
        if case .ok(let s) = entry.state, let t = Fmt.time(s["updated"] as? String) { parts.append(t) }
        if entry.camera != nil { parts.append(entry.every == 60 ? "раз в час" : "раз в \(entry.every) мин") }
        return parts.joined(separator: " · ")
    }
}

struct VideoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SmitVideo", intent: VideoConfigIntent.self, provider: VideoProvider()) {
            VideoView(entry: $0)
        }
        .configurationDisplayName("Видеонаблюдение")
        .description("Свежий кадр с ваших камер")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SmitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        VideoWidget()
    }
}
