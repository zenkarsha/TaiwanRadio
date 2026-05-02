import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    private enum DefaultsKey {
        static let favoriteStationIDs = "favoriteStationIDs"
        static let recentStationIDs = "recentStationIDs"
        static let selectedSection = "selectedStationSection"
    }

    @Published private(set) var favoriteStationIDs: Set<String>
    @Published private(set) var recentStationIDs: [String]
    @Published private(set) var selectedSection: StationSection

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteStationIDs = Set(defaults.stringArray(forKey: DefaultsKey.favoriteStationIDs) ?? [])
        recentStationIDs = defaults.stringArray(forKey: DefaultsKey.recentStationIDs) ?? []
        selectedSection = StationSection(rawValue: defaults.string(forKey: DefaultsKey.selectedSection) ?? "") ?? .stations
    }

    var recentStationCount: Int {
        recentStationIDs.count
    }

    func selectSection(_ section: StationSection) {
        selectedSection = section
        defaults.set(section.rawValue, forKey: DefaultsKey.selectedSection)
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        favoriteStationIDs.contains(station.id)
    }

    func toggleFavorite(for station: RadioStation) {
        if favoriteStationIDs.contains(station.id) {
            favoriteStationIDs.remove(station.id)
        } else {
            favoriteStationIDs.insert(station.id)
        }

        defaults.set(Array(favoriteStationIDs).sorted(), forKey: DefaultsKey.favoriteStationIDs)
    }

    func recordRecentPlay(_ station: RadioStation) {
        recentStationIDs.removeAll { $0 == station.id }
        recentStationIDs.insert(station.id, at: 0)
        recentStationIDs = Array(recentStationIDs.prefix(20))
        defaults.set(recentStationIDs, forKey: DefaultsKey.recentStationIDs)
    }

    func removeRecentPlay(_ station: RadioStation) {
        recentStationIDs.removeAll { $0 == station.id }
        defaults.set(recentStationIDs, forKey: DefaultsKey.recentStationIDs)
    }

    func clearRecentPlays() {
        recentStationIDs.removeAll()
        defaults.set(recentStationIDs, forKey: DefaultsKey.recentStationIDs)
    }

    func pruneStoredStationState(validIDs: Set<String>) {
        let filteredFavorites = favoriteStationIDs.intersection(validIDs)
        if filteredFavorites != favoriteStationIDs {
            favoriteStationIDs = filteredFavorites
            defaults.set(Array(filteredFavorites).sorted(), forKey: DefaultsKey.favoriteStationIDs)
        }

        let filteredRecents = recentStationIDs.filter { validIDs.contains($0) }
        if filteredRecents != recentStationIDs {
            recentStationIDs = filteredRecents
            defaults.set(filteredRecents, forKey: DefaultsKey.recentStationIDs)
        }
    }

    func enforceSelectedSectionAvailability(hasFavorites: Bool, hasRecentStations: Bool) {
        switch selectedSection {
        case .favorites where !hasFavorites:
            selectedSection = .stations
        case .recent where !hasRecentStations:
            selectedSection = .stations
        default:
            break
        }

        defaults.set(selectedSection.rawValue, forKey: DefaultsKey.selectedSection)
    }

    func recentStations(from stations: [RadioStation]) -> [RadioStation] {
        let stationsByID = Dictionary(uniqueKeysWithValues: stations.map { ($0.id, $0) })
        return recentStationIDs.compactMap { stationsByID[$0] }
    }
}
