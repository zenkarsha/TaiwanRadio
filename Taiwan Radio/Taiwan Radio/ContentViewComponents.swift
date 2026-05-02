import SwiftUI

struct SectionPickerView: View {
    @ObservedObject var viewModel: RadioViewModel

    var body: some View {
        Picker("", selection: Binding(
            get: { viewModel.selectedSection },
            set: { viewModel.selectSection($0) }
        )) {
            ForEach(StationSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

struct StationListView: View {
    @ObservedObject var viewModel: RadioViewModel

    var body: some View {
        Group {
            if viewModel.isFetching && viewModel.stations.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在抓取台灣電台…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fetchError = viewModel.fetchError, viewModel.stations.isEmpty {
                ContentUnavailableView {
                    Label("載入失敗", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(fetchError)
                } actions: {
                    Button("重新載入") {
                        Task {
                            await viewModel.fetchStations()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredStations, selection: .constant(viewModel.currentStation?.id)) { station in
                    StationRow(
                        station: station,
                        isActive: station.id == viewModel.currentStation?.id,
                        isFavorite: viewModel.isFavorite(station),
                        showsRecentDelete: viewModel.selectedSection == .recent,
                        onPlay: {
                            viewModel.play(station)
                        },
                        onToggleFavorite: {
                            viewModel.toggleFavorite(for: station)
                        },
                        onDeleteRecent: {
                            viewModel.removeRecentPlay(station)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 6, bottom: 10, trailing: 6))
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.query, prompt: "搜尋電台")
                .overlay(alignment: .center) {
                    if viewModel.filteredStations.isEmpty {
                        StationListEmptyStateView(viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct RecentActionsBarView: View {
    @ObservedObject var viewModel: RadioViewModel

    var body: some View {
        if viewModel.selectedSection == .recent, viewModel.hasRecentStations {
            HStack {
                Text("最近播放 \(viewModel.recentStationCount) 筆")
                    .font(.subheadline)

                Spacer()

                Button("清除全部") {
                    viewModel.clearRecentPlays()
                }
                .buttonStyle(.link)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }
}

struct PlayerBarView: View {
    @ObservedObject var viewModel: RadioViewModel
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canTogglePlayback)
            .opacity(viewModel.canTogglePlayback ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.currentStation?.displayName ?? "尚未選擇電台")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if case .loading = viewModel.playerPhase {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(viewModel.playerPhase.title)
                        .font(.subheadline)
                        .foregroundStyle(playerStateColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            if showsRetryButton {
                Button {
                    viewModel.retryCurrentStation()
                } label: {
                    Label("重試", systemImage: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(.red)
                        .background(Color.red.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                onOpenSettings()
            } label: {
                Label("設定", systemImage: "gearshape")
                    .font(.body.weight(.medium))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var playerStateColor: Color {
        switch viewModel.playerPhase {
        case .idle:
            return .secondary
        case .loading:
            return .orange
        case .paused:
            return .secondary
        case .playing:
            return .green
        case .failed:
            return .red
        }
    }

    private var showsRetryButton: Bool {
        if case .failed = viewModel.playerPhase {
            true
        } else {
            false
        }
    }
}

struct StationListEmptyStateView: View {
    @ObservedObject var viewModel: RadioViewModel

    var body: some View {
        if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            switch viewModel.selectedSection {
            case .favorites:
                ContentUnavailableView {
                    Label("還沒有收藏", systemImage: "heart")
                } description: {
                    Text("點右側愛心，把常聽電台收進來。")
                }
            case .recent:
                ContentUnavailableView {
                    Label("還沒有最近播放", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("播放過的電台會自動出現在這裡。")
                }
            case .hot:
                ContentUnavailableView {
                    Label("還沒有熱門電台", systemImage: "flame")
                } description: {
                    Text("載入完成後，這裡會依投票數顯示熱門電台。")
                }
            case .stations:
                ContentUnavailableView.search
            }
        }
    }
}
