import AVFoundation
import Combine
import Foundation

@MainActor
final class PlayerService: ObservableObject {
    @Published private(set) var currentStation: RadioStation?
    @Published private(set) var playerPhase: PlayerPhase = .idle

    private let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var currentItemCancellables = Set<AnyCancellable>()
    private var activeStreamURLs: [URL] = []
    private var activeStreamIndex = 0

    init(enableObservers: Bool = true) {
        if enableObservers {
            observePlayer()
        }
    }

    var canTogglePlayback: Bool {
        currentStation != nil && player.currentItem != nil
    }

    var isPlaying: Bool {
        playerPhase == .playing
    }

    func play(_ station: RadioStation) {
        let streamURLs = station.streamURLs

        guard !streamURLs.isEmpty else {
            playerPhase = .failed("這個電台沒有可播放來源")
            return
        }

        currentStation = station
        activeStreamURLs = streamURLs
        activeStreamIndex = 0
        startPlaybackAttempt(at: 0)
    }

    func retryCurrentStation() {
        guard currentStation != nil else { return }
        startPlaybackAttempt(at: activeStreamIndex)
    }

    func togglePlayback() {
        guard canTogglePlayback else { return }

        if playerPhase == .playing || player.rate > 0 {
            pausePlayback()
        } else {
            player.play()
            playerPhase = .loading("連線中…")
        }
    }

    func pausePlayback() {
        player.pause()
        playerPhase = .paused
    }

    func previewConfigure(currentStation: RadioStation?, playerPhase: PlayerPhase) {
        self.currentStation = currentStation
        self.playerPhase = playerPhase
    }

    private func observePlayer() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                switch status {
                case .paused:
                    if case .loading = self.playerPhase {
                        break
                    }
                    if self.currentStation == nil {
                        self.playerPhase = .idle
                    } else if case .failed = self.playerPhase {
                        break
                    } else {
                        self.playerPhase = .paused
                    }
                case .waitingToPlayAtSpecifiedRate:
                    if case let .loading(message) = self.playerPhase {
                        self.playerPhase = .loading(message)
                    } else {
                        self.playerPhase = .loading("連線中…")
                    }
                case .playing:
                    self.playerPhase = .playing
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let item = notification.object as? AVPlayerItem
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self.handlePlaybackFailure(error, for: item)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let item = notification.object as? AVPlayerItem
                let error = item?.error ?? self.player.currentItem?.error
                self.handlePlaybackFailure(error, for: item)
            }
            .store(in: &cancellables)
    }

    private func startPlaybackAttempt(at index: Int) {
        guard activeStreamURLs.indices.contains(index) else {
            playerPhase = .failed("這個電台目前沒有可用的播放來源")
            return
        }

        activeStreamIndex = index

        playerPhase = .loading(Self.loadingMessage(forAttemptAt: index))

        let item = AVPlayerItem(url: activeStreamURLs[index])
        observeCurrentItem(item)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    private func observeCurrentItem(_ item: AVPlayerItem) {
        currentItemCancellables.removeAll()

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                guard item === self.player.currentItem else { return }

                if status == .failed {
                    self.handlePlaybackFailure(item.error, for: item)
                }
            }
            .store(in: &currentItemCancellables)
    }

    private func handlePlaybackFailure(_ error: Error?, for item: AVPlayerItem?) {
        if let item, item !== player.currentItem {
            return
        }

        if let fallbackIndex = Self.fallbackIndex(currentIndex: activeStreamIndex, totalCount: activeStreamURLs.count) {
            startPlaybackAttempt(at: fallbackIndex)
            return
        }

        player.pause()
        playerPhase = .failed(Self.playbackErrorMessage(from: error))
    }

    private static func playbackErrorMessage(from error: Error?) -> String {
        guard let error else {
            return "播放失敗，這個電台目前無法連線"
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "播放失敗，電台連線逾時"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "播放失敗，找不到電台伺服器"
            case .networkConnectionLost, .notConnectedToInternet:
                return "播放失敗，目前網路連線不穩定"
            case .appTransportSecurityRequiresSecureConnection:
                return "播放失敗，這個電台的串流被系統安全限制擋下"
            default:
                break
            }
        }

        let nsError = error as NSError
        let message = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            return "播放失敗，這個電台目前無法連線"
        }

        return "播放失敗：\(message)"
    }

    static func loadingMessage(forAttemptAt index: Int) -> String {
        index == 0 ? "連線中…" : "原始來源失敗，改試其他來源…"
    }

    static func fallbackIndex(currentIndex: Int, totalCount: Int) -> Int? {
        let nextIndex = currentIndex + 1
        return nextIndex < totalCount ? nextIndex : nil
    }

    static func testPlaybackErrorMessage(from error: Error?) -> String {
        playbackErrorMessage(from: error)
    }
}
