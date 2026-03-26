import SwiftUI

struct ShareConnectionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var copiedURI = false

    var body: some View {
        ZStack {
            Color.rfSurface.ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 24) {
                    if let identity = appState.selectedIdentity {
                        let bunkerURI = NIP46URIParser.generateBunkerURI(
                            signerPubkey: identity.publicKeyHex,
                            relays: ["wss://relay.damus.io", "wss://nos.lol", "wss://relay.primal.net"]
                        )

                        Text("Share this with a Nostr app to connect")
                            .font(RFFont.body(14))
                            .foregroundColor(Color.rfOnSurfaceVariant)
                            .multilineTextAlignment(.center)

                        // URI display
                        Text(bunkerURI)
                            .font(RFFont.mono(10))
                            .foregroundColor(Color.rfOffline)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.rfSurfaceContainerLow)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .lineLimit(4)

                        // Copy button
                        Button {
                            UIPasteboard.general.string = bunkerURI
                            copiedURI = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copiedURI = false
                            }
                        } label: {
                            Label(copiedURI ? "Copied" : "Copy URI", systemImage: copiedURI ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(RFSecondaryButtonStyle())

                        Text("Identity: \(identity.label)")
                            .font(RFFont.caption(12))
                            .foregroundColor(Color.rfOffline)
                    } else {
                        Text("No identity selected")
                            .font(RFFont.body(14))
                            .foregroundColor(Color.rfOffline)
                    }

                    Spacer()
                }
                .padding(24)
                .navigationTitle("Share Connection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.rfSurface, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundColor(Color.rfPrimary)
                    }
                }
            }
        }
    }
}
