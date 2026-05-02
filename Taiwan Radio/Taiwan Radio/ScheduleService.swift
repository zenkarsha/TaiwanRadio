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
        static let scheduledStationSwitchEnabled = "scheduledStationSwitchEnabled"
        static let scheduledStationSwitchTime = "scheduledStationSwitchTime"
        static let scheduledStationSwitchStationID = "scheduledStationSwitchStationID"
        static let scheduledStationSwitchWeekdays = "scheduledStationSwitchWeekdays"
        static let scheduledStationSwitchLastTriggered = "scheduledStationSwitchLastTriggered"
    }

    @Published private(set) var scheduledPlaySettings: ScheduledPlaySettings
    @Published private(set) var scheduledStopSettings: ScheduledStopSettings
    @Published private(set) var scheduledStationSwitchSettings: ScheduledStationSwitchSettings

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
        scheduledStationSwitchSettings = ScheduledStationSwitchSettings(
            isEnabled: defaults.bool(forKey: DefaultsKey.scheduledStationSwitchEnabled),
            time: defaults.object(forKey: DefaultsKey.scheduledStationSwitchTime) as? Date ?? defaultTime,
            stationID: defaults.string(forKey: DefaultsKey.scheduledStationSwitchStationID),
            weekdays: Self.storedWeekdays(from: defaults.array(forKey: DefaultsKey.scheduledStationSwitchWeekdays) as? [Int])
        )
    }

    func scheduledPlayStation(from stations: [RadioStation]) -> RadioStation? {
        guard let stationID = scheduledPlaySettings.stationID else { return nil }
        return stations.first(where: { $0.id == stationID })
    }

    func scheduledStationSwitchStation(from stations: [RadioStation]) -> RadioStation? {
        guard let stationID = scheduledStationSwitchSettings.stationID else { return nil }
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

    func updateScheduledStationSwitchEnabled(_ isEnabled: Bool) {
        if isEnabled, scheduledStationSwitchSettings.stationID == nil || scheduledStationSwitchSettings.weekdays.isEmpty {
            scheduledStationSwitchSettings.isEnabled = false
        } else {
            scheduledStationSwitchSettings.isEnabled = isEnabled
        }
        persistScheduledStationSwitchSettings()
    }

    func updateScheduledStationSwitchTime(_ time: Date) {
        scheduledStationSwitchSettings.time = normalizedTime(time)
        persistScheduledStationSwitchSettings()
    }

    func updateScheduledStationSwitchStation(_ station: RadioStation?) {
        scheduledStationSwitchSettings.stationID = station?.id
        if station == nil {
            scheduledStationSwitchSettings.isEnabled = false
        }
        persistScheduledStationSwitchSettings()
    }

    func toggleScheduledStationSwitchWeekday(_ weekday: ScheduledWeekday) {
        if scheduledStationSwitchSettings.weekdays.contains(weekday) {
            scheduledStationSwitchSettings.weekdays.remove(weekday)
        } else {
            scheduledStationSwitchSettings.weekdays.insert(weekday)
        }
        if scheduledStationSwitchSettings.weekdays.isEmpty {
            scheduledStationSwitchSettings.isEnabled = false
        }
        persistScheduledStationSwitchSettings()
    }

    func sanitizeSchedules(using stations: [RadioStation]) {
        if let stationID = scheduledPlaySettings.stationID,
           !stations.contains(where: { $0.id == stationID }) {
            scheduledPlaySettings.stationID = nil
            scheduledPlaySettings.isEnabled = false
            persistScheduledPlaySettings()
        }

        if let stationID = scheduledStationSwitchSettings.stationID,
           !stations.contains(where: { $0.id == stationID }) {
            scheduledStationSwitchSettings.stationID = nil
            scheduledStationSwitchSettings.isEnabled = false
            persistScheduledStationSwitchSettings()
        }
    }

    func processSchedules(
        at now: Date,
        stations: [RadioStation],
        onPlay: (RadioStation) -> Void,
        onSwitchStation: (RadioStation) -> Void,
        onStop: () -> Void
    ) {
        let currentMinute = minuteIdentifier(for: now)

        if scheduledPlaySettings.isEnabled,
           let station = scheduledPlayStation(from: stations),
           shouldTrigger(time: scheduledPlaySettings.time, now: now, lastTriggeredKey: DefaultsKey.scheduledPlayLastTriggered, currentMinute: currentMinute) {
            onPlay(station)
            defaults.set(currentMinute, forKey: DefaultsKey.scheduledPlayLastTriggered)
        }

        if scheduledStationSwitchSettings.isEnabled,
           scheduledStationSwitchSettings.weekdays.contains(weekday(for: now)),
           let station = scheduledStationSwitchStation(from: stations),
           shouldTrigger(time: scheduledStationSwitchSettings.time, now: now, lastTriggeredKey: DefaultsKey.scheduledStationSwitchLastTriggered, currentMinute: currentMinute) {
            onSwitchStation(station)
            defaults.set(currentMinute, forKey: DefaultsKey.scheduledStationSwitchLastTriggered)
        }

        if scheduledStopSettings.isEnabled,
           shouldTrigger(time: scheduledStopSettings.time, now: now, lastTriggeredKey: DefaultsKey.scheduledStopLastTriggered, currentMinute: currentMinute) {
            onStop()
            defaults.set(currentMinute, forKey: DefaultsKey.scheduledStopLastTriggered)
        }
    }

    func previewConfigure(play: ScheduledPlaySettings, stop: ScheduledStopSettings, stationSwitch: ScheduledStationSwitchSettings) {
        scheduledPlaySettings = play
        scheduledStopSettings = stop
        scheduledStationSwitchSettings = stationSwitch
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

    private func persistScheduledStationSwitchSettings() {
        defaults.set(scheduledStationSwitchSettings.isEnabled, forKey: DefaultsKey.scheduledStationSwitchEnabled)
        defaults.set(scheduledStationSwitchSettings.time, forKey: DefaultsKey.scheduledStationSwitchTime)
        defaults.set(scheduledStationSwitchSettings.stationID, forKey: DefaultsKey.scheduledStationSwitchStationID)
        defaults.set(scheduledStationSwitchSettings.weekdays.sorted().map(\.rawValue), forKey: DefaultsKey.scheduledStationSwitchWeekdays)
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

    private func weekday(for date: Date) -> ScheduledWeekday {
        ScheduledWeekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }

    private static func storedWeekdays(from rawValues: [Int]?) -> Set<ScheduledWeekday> {
        guard let rawValues else {
            return Set(ScheduledWeekday.allCases)
        }

        return Set(rawValues.compactMap(ScheduledWeekday.init(rawValue:)))
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
