import AppIntents
import WidgetKit
import SwiftUI
import home_widget

private let appGroupId = "group.com.example.mind_buddy"

struct HabitTodayItem: Hashable {
    let id: String
    let name: String
    let done: Bool
}

struct HabitTodayEntry: TimelineEntry {
    let date: Date
    let title: String
    let items: [HabitTodayItem]
    let moreCount: Int
    let errorMessage: String?
    let theme: HabitWidgetTheme
}

struct HabitWidgetTheme: Hashable {
    let paper: Color
    let box: Color
    let border: Color
    let text: Color
    let muted: Color
    let accent: Color
}

struct HabitTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitTodayEntry {
        HabitTodayEntry(
            date: Date(),
            title: "Habits",
            items: [],
            moreCount: 0,
            errorMessage: nil,
            theme: fallbackTheme()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HabitTodayEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitTodayEntry>) -> Void) {
        let entry = loadEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> HabitTodayEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "habits_widget_title") ?? "Habits"
        let moreCount = defaults?.integer(forKey: "habits_widget_more_count") ?? 0
        let errorMessage = defaults?.string(forKey: "habits_widget_error")
        let itemsJson = defaults?.string(forKey: "habits_widget_items_json") ?? "[]"
        let items = parseItems(from: itemsJson)
        let theme = readTheme(defaults)
        return HabitTodayEntry(
            date: Date(),
            title: title,
            items: items,
            moreCount: moreCount,
            errorMessage: errorMessage,
            theme: theme
        )
    }

    private func fallbackTheme() -> HabitWidgetTheme {
        HabitWidgetTheme(
            paper: Color(red: 0.97, green: 0.97, blue: 0.99),
            box: Color(red: 0.99, green: 0.99, blue: 1.0),
            border: Color(red: 0.84, green: 0.86, blue: 0.92),
            text: Color(red: 0.19, green: 0.21, blue: 0.30),
            muted: Color(red: 0.38, green: 0.41, blue: 0.52),
            accent: Color(red: 0.30, green: 0.36, blue: 0.55)
        )
    }

    private func readTheme(_ defaults: UserDefaults?) -> HabitWidgetTheme {
        let fallback = fallbackTheme()
        guard let defaults = defaults else { return fallback }
        return HabitWidgetTheme(
            paper: color(defaults.integer(forKey: "habits_theme_paper"), fallback: fallback.paper),
            box: color(defaults.integer(forKey: "habits_theme_box"), fallback: fallback.box),
            border: color(defaults.integer(forKey: "habits_theme_border"), fallback: fallback.border),
            text: color(defaults.integer(forKey: "habits_theme_text"), fallback: fallback.text),
            muted: color(defaults.integer(forKey: "habits_theme_muted"), fallback: fallback.muted),
            accent: color(defaults.integer(forKey: "habits_theme_accent"), fallback: fallback.accent)
        )
    }

    private func color(_ argb: Int, fallback: Color) -> Color {
        if argb == 0 { return fallback }
        let a = Double((argb >> 24) & 0xff) / 255.0
        let r = Double((argb >> 16) & 0xff) / 255.0
        let g = Double((argb >> 8) & 0xff) / 255.0
        let b = Double(argb & 0xff) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private func parseItems(from json: String) -> [HabitTodayItem] {
        guard let data = json.data(using: .utf8) else { return [] }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var out: [HabitTodayItem] = []
        for row in raw {
            let id = (row["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (row["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if id.isEmpty || name.isEmpty { continue }
            let done = row["done"] as? Bool ?? false
            out.append(HabitTodayItem(id: id, name: name, done: done))
        }
        return out
    }
}

struct HabitTodayWidgetExtensionEntryView: View {
    var entry: HabitTodayProvider.Entry
    @Environment(\.widgetFamily) private var family

    private var habitsUrl: URL {
        URL(string: "brainbubble://widget/habits")!
    }

    private var rowCandidates: [Int] {
        switch family {
        case .systemSmall:
            return [3, 2, 1]
        case .systemMedium:
            return [4, 3, 2]
        case .systemLarge:
            return [6, 5, 4, 3]
        default:
            return [4, 3, 2]
        }
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(rowCandidates, id: \.self) { candidate in
                content(maxRows: candidate)
            }
        }
        .padding(4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(entry.theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func content(maxRows: Int) -> some View {
        let hasOverflow = (entry.items.count + entry.moreCount) > maxRows
        let visibleHabitCount = hasOverflow ? max(0, maxRows - 1) : min(entry.items.count, maxRows)
        let visibleItems = Array(entry.items.prefix(visibleHabitCount))
        let hiddenFromStored = max(0, entry.items.count - visibleHabitCount)
        let computedMoreCount = entry.moreCount + hiddenFromStored

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entry.theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Link("View all", destination: habitsUrl)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(entry.theme.accent)
                    .lineLimit(1)
            }

            if visibleItems.isEmpty {
                Text("No active habits yet.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(entry.theme.muted)
                    .lineLimit(1)
            } else {
                ForEach(visibleItems, id: \.self) { item in
                    habitChip(item)
                }
                if computedMoreCount > 0 {
                    moreChip(moreCount: computedMoreCount)
                }
            }

            if let errorMessage = entry.errorMessage, !errorMessage.isEmpty,
               computedMoreCount == 0, visibleHabitCount < maxRows {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(red: 0.66, green: 0.25, blue: 0.25))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func habitChip(_ item: HabitTodayItem) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Button(
                intent: HabitToggleIntent(
                    habitId: item.id,
                    appGroup: appGroupId
                )
            ) {
                chipLabel(item)
            }
            .buttonStyle(.plain)
        } else {
            chipLabel(item)
        }
    }

    @ViewBuilder
    private func moreChip(moreCount: Int) -> some View {
        Link(destination: habitsUrl) {
            Text("+\(moreCount) more")
                .lineLimit(1)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(entry.theme.box)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entry.theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(entry.theme.muted)
        }
    }

    @ViewBuilder
    private func chipLabel(_ item: HabitTodayItem) -> some View {
            Text(item.name)
            .lineLimit(1)
            .font(.system(size: 10, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(item.done ? entry.theme.box.opacity(0.85) : Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(item.done ? entry.theme.accent.opacity(0.42) : entry.theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(item.done ? entry.theme.accent : entry.theme.text)
    }

}

struct HabitTodayWidgetExtension: Widget {
    let kind: String = "HabitTodayWidgetV2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitTodayProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                HabitTodayWidgetExtensionEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        entry.theme.paper
                    }
            } else {
                HabitTodayWidgetExtensionEntryView(entry: entry)
                    .background()
            }
        }
        .configurationDisplayName("Habit Tracker (Today)")
        .description("Track today's habit completion.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@available(iOSApplicationExtension 17.0, *)
#Preview(as: .systemMedium) {
    HabitTodayWidgetExtension()
} timeline: {
    HabitTodayEntry(
        date: .now,
        title: "Habits",
        items: [
            HabitTodayItem(id: "1", name: "Morning walk", done: true),
            HabitTodayItem(id: "2", name: "Read for 20 minutes", done: false),
            HabitTodayItem(id: "3", name: "Hydrate", done: true),
            HabitTodayItem(id: "4", name: "Stretch", done: false)
        ],
        moreCount: 2,
        errorMessage: nil,
        theme: HabitWidgetTheme(
            paper: Color(red: 0.97, green: 0.97, blue: 0.99),
            box: Color(red: 0.99, green: 0.99, blue: 1.0),
            border: Color(red: 0.84, green: 0.86, blue: 0.92),
            text: Color(red: 0.19, green: 0.21, blue: 0.30),
            muted: Color(red: 0.38, green: 0.41, blue: 0.52),
            accent: Color(red: 0.30, green: 0.36, blue: 0.55)
        )
    )
}

@available(iOSApplicationExtension 17.0, *)
struct HabitToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Habit Id")
    var habitId: String

    @Parameter(title: "AppGroup")
    var appGroup: String?

    init() {
        self.habitId = ""
    }

    init(habitId: String, appGroup: String?) {
        self.habitId = habitId
        self.appGroup = appGroup
    }

    func perform() async throws -> some IntentResult {
        guard let appGroup else { return .result() }
        let toggledDone = applyOptimisticToggle(habitId: habitId, appGroup: appGroup)
        if let toggledDone {
            enqueuePendingToggle(
                habitId: habitId,
                habitName: currentHabitName(appGroup: appGroup, habitId: habitId) ?? "",
                day: todayYmd(),
                completed: toggledDone,
                appGroup: appGroup
            )
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTodayWidgetV2")
        let encodedId = habitId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedName = currentHabitName(appGroup: appGroup, habitId: habitId)?
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let completedValue = toggledDone == true ? "1" : "0"
        let uri = URL(
            string: "homewidget://toggle?habit_id=\(encodedId)&habit_name=\(encodedName)&is_completed=\(completedValue)&already_toggled=1"
        )
        guard let uri else { return .result() }
        await HomeWidgetBackgroundWorker.run(url: uri, appGroup: appGroup)
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTodayWidgetV2")
        return .result()
    }

    private func applyOptimisticToggle(habitId: String, appGroup: String) -> Bool? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        let raw = defaults.string(forKey: "habits_widget_items_json") ?? "[]"
        guard let data = raw.data(using: .utf8) else { return nil }
        guard var arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }
        let needle = habitId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        var changed = false
        var toggledDone: Bool?
        for i in arr.indices {
            let id = (arr[i]["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if id != needle { continue }
            let done = arr[i]["done"] as? Bool ?? false
            toggledDone = !done
            arr[i]["done"] = toggledDone
            changed = true
            break
        }
        guard changed else { return nil }
        guard let out = try? JSONSerialization.data(withJSONObject: arr),
              let outString = String(data: out, encoding: .utf8) else {
            return nil
        }
        defaults.set(outString, forKey: "habits_widget_items_json")
        return toggledDone
    }

    private func currentHabitName(appGroup: String, habitId: String) -> String? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        let raw = defaults.string(forKey: "habits_widget_items_json") ?? "[]"
        guard let data = raw.data(using: .utf8) else { return nil }
        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }
        for item in arr {
            let id = (item["id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if id == habitId {
                return (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func todayYmd() -> String {
        let now = Date()
        let calendar = Calendar.current
        let y = calendar.component(.year, from: now)
        let m = calendar.component(.month, from: now)
        let d = calendar.component(.day, from: now)
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func enqueuePendingToggle(
        habitId: String,
        habitName: String,
        day: String,
        completed: Bool,
        appGroup: String
    ) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let key = "habits_widget_pending_toggles_json"
        let raw = defaults.string(forKey: key) ?? "[]"
        let data = raw.data(using: .utf8)
        let current = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [[String: Any]] ?? []
        var next: [[String: Any]] = []
        for row in current {
            let hid = (row["habit_id"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rday = (row["day"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if hid == habitId && rday == day { continue }
            next.append(row)
        }
        next.append([
            "habit_id": habitId,
            "habit_name": habitName,
            "day": day,
            "is_completed": completed,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ])
        guard let out = try? JSONSerialization.data(withJSONObject: next),
              let outString = String(data: out, encoding: .utf8) else {
            return
        }
        defaults.set(outString, forKey: key)
    }
}
