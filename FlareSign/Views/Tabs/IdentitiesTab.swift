import SwiftUI

struct IdentitiesTab: View {
    @Environment(AppState.self) private var appState
    @State private var showAddIdentity = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Identities")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.rfOnSurface)
                    Spacer()
                    Button { showAddIdentity = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.rfPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.identities, id: \.publicKeyHex) { identity in
                            IdentityCard(
                                identity: identity,
                                isSelected: identity.publicKeyHex == appState.selectedIdentity?.publicKeyHex
                            )
                            .onTapGesture {
                                appState.selectedIdentity = identity
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.rfSurface)
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddIdentity) {
                AddIdentitySheet()
            }
        }
    }
}

struct IdentityCard: View {
    let identity: Identity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isSelected {
                FlareIndicator()
                    .frame(height: 48)
                    .padding(.trailing, 12)
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.rfPrimary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: identity.isPasskeyDerived ? "person.badge.key.fill" : "key.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.rfPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.label)
                        .font(RFFont.title(16))
                        .foregroundColor(Color.rfOnSurface)
                    Text(identity.npub.prefix(20) + "...")
                        .font(RFFont.mono(11))
                        .foregroundColor(Color.rfOffline)
                }

                Spacer()

                if !identity.connectedApps.isEmpty {
                    Text("\(identity.connectedApps.count)")
                        .font(RFFont.caption(12))
                        .foregroundColor(Color.rfOnSurfaceVariant)
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.caption)
                        .foregroundColor(Color.rfOffline)
                }
            }
            .padding(16)
            .background(Color.rfSurfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
