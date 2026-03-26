import SwiftUI

struct AppsTab: View {
    @Environment(AppState.self) private var appState
    @State private var showConnectApp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Apps")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.rfOnSurface)
                    Spacer()
                    Button { showConnectApp = true } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(Color.rfPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if appState.connectedApps.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "app.badge")
                            .font(.system(size: 48))
                            .foregroundColor(Color.rfOffline)
                        Text("No apps connected")
                            .font(RFFont.title(18))
                            .foregroundColor(Color.rfOnSurfaceVariant)
                        Text("Scan a QR code from a Nostr app to connect")
                            .font(RFFont.body(14))
                            .foregroundColor(Color.rfOffline)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.connectedApps, id: \.id) { app in
                                AppCard(app: app)
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
            .sheet(isPresented: $showConnectApp) {
                ConnectAppSheet()
            }
        }
    }
}

struct AppCard: View {
    let app: ConnectedApp

    var body: some View {
        HStack(spacing: 0) {
            FlareIndicator()
                .frame(height: 48)
                .padding(.trailing, 12)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rfSurfaceContainerHigh)
                        .frame(width: 48, height: 48)
                    Text(String(app.name.prefix(1)).uppercased())
                        .font(RFFont.title(20))
                        .foregroundColor(Color.rfPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(RFFont.title(16))
                        .foregroundColor(Color.rfOnSurface)
                    Text("Last used \(app.lastUsedAt.formatted(.relative(presentation: .named)))")
                        .font(RFFont.caption(12))
                        .foregroundColor(Color.rfOffline)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.rfOffline)
            }
            .padding(16)
            .background(Color.rfSurfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
