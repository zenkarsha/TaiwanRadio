import Combine
import Foundation

@MainActor
final class RadioViewModel: ObservableObject {
    @Published var stations: [RadioStation] = []
    @Published var isFetching = false
    @Published var fetchError: String?
    @Published var query = ""

    private let stationService: StationService
    private let playerService: PlayerService
    private let scheduleService: ScheduleService
    private let libraryStore: LibraryStore
    private var cancellables = Set<AnyCancellable>()

    init(
        defaults: UserDefaults = .standard,
        stationService: StationService = StationService(),
        playerService: PlayerService? = nil,
        scheduleService: ScheduleService? = nil,
        enableRuntimeObservers: Bool = true
    ) {
        self.stationService = stationService
        self.playerService = playerService ?? PlayerService(enableObservers: enableRuntimeObservers)
        self.scheduleService = scheduleService ?? ScheduleService(defaults: defaults)
        libraryStore = LibraryStore(defaults: defaults)

        bindServices()
        if enableRuntimeObservers {
            observeSchedules()
        }
        libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
        self.scheduleService.sanitizeSchedules(using: stations)
    }

    var selectedSection: StationSection {
        libraryStore.selectedSection
    }

    var favoriteStationIDs: Set<String> {
        libraryStore.favoriteStationIDs
    }

    var recentStationIDs: [String] {
        libraryStore.recentStationIDs
    }

    var canTogglePlayback: Bool {
        playerService.canTogglePlayback
    }

    var isPlaying: Bool {
        playerService.isPlaying
    }

    var currentStation: RadioStation? {
        playerService.currentStation
    }

    var playerPhase: PlayerPhase {
        playerService.playerPhase
    }

    var hasFavorites: Bool {
        !libraryStore.favoriteStationIDs.isEmpty
    }

    var hasRecentStations: Bool {
        !recentStations.isEmpty
    }

    var recentStationCount: Int {
        libraryStore.recentStationCount
    }

    var scheduledPlaySettings: ScheduledPlaySettings {
        scheduleService.scheduledPlaySettings
    }

    var scheduledStopSettings: ScheduledStopSettings {
        scheduleService.scheduledStopSettings
    }

    var filteredStations: [RadioStation] {
        let searchableStations = stationsForSelectedSection

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return searchableStations
        }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return searchableStations.filter { station in
            let haystacks = [
                station.displayName,
                station.tags ?? "",
                station.language ?? "",
                station.codec ?? ""
            ]

            return haystacks.contains {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalizedQuery)
            }
        }
    }

    var scheduledPlayStation: RadioStation? {
        scheduleService.scheduledPlayStation(from: stations)
    }

    func fetchStations() async {
        guard !isFetching else { return }

        isFetching = true
        fetchError = nil

        defer { isFetching = false }

        do {
            stations = try await stationService.fetchStations()
            libraryStore.pruneStoredStationState(validIDs: Set(stations.map(\.id)))
            libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
            scheduleService.sanitizeSchedules(using: stations)
        } catch {
            fetchError = stationService.errorMessage(for: error)
        }
    }

    func selectSection(_ section: StationSection) {
        libraryStore.selectSection(section)
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        libraryStore.isFavorite(station)
    }

    func toggleFavorite(for station: RadioStation) {
        libraryStore.toggleFavorite(for: station)
        libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
    }

    func play(_ station: RadioStation) {
        guard !station.streamURLs.isEmpty else {
            playerService.play(station)
            return
        }

        libraryStore.recordRecentPlay(station)
        libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
        playerService.play(station)
    }

    func retryCurrentStation() {
        playerService.retryCurrentStation()
    }

    func togglePlayback() {
        playerService.togglePlayback()
    }

    func updateScheduledPlayEnabled(_ isEnabled: Bool) {
        scheduleService.updateScheduledPlayEnabled(isEnabled)
    }

    func updateScheduledPlayTime(_ time: Date) {
        scheduleService.updateScheduledPlayTime(time)
    }

    func updateScheduledPlayStation(_ station: RadioStation?) {
        scheduleService.updateScheduledPlayStation(station)
    }

    func updateScheduledStopEnabled(_ isEnabled: Bool) {
        scheduleService.updateScheduledStopEnabled(isEnabled)
    }

    func updateScheduledStopTime(_ time: Date) {
        scheduleService.updateScheduledStopTime(time)
    }

    func removeRecentPlay(_ station: RadioStation) {
        libraryStore.removeRecentPlay(station)
        libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
    }

    func clearRecentPlays() {
        libraryStore.clearRecentPlays()
        libraryStore.enforceSelectedSectionAvailability(hasFavorites: hasFavorites, hasRecentStations: hasRecentStations)
    }

    private var recentStations: [RadioStation] {
        libraryStore.recentStations(from: stations)
    }

    private var stationsForSelectedSection: [RadioStation] {
        switch selectedSection {
        case .favorites:
            return stations.filter { libraryStore.favoriteStationIDs.contains($0.id) }
        case .recent:
            return recentStations
        case .hot:
            return stationService.hotStations(from: stations)
        case .stations:
            return stations
        }
    }

    private func bindServices() {
        playerService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        scheduleService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        libraryStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func observeSchedules() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.processSchedules(at: now)
            }
            .store(in: &cancellables)
    }

    private func processSchedules(at now: Date) {
        scheduleService.processSchedules(
            at: now,
            stations: stations,
            onPlay: { [weak self] station in
                self?.play(station)
            },
            onStop: { [weak self] in
                guard let self, self.currentStation != nil, self.canTogglePlayback else { return }
                self.playerService.pausePlayback()
            }
        )
    }

    static func preview() -> RadioViewModel {
        let defaults = UserDefaults(suiteName: "TaiwanRadioPreview.\(UUID().uuidString)") ?? .standard
        let playerService = PlayerService(enableObservers: false)
        let scheduleService = ScheduleService(defaults: defaults)
        let viewModel = RadioViewModel(
            defaults: defaults,
            playerService: playerService,
            scheduleService: scheduleService,
            enableRuntimeObservers: false
        )
        let stations = [
            RadioStation(
                stationUUID: "preview-1",
                name: "ICRT Taipei",
                favicon: nil,
                url: "https://example.com/live-1",
                urlResolved: "https://example.com/live-1",
                tags: "english,pop",
                language: "English",
                country: "Taiwan",
                codec: "aac",
                bitrate: 128,
                votes: 100
            ),
            RadioStation(
                stationUUID: "preview-2",
                name: "寶島新聲",
                favicon: nil,
                url: "https://example.com/live-2",
                urlResolved: "https://example.com/live-2",
                tags: "talk,news",
                language: "Chinese",
                country: "Taiwan",
                codec: "mp3",
                bitrate: 96,
                votes: 80
            ),
            RadioStation(
                stationUUID: "preview-3",
                name: "警廣",
                favicon: nil,
                url: "https://example.com/live-3",
                urlResolved: "https://example.com/live-3",
                tags: "traffic,public",
                language: "Chinese",
                country: "Taiwan",
                codec: "aac",
                bitrate: 64,
                votes: 70
            )
        ]

        viewModel.stations = stations
        viewModel.libraryStore.toggleFavorite(for: stations[0])
        viewModel.libraryStore.toggleFavorite(for: stations[1])
        viewModel.libraryStore.recordRecentPlay(stations[0])
        viewModel.libraryStore.recordRecentPlay(stations[1])
        playerService.previewConfigure(currentStation: stations[0], playerPhase: .playing)
        scheduleService.previewConfigure(
            play: ScheduledPlaySettings(
                isEnabled: true,
                time: Date(),
                stationID: stations[1].id
            ),
            stop: ScheduledStopSettings(
                isEnabled: true,
                time: Date()
            )
        )
        return viewModel
    }
}
