//
//  Taiwan_RadioTests.swift
//  Taiwan RadioTests
//
//  Created by marc huang on 2026/4/10.
//

import Foundation
import Testing
@testable import Taiwan_Radio

@MainActor
struct Taiwan_RadioTests {
    @Test func 資料庫store會記住收藏最近播放和tab() {
        let defaults = makeDefaults(testName: #function)
        let store = LibraryStore(defaults: defaults)
        let stationA = makeStation(id: "a", name: "Alpha", votes: 10)
        let stationB = makeStation(id: "b", name: "Bravo", votes: 20)

        store.toggleFavorite(for: stationA)
        store.recordRecentPlay(stationA)
        store.recordRecentPlay(stationB)
        store.selectSection(.recent)

        let restored = LibraryStore(defaults: defaults)

        #expect(restored.favoriteStationIDs == [stationA.id])
        #expect(restored.recentStationIDs == [stationB.id, stationA.id])
        #expect(restored.selectedSection == .recent)
    }

    @Test func 資料庫store在空收藏或空最近播放時會回到所有電台() {
        let store = LibraryStore(defaults: makeDefaults(testName: #function))

        store.selectSection(.favorites)
        store.enforceSelectedSectionAvailability(hasFavorites: false, hasRecentStations: true)
        #expect(store.selectedSection == .stations)

        store.selectSection(.recent)
        store.enforceSelectedSectionAvailability(hasFavorites: true, hasRecentStations: false)
        #expect(store.selectedSection == .stations)
    }

    @Test func 資料庫store會修剪不存在的收藏與最近播放() {
        let store = LibraryStore(defaults: makeDefaults(testName: #function))
        let stationA = makeStation(id: "a", name: "Alpha", votes: 10)
        let stationB = makeStation(id: "b", name: "Bravo", votes: 20)

        store.toggleFavorite(for: stationA)
        store.toggleFavorite(for: stationB)
        store.recordRecentPlay(stationA)
        store.recordRecentPlay(stationB)
        store.pruneStoredStationState(validIDs: [stationA.id])

        #expect(store.favoriteStationIDs == [stationA.id])
        #expect(store.recentStationIDs == [stationA.id])
    }

    @Test func 電台服務可依名稱反序排序() {
        let service = StationService()
        let stations = [
            makeStation(id: "a", name: "Bravo", votes: 2),
            makeStation(id: "b", name: "Alpha", votes: 3),
            makeStation(id: "c", name: "Charlie", votes: 1)
        ]

        let result = service.sortedStations(stations)

        #expect(result.map(\.displayName) == ["Charlie", "Bravo", "Alpha"])
    }

    @Test func 熱門電台依票數排序且只取前30筆() {
        let service = StationService()
        let result = service.hotStations(from: makeStationsForHotRanking())

        #expect(result.count == 30)
        #expect(result.first?.displayName == "Station 35")
        #expect(result[1].displayName == "Station 34")
        #expect(result.last?.displayName == "Station 6")
        #expect(result.allSatisfy { ($0.votes ?? 0) >= 6 })
    }

    @Test func 電台服務錯誤訊息會映射節點連線失敗() {
        let service = StationService()

        #expect(service.errorMessage(for: URLError(.cannotFindHost)) == "目前無法連上 Radio Browser 節點，已嘗試多個伺服器。")
    }

    @Test func 最近播放會去重並保留最新順序() {
        let viewModel = makeViewModel()
        let stationA = makeStation(id: "a", name: "Alpha", votes: 10)
        let stationB = makeStation(id: "b", name: "Bravo", votes: 20)
        let stationC = makeStation(id: "c", name: "Charlie", votes: 30)

        viewModel.stations = [stationA, stationB, stationC]
        viewModel.play(stationA)
        viewModel.play(stationB)
        viewModel.play(stationA)
        viewModel.play(stationC)

        #expect(viewModel.recentStationIDs == ["c", "a", "b"])

        viewModel.selectSection(.recent)
        #expect(viewModel.filteredStations.map(\.id) == ["c", "a", "b"])
    }

    @Test func 定時播放同一分鐘只觸發一次() {
        let defaults = makeDefaults(testName: #function)
        let service = ScheduleService(defaults: defaults)
        let station = makeStation(id: "alarm", name: "Alarm", votes: 99)
        let time = makeTime(hour: 7, minute: 30)

        service.updateScheduledPlayStation(station)
        service.updateScheduledPlayTime(time)
        service.updateScheduledPlayEnabled(true)

        var playCount = 0
        let now = makeDate(year: 2026, month: 4, day: 10, hour: 7, minute: 30)

        service.processSchedules(
            at: now,
            stations: [station],
            onPlay: { _ in playCount += 1 },
            onStop: {}
        )
        service.processSchedules(
            at: now,
            stations: [station],
            onPlay: { _ in playCount += 1 },
            onStop: {}
        )

        #expect(playCount == 1)
    }

    @Test func 定時停止播放到點會觸發() {
        let defaults = makeDefaults(testName: #function)
        let service = ScheduleService(defaults: defaults)
        let time = makeTime(hour: 23, minute: 45)

        service.updateScheduledStopTime(time)
        service.updateScheduledStopEnabled(true)

        var stopCount = 0
        service.processSchedules(
            at: makeDate(year: 2026, month: 4, day: 10, hour: 23, minute: 45),
            stations: [],
            onPlay: { _ in },
            onStop: { stopCount += 1 }
        )

        #expect(stopCount == 1)
    }

    @Test func 定時播放選到不存在的電台會自動清空並停用() {
        let defaults = makeDefaults(testName: #function)
        let service = ScheduleService(defaults: defaults)
        let station = makeStation(id: "alarm", name: "Alarm", votes: 99)

        service.updateScheduledPlayStation(station)
        service.updateScheduledPlayEnabled(true)
        service.sanitizeSchedules(using: [])

        #expect(service.scheduledPlaySettings.stationID == nil)
        #expect(service.scheduledPlaySettings.isEnabled == false)
    }

    @Test func 重開後定時播放設定在電台載入前仍會保留() {
        let defaults = makeDefaults(testName: #function)
        let station = makeStation(id: "alarm", name: "Alarm", votes: 99)
        let persistedScheduleService = ScheduleService(defaults: defaults)

        persistedScheduleService.updateScheduledPlayStation(station)
        persistedScheduleService.updateScheduledPlayEnabled(true)

        let restoredViewModel = RadioViewModel(
            defaults: defaults,
            playerService: PlayerService(enableObservers: false),
            scheduleService: ScheduleService(defaults: defaults),
            enableRuntimeObservers: false
        )

        #expect(restoredViewModel.scheduledPlaySettings.stationID == station.id)
        #expect(restoredViewModel.scheduledPlaySettings.isEnabled == true)
    }

    @Test func 電台串流來源只保留有效且去重的http網址() {
        let station = RadioStation(
            stationUUID: "stream-test",
            name: "Stream Test",
            favicon: nil,
            url: " https://example.com/live ",
            urlResolved: "https://example.com/live",
            tags: nil,
            language: nil,
            country: nil,
            codec: nil,
            bitrate: nil,
            votes: nil
        )

        #expect(station.streamURLs.map(\.absoluteString) == ["https://example.com/live"])
    }

    @Test func 播放器fallback索引會正確切到下一個來源() {
        #expect(PlayerService.fallbackIndex(currentIndex: 0, totalCount: 2) == 1)
        #expect(PlayerService.fallbackIndex(currentIndex: 1, totalCount: 2) == nil)
        #expect(PlayerService.fallbackIndex(currentIndex: 0, totalCount: 1) == nil)
    }

    @Test func 播放器loading訊息會依嘗試次數切換() {
        #expect(PlayerService.loadingMessage(forAttemptAt: 0) == "連線中…")
        #expect(PlayerService.loadingMessage(forAttemptAt: 1) == "原始來源失敗，改試其他來源…")
    }

    @Test func 播放器錯誤訊息會映射逾時與安全限制() {
        #expect(PlayerService.testPlaybackErrorMessage(from: URLError(.timedOut)) == "播放失敗，電台連線逾時")
        #expect(PlayerService.testPlaybackErrorMessage(from: URLError(.appTransportSecurityRequiresSecureConnection)) == "播放失敗，這個電台的串流被系統安全限制擋下")
    }

    @Test func 播放器錯誤訊息會保留系統描述() {
        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server exploded"])

        #expect(PlayerService.testPlaybackErrorMessage(from: error) == "播放失敗：Server exploded")
    }
}

@MainActor
private func makeViewModel(testName: String = #function) -> RadioViewModel {
    let defaults = makeDefaults(testName: testName)
    let playerService = PlayerService(enableObservers: false)
    let scheduleService = ScheduleService(defaults: defaults)

    return RadioViewModel(
        defaults: defaults,
        playerService: playerService,
        scheduleService: scheduleService,
        enableRuntimeObservers: false
    )
}

@MainActor
private func makeDefaults(testName: String) -> UserDefaults {
    let suiteName = "TaiwanRadioTests.\(testName).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@MainActor
private func makeStationsForHotRanking() -> [RadioStation] {
    (1...35).map { index in
        makeStation(
            id: "station-\(index)",
            name: "Station \(index)",
            votes: index
        )
    }
}

@MainActor
private func makeStation(id: String, name: String, votes: Int) -> RadioStation {
    RadioStation(
        stationUUID: id,
        name: name,
        favicon: nil,
        url: "https://example.com/\(id)",
        urlResolved: "https://example.com/\(id)",
        tags: "test",
        language: "Chinese",
        country: "Taiwan",
        codec: "aac",
        bitrate: 128,
        votes: votes
    )
}

private func makeTime(hour: Int, minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(hour: hour, minute: minute))!
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
