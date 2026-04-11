import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RadioViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingStation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("設定")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button("完成") {
                    dismiss()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Form {
                Section("定時播放") {
                    Toggle("啟用", isOn: Binding(
                        get: { viewModel.scheduledPlaySettings.isEnabled },
                        set: { viewModel.updateScheduledPlayEnabled($0) }
                    ))
                    .disabled(viewModel.scheduledPlaySettings.stationID == nil)

                    DatePicker(
                        "播放時間",
                        selection: Binding(
                            get: { viewModel.scheduledPlaySettings.time },
                            set: { viewModel.updateScheduledPlayTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    HStack {
                        Text("播放電台")
                        Spacer()
                        Button {
                            isPickingStation = true
                        } label: {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.scheduledPlayStation?.displayName ?? "選擇電台")
                                    .foregroundStyle(viewModel.scheduledPlayStation == nil ? .secondary : .primary)
                                if let station = viewModel.scheduledPlayStation {
                                    Text(station.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.scheduledPlaySettings.stationID == nil {
                        Text("要先選電台，才可以開啟定時播放。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("定時停止播放") {
                    Toggle("啟用", isOn: Binding(
                        get: { viewModel.scheduledStopSettings.isEnabled },
                        set: { viewModel.updateScheduledStopEnabled($0) }
                    ))

                    DatePicker(
                        "停止時間",
                        selection: Binding(
                            get: { viewModel.scheduledStopSettings.time },
                            set: { viewModel.updateScheduledStopTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    Text("每天到這個時間，如果目前有在播放，就會自動暫停。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 520, minHeight: 420)
        .sheet(isPresented: $isPickingStation) {
            StationPickerSheet(
                stations: viewModel.stations,
                selectedStationID: viewModel.scheduledPlaySettings.stationID,
                onSelect: { station in
                    viewModel.updateScheduledPlayStation(station)
                    isPickingStation = false
                }
            )
        }
    }
}

private struct StationPickerSheet: View {
    let stations: [RadioStation]
    let selectedStationID: String?
    let onSelect: (RadioStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filteredStations) { station in
                Button {
                    onSelect(station)
                } label: {
                    StationPickerRow(
                        station: station,
                        isSelected: station.id == selectedStationID
                    )
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("選擇電台")
            .searchable(text: $query, prompt: "搜尋電台")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 500)
    }

    private var filteredStations: [RadioStation] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return stations
        }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return stations.filter { station in
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
}

private struct StationPickerRow: View {
    let station: RadioStation
    let isSelected: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName)
                    .foregroundStyle(.primary)
                Text(station.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.secondary.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
