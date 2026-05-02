import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: RadioViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var stationPickerTarget: SettingsStationPickerTarget?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("設定")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("完成", systemImage: "checkmark")
                        .font(.subheadline.weight(.medium))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
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
                            stationPickerTarget = .scheduledPlay
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

                Section("定時切換電台") {
                    Toggle("啟用", isOn: Binding(
                        get: { viewModel.scheduledStationSwitchSettings.isEnabled },
                        set: { viewModel.updateScheduledStationSwitchEnabled($0) }
                    ))
                    .disabled(
                        viewModel.scheduledStationSwitchSettings.stationID == nil ||
                            viewModel.scheduledStationSwitchSettings.weekdays.isEmpty
                    )

                    DatePicker(
                        "切換時間",
                        selection: Binding(
                            get: { viewModel.scheduledStationSwitchSettings.time },
                            set: { viewModel.updateScheduledStationSwitchTime($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    WeekdaySelectionView(
                        selectedWeekdays: viewModel.scheduledStationSwitchSettings.weekdays,
                        onToggle: { weekday in
                            viewModel.toggleScheduledStationSwitchWeekday(weekday)
                        }
                    )

                    HStack {
                        Text("切換電台")
                        Spacer()
                        Button {
                            stationPickerTarget = .scheduledStationSwitch
                        } label: {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.scheduledStationSwitchStation?.displayName ?? "選擇電台")
                                    .foregroundStyle(viewModel.scheduledStationSwitchStation == nil ? .secondary : .primary)
                                if let station = viewModel.scheduledStationSwitchStation {
                                    Text(station.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.scheduledStationSwitchSettings.stationID == nil {
                        Text("要先選電台，才可以開啟定時切換。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if viewModel.scheduledStationSwitchSettings.weekdays.isEmpty {
                        Text("至少選一天，才可以開啟定時切換。")
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
        .frame(minWidth: 520, minHeight: 520)
        .sheet(item: $stationPickerTarget) { target in
            StationPickerSheet(
                stations: viewModel.stations,
                selectedStationID: selectedStationID(for: target),
                onSelect: { station in
                    updateStation(station, for: target)
                    stationPickerTarget = nil
                }
            )
        }
    }

    private func selectedStationID(for target: SettingsStationPickerTarget) -> String? {
        switch target {
        case .scheduledPlay:
            return viewModel.scheduledPlaySettings.stationID
        case .scheduledStationSwitch:
            return viewModel.scheduledStationSwitchSettings.stationID
        }
    }

    private func updateStation(_ station: RadioStation, for target: SettingsStationPickerTarget) {
        switch target {
        case .scheduledPlay:
            viewModel.updateScheduledPlayStation(station)
        case .scheduledStationSwitch:
            viewModel.updateScheduledStationSwitchStation(station)
        }
    }
}

private enum SettingsStationPickerTarget: Identifiable {
    case scheduledPlay
    case scheduledStationSwitch

    var id: String {
        switch self {
        case .scheduledPlay:
            return "scheduledPlay"
        case .scheduledStationSwitch:
            return "scheduledStationSwitch"
        }
    }
}

private struct WeekdaySelectionView: View {
    let selectedWeekdays: Set<ScheduledWeekday>
    let onToggle: (ScheduledWeekday) -> Void

    var body: some View {
        HStack {
            Text("星期")

            Spacer()

            HStack(spacing: 4) {
                ForEach(ScheduledWeekday.displayOrder) { weekday in
                    Button {
                        onToggle(weekday)
                    } label: {
                        Text(weekday.shortTitle)
                            .font(.caption.weight(.medium))
                            .frame(width: 26, height: 26)
                            .foregroundStyle(selectedWeekdays.contains(weekday) ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selectedWeekdays.contains(weekday) ? Color.accentColor : Color.secondary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
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
