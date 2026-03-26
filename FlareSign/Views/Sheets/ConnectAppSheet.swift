import SwiftUI

struct ConnectAppSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var pasteText = ""
    @State private var parsedParams: NostrConnectParams?
    @State private var errorMessage: String?
    @State private var showScanner = false
    @State private var selectedIdentity: Identity?
    @State private var isConnecting = false

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

                            // Identity picker (only if multiple identities)
                            if appState.identities.count > 1 {
                                SectionLabel("Sign as")
                                Picker("Identity", selection: $selectedIdentity) {
                                    ForEach(appState.identities, id: \.publicKeyHex) { identity in
                                        Text(identity.label).tag(Optional(identity))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.rfPrimary)
                            }

                            Button {
                                approveConnection(params)
                            } label: {
                                if isConnecting {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Approve Connection")
                                }
                            }
                            .buttonStyle(RFPrimaryButtonStyle())
                            .disabled(isConnecting)
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
                .onAppear {
                    selectedIdentity = appState.selectedIdentity ?? appState.identities.first
                }
                .fullScreenCover(isPresented: $showScanner) {
                    ZStack {
                        Color.rfSurface.ignoresSafeArea()
                        VStack(spacing: 0) {
                            HStack {
                                Button("Cancel") { showScanner = false }
                                    .font(RFFont.title(16))
                                    .foregroundColor(Color.rfPrimary)
                                Spacer()
                                Text("Scan QR Code")
                                    .font(RFFont.title(16))
                                    .foregroundColor(Color.rfOnSurface)
                                Spacer()
                                // Balance the cancel button
                                Text("Cancel").opacity(0)
                                    .font(RFFont.title(16))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            QRScannerView { scannedCode in
                                showScanner = false
                                pasteText = scannedCode
                                parseURI(scannedCode)
                            }
                        }
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
        guard !isConnecting else { return }
        let identity = selectedIdentity ?? appState.selectedIdentity ?? appState.identities.first
        guard let identity else { return }
        isConnecting = true
        Task {
            await appState.approveConnection(params, forIdentity: identity)
            isConnecting = false
            dismiss()
        }
    }
}
