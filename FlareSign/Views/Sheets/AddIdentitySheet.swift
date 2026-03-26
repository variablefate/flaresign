import SwiftUI

struct AddIdentitySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.rfSurface.ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 24) {
                    TextField("Identity label (e.g., Work, Anon)", text: $label)
                        .font(RFFont.body(16))
                        .padding(14)
                        .background(Color.rfSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(Color.rfOnSurface)

                    if #available(iOS 18.0, *) {
                        Button {
                            deriveNext()
                        } label: {
                            Label("Derive from Passkey", systemImage: "person.badge.key.fill")
                        }
                        .buttonStyle(RFPrimaryButtonStyle())
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }

                    if isLoading {
                        ProgressView().tint(.rfPrimary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(RFFont.caption())
                            .foregroundColor(Color.rfError)
                    }

                    Spacer()
                }
                .padding(24)
                .navigationTitle("Add Identity")
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

    private func deriveNext() {
        guard !isLoading else { return }
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true; errorMessage = nil
        Task {
            do {
                if #available(iOS 18.0, *) {
                    try await appState.createIdentityWithPasskey(label: trimmed)
                }
                dismiss()
            } catch {
                if !"\(error)".contains("cancelled") { errorMessage = error.localizedDescription }
            }
            isLoading = false
        }
    }
}
