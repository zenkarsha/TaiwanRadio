import Foundation

enum StationSection: String, CaseIterable, Identifiable {
    case favorites = "我的最愛"
    case recent = "最近播放"
    case stations = "所有電台"
    case hot = "熱門電台"

    var id: String { rawValue }
}

struct ScheduledPlaySettings {
    var isEnabled: Bool
    var time: Date
    var stationID: String?
}

struct ScheduledStopSettings {
    var isEnabled: Bool
    var time: Date
}

struct ScheduledStationSwitchSettings {
    var isEnabled: Bool
    var time: Date
    var stationID: String?
    var weekdays: Set<ScheduledWeekday>
}

enum ScheduledWeekday: Int, CaseIterable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .monday:
            return "一"
        case .tuesday:
            return "二"
        case .wednesday:
            return "三"
        case .thursday:
            return "四"
        case .friday:
            return "五"
        case .saturday:
            return "六"
        case .sunday:
            return "日"
        }
    }

    static var displayOrder: [ScheduledWeekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    static func < (lhs: ScheduledWeekday, rhs: ScheduledWeekday) -> Bool {
        displayOrder.firstIndex(of: lhs) ?? 0 < displayOrder.firstIndex(of: rhs) ?? 0
    }
}

struct RadioStation: Decodable, Identifiable, Equatable {
    let stationUUID: String
    let name: String
    let favicon: String?
    let url: String?
    let urlResolved: String?
    let tags: String?
    let language: String?
    let country: String?
    let codec: String?
    let bitrate: Int?
    let votes: Int?

    var id: String { stationUUID }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名電台" : trimmed
    }

    var streamURL: URL? {
        streamURLs.first
    }

    var streamURLs: [URL] {
        let candidates = [urlResolved, url]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var resolvedURLs: [URL] = []
        var seen = Set<String>()

        for candidate in candidates {
            guard let parsed = URL(string: candidate) else { continue }
            guard let scheme = parsed.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            let key = parsed.absoluteString
            guard seen.insert(key).inserted else { continue }
            resolvedURLs.append(parsed)
        }

        return resolvedURLs
    }

    var subtitle: String {
        var pieces: [String] = []

        if let codec = codec.nilIfBlank {
            pieces.append(codec.uppercased())
        }

        if let bitrate {
            pieces.append("\(bitrate) kbps")
        }

        if pieces.isEmpty {
            return country.nilIfBlank ?? "Taiwan"
        }

        return pieces.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case stationUUID = "stationuuid"
        case name
        case favicon
        case url
        case urlResolved = "url_resolved"
        case tags
        case language
        case country
        case codec
        case bitrate
        case votes
    }
}

enum PlayerPhase: Equatable {
    case idle
    case loading(String)
    case paused
    case playing
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "選一個電台開始播放"
        case let .loading(message):
            return message
        case .paused:
            return "已暫停"
        case .playing:
            return "播放中"
        case let .failed(message):
            return message
        }
    }
}
