import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showImport = false
    @State private var importText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height

            ZStack {
                Color.rfSurface.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: h * 0.03)

                    // Logo
                    VStack(spacing: h * 0.02) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.rfFlare)
                                .frame(width: 100, height: 100)
                                .rfAmbientShadow(color: .rfPrimary, radius: 40, opacity: 0.2)
                            Image(systemName: "key.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.black)
                        }

                        HStack(spacing: 0) {
                            Text("Flare")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(Color.rfOnSurface)
                            Text("Sign")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(Color.rfPrimary)
                        }
                    }

                    Color.clear.frame(height: h * 0.015)

                    // Subtitle
                    VStack(spacing: 10) {
                        Text("Your keys, your identity")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.5)
                            .foregroundColor(Color.rfOnSurface)

                        Text("Sign into Nostr apps without sharing your private key.")
                            .font(RFFont.body(15))
                            .foregroundColor(Color.rfOnSurfaceVariant)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    Spacer(minLength: h * 0.03)

                    // Bullet points
                    VStack(alignment: .leading, spacing: 16) {
                        bulletPoint("NO SEED PHRASES")
                        bulletPoint("NO KEY SHARING")
                        bulletPoint("NO TRACKING")
                    }
                    .padding(.leading, 52)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: h * 0.03)

                    // Buttons
                    VStack(spacing: 16) {
                        if #available(iOS 18.0, *) {
                            Button {
                                createWithPasskey()
                            } label: {
                                Label("Create with Passkey", systemImage: "person.badge.key.fill")
                            }
                            .buttonStyle(RFPrimaryButtonStyle())
                            .disabled(isLoading)
                        }

                        Button {
                            showImport = true
                        } label: {
                            Text("Import Existing Key")
                        }
                        .buttonStyle(RFSecondaryButtonStyle())
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)

                    if isLoading {
                        ProgressView().tint(.rfPrimary).padding(.top, 8)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(RFFont.caption())
                            .foregroundColor(Color.rfError)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: h * 0.03)
                }
            }
        }
        .sheet(isPresented: $showImport) {
            ImportKeySheet(importText: $importText, errorMessage: $errorMessage) {
                importKey()
            }
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.rfPrimary)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.5)
                .foregroundColor(Color.rfOnSurfaceVariant)
        }
    }

    private func createWithPasskey() {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        Task {
            do {
                if #available(iOS 18.0, *) {
                    try await appState.createIdentityWithPasskey(label: "Primary")
                }
            } catch {
                if !"\(error)".contains("cancelled") { errorMessage = error.localizedDescription }
            }
            isLoading = false
        }
    }

    private func importKey() {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        Task {
            do {
                try appState.importIdentity(nsec: importText.trimmingCharacters(in: .whitespaces), label: "Imported")
                showImport = false
            } catch {
                errorMessage = "Invalid key. Check that you pasted the full nsec."
            }
            isLoading = false
        }
    }
}

struct ImportKeySheet: View {
    @Binding var importText: String
    @Binding var errorMessage: String?
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.rfSurface.ignoresSafeArea()
            NavigationStack {
                VStack(spacing: 24) {
                    TextField("Paste your nsec key", text: $importText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(RFFont.mono(14))
                        .padding(12)
                        .background(Color.rfSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(Color.rfOnSurface)

                    if let error = errorMessage {
                        Text(error)
                            .font(RFFont.caption())
                            .foregroundColor(Color.rfError)
                    }

                    Button("Import") { onImport() }
                        .buttonStyle(RFPrimaryButtonStyle())
                        .disabled(importText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(24)
                .navigationTitle("Import Key")
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
}
