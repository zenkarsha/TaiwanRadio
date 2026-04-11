import Foundation

@MainActor
final class ScheduleService: ObservableObject {
    private enum DefaultsKey {
        static let scheduledPlayEnabled = "scheduledPlayEnabled"
        static let scheduledPlayTime = "scheduledPlayTime"
        static let scheduledPlayStationID = "scheduledPlayStationID"
        static let scheduledPlayLastTriggered = "scheduledPlayLastTriggered"
        static let scheduledStopEnabled = "scheduledStopEnabled"
        static let scheduledStopTime = "scheduledStopTime"
        static let scheduledStopLastTriggered = "scheduledStopLastTriggered"
    }

    @Published private(set) var scheduledPlaySettings: ScheduledPlaySettings
    @Published private(set) var scheduledStopSettings: ScheduledStopSettings

    private let defaults: UserDefaults
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultTime = Self.defaultScheduleTime()

        scheduledPlaySettings = ScheduledPlaySettings(
            isEnabled: defaults.bool(forKey: DefaultsKey.scheduledPlayEnabled),
            time: defaults.object(forKey: DefaultsKey.scheduledPlayTime) as? Date ?? defaultTime,
            stationID: defaults.string(forKey: DefaultsKey.scheduledPlayStationID)
        )
        scheduledStopSettings = ScheduledStopSettings(
            isEnabled: defaults.bool(forKey: DefaultsKey.scheduledStopEnabled),
            time: defaults.object(forKey: DefaultsKey.scheduledStopTime) as? Date ?? defaultTime
        )
    }

    func scheduledPlayStation(from stations: [RadioStation]) -> RadioStation? {
        guard let stationID = scheduledPlaySettings.stationID else { return nil }
        return stations.first(where: { $0.id == stationID })
    }

    func updateScheduledPlayEnabled(_ isEnabled: Bool) {
        if isEnabled, scheduledPlaySettings.stationID == nil {
            scheduledPlaySettings.isEnabled = false
        } else {
            scheduledPlaySettings.isEnabled = isEnabled
        }
        persistScheduledPlaySettings()
    }

    func updateScheduledPlayTime(_ time: Date) {
        scheduledPlaySettings.time = normalizedTime(time)
        persistScheduledPlaySettings()
    }

    func updateScheduledPlayStation(_ station: RadioStation?) {
        scheduledPlaySettings.stationID = station?.id
        if station == nil {
            scheduledPlaySettings.isEnabled = false
        }
        persistScheduledPlaySettings()
    }

    func updateScheduledStopEnabled(_ isEnabled: Bool) {
        scheduledStopSettings.isEnabled = isEnabled
        persistScheduledStopSettings()
    }

    func updateScheduledStopTime(_ time: Date) {
        scheduledStopSettings.time = normalizedTime(time)
        persistScheduledStopSettings()
    }

    func sanitizeSchedules(using stations: [RadioStation]) {
        if let stationID = scheduledPlaySettings.stationID,
           !stations.contains(where: { $0.id == stationID }) {
            scheduledPlaySettings.stationID = nil
            scheduledPlaySettings.isEnabled = false
            persistScheduledPlaySettings()
        }
    }

    func processSchedules(
        at now: Date,
        stations: [RadioStation],
        onPlay: (RadioStation) -> Void,
        onStop: () -> Void
    ) {
        let currentMinute = minuteIdentifier(for: now)

        if scheduledPlaySettings.isEnabled,
           let station = scheduledPlayStation(from: stations),
           shouldTrigger(time: scheduledPlaySettings.time, now: now, lastTriggeredKey: DefaultsKey.scheduledPlayLastTriggered, currentMinute: currentMinute) {
            onPlay(station)
            defaults.set(currentMinute, forKey: DefaultsKey.scheduledPlayLastTriggered)
        }

        if scheduledStopSettings.isEnabled,
           shouldTrigger(time: scheduledStopSettings.time, now: now, lastTriggeredKey: DefaultsKey.scheduledStopLastTriggered, currentMinute: currentMinute) {
            onStop()
            defaults.set(currentMinute, forKey: DefaultsKey.scheduledStopLastTriggered)
        }
    }

    func previewConfigure(play: ScheduledPlaySettings, stop: ScheduledStopSettings) {
        scheduledPlaySettings = play
        scheduledStopSettings = stop
    }

    private func shouldTrigger(time: Date, now: Date, lastTriggeredKey: String, currentMinute: String) -> Bool {
        guard defaults.string(forKey: lastTriggeredKey) != currentMinute else {
            return false
        }

        let scheduledComponents = calendar.dateComponents([.hour, .minute], from: time)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

        return scheduledComponents.hour == nowComponents.hour && scheduledComponents.minute == nowComponents.minute
    }

    private func persistScheduledPlaySettings() {
        defaults.set(scheduledPlaySettings.isEnabled, forKey: DefaultsKey.scheduledPlayEnabled)
        defaults.set(scheduledPlaySettings.time, forKey: DefaultsKey.scheduledPlayTime)
        defaults.set(scheduledPlaySettings.stationID, forKey: DefaultsKey.scheduledPlayStationID)
    }

    private func persistScheduledStopSettings() {
        defaults.set(scheduledStopSettings.isEnabled, forKey: DefaultsKey.scheduledStopEnabled)
        defaults.set(scheduledStopSettings.time, forKey: DefaultsKey.scheduledStopTime)
    }

    private func normalizedTime(_ date: Date) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private func minuteIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        ].map(String.init).joined(separator: "-")
    }

    private static func defaultScheduleTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: now)
        let nextMinute = ((minute / 5) + 1) * 5
        let base = calendar.date(bySettingHour: calendar.component(.hour, from: now), minute: min(nextMinute, 55), second: 0, of: now)
        return base ?? now
    }
}
