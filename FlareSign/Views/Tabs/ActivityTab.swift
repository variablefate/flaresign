import SwiftUI
import SwiftData

struct ActivityTab: View {
    @Query(sort: \ActivityLogEntry.timestamp, order: .reverse)
    private var entries: [ActivityLogEntry]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Activity")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.rfOnSurface)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if entries.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(Color.rfOffline)
                        Text("No activity yet")
                            .font(RFFont.title(18))
                            .foregroundColor(Color.rfOnSurfaceVariant)
                        Text("Signing requests from connected apps will appear here")
                            .font(RFFont.body(14))
                            .foregroundColor(Color.rfOffline)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                ActivityRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color.rfSurface)
            .navigationBarHidden(true)
        }
    }
}

struct ActivityRow: View {
    let entry: ActivityLogEntry

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: entry.approved ? .approved : .denied)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.appName)
                        .font(RFFont.title(14))
                        .foregroundColor(Color.rfOnSurface)
                    Spacer()
                    Text(entry.timestamp.formatted(.relative(presentation: .named)))
                        .font(RFFont.caption(11))
                        .foregroundColor(Color.rfOffline)
                }

                HStack(spacing: 4) {
                    Text(entry.method == "sign_event" && entry.kind != nil
                         ? EventKindLabel.name(for: entry.kind!)
                         : entry.method)
                        .font(RFFont.caption(12))
                        .foregroundColor(Color.rfOnSurfaceVariant)

                    if let preview = entry.eventPreview, !preview.isEmpty {
                        Text("— \(preview)")
                            .font(RFFont.caption(12))
                            .foregroundColor(Color.rfOffline)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.rfSurfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
