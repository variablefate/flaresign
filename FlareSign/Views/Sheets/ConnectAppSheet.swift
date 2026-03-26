import SwiftUI

struct ConnectAppSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var pasteText = ""
    @State private var parsedParams: NostrConnectParams?
    @State private var errorMessage: String?
    @State private var showScanner = false

    var body: some View {
        ZStack {
            Color.rfSurface.ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 24) {
                    // Scan QR button
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(RFPrimaryButtonStyle())

                    Text("or paste a nostrconnect:// URI")
                        .font(RFFont.caption())
                        .foregroundColor(Color.rfOnSurfaceVariant)

                    // Manual paste
                    TextField("nostrconnect://...", text: $pasteText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(RFFont.mono(12))
                        .padding(12)
                        .background(Color.rfSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(Color.rfOnSurface)
                        .onChange(of: pasteText) {
                            parseURI(pasteText)
                        }

                    // Parsed result
                    if let params = parsedParams {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel("Connection Request")
                            VStack(alignment: .leading, spacing: 8) {
                                if let name = params.name {
                                    HStack {
                                        Text("App:")
                                            .font(RFFont.caption())
                                            .foregroundColor(Color.rfOffline)
                                        Text(name)
                                            .font(RFFont.body(14))
                                            .foregroundColor(Color.rfOnSurface)
                                    }
                                }
                                HStack {
                                    Text("Relays:")
                                        .font(RFFont.caption())
                                        .foregroundColor(Color.rfOffline)
                                    Text(params.relays.joined(separator: ", "))
                                        .font(RFFont.mono(11))
                                        .foregroundColor(Color.rfOnSurfaceVariant)
                                        .lineLimit(2)
                                }
                                if !params.permissions.isEmpty {
                                    HStack {
                                        Text("Permissions:")
                                            .font(RFFont.caption())
                                            .foregroundColor(Color.rfOffline)
                                        Text(params.permissions.joined(separator: ", "))
                                            .font(RFFont.caption(12))
                                            .foregroundColor(Color.rfOnSurfaceVariant)
                                    }
                                }
                            }
                            .rfCard(.low)

                            Button("Approve Connection") {
                                approveConnection(params)
                            }
                            .buttonStyle(RFPrimaryButtonStyle())
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(RFFont.caption())
                            .foregroundColor(Color.rfError)
                    }

                    Spacer()
                }
                .padding(24)
                .navigationTitle("Connect App")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.rfSurface, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(Color.rfOnSurfaceVariant)
                    }
                }
            }
        }
    }

    private func parseURI(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let params = NIP46URIParser.parseNostrConnect(trimmed) {
            parsedParams = params
            errorMessage = nil
        } else if !trimmed.isEmpty && trimmed.contains("nostrconnect://") {
            errorMessage = "Invalid nostrconnect:// URI"
            parsedParams = nil
        } else {
            parsedParams = nil
            errorMessage = nil
        }
    }

    private func approveConnection(_ params: NostrConnectParams) {
        // TODO: Create ConnectedApp, add session to NIP46Service, send connect response
        dismiss()
    }
}
