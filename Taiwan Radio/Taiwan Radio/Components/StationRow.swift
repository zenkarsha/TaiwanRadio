import SwiftUI

struct StationRow: View {
    let station: RadioStation
    let isActive: Bool
    let isFavorite: Bool
    let showsRecentDelete: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onDeleteRecent: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isActive ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))

                        Image(systemName: isActive ? "dot.radiowaves.left.and.right" : "radio")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(station.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    if isActive {
                        Text("LIVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.14), in: Capsule())
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavorite ? .red : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isFavorite ? Color.red.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)

            if showsRecentDelete {
                Button(action: onDeleteRecent) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .help("刪除這筆最近播放")
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        )
    }
}
