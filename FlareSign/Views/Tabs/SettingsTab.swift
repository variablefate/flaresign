import SwiftUI

struct SettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.rfOnSurface)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        // Relay configuration
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("Relays")
                            VStack(spacing: 0) {
                                SettingsRow(icon: "antenna.radiowaves.left.and.right", label: "relay.damus.io")
                                SettingsRow(icon: "antenna.radiowaves.left.and.right", label: "nos.lol")
                                SettingsRow(icon: "antenna.radiowaves.left.and.right", label: "relay.primal.net")
                            }
                            .background(Color.rfSurfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // About
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("About")
                            VStack(spacing: 0) {
                                SettingsRow(icon: "info.circle", label: "Version", value: "0.1.0")
                                SettingsRow(icon: "lock.shield", label: "Privacy Policy")
                                SettingsRow(icon: "doc.text", label: "Terms of Service")
                            }
                            .background(Color.rfSurfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.rfSurface)
            .navigationBarHidden(true)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    var value: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(Color.rfPrimary)
            Text(label)
                .font(RFFont.body(15))
                .foregroundColor(Color.rfOnSurface)
            Spacer()
            if let value {
                Text(value)
                    .font(RFFont.body(14))
                    .foregroundColor(Color.rfOnSurfaceVariant)
            }
        }
        .padding(16)
    }
}
