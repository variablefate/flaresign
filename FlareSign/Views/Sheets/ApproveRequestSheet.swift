import SwiftUI

struct ApproveRequestSheet: View {
    @Environment(AppState.self) private var appState
    @State private var rememberDuration: PermissionEngine.RememberDuration = .thisTimeOnly

    var body: some View {
        ZStack {
            Color.rfSurface.ignoresSafeArea()

            if let request = appState.requestQueue.currentRequest {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Signing Request")
                            .font(RFFont.title(18))
                            .foregroundColor(Color.rfOnSurface)
                        Spacer()
                        if appState.requestQueue.pendingCount > 0 {
                            Text("+\(appState.requestQueue.pendingCount) more")
                                .font(RFFont.caption(12))
                                .foregroundColor(Color.rfOnSurfaceVariant)
                        }
                    }

                    // App info
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.rfSurfaceContainerHigh)
                                .frame(width: 44, height: 44)
                            Text(String(request.appName.prefix(1)).uppercased())
                                .font(RFFont.title(18))
                                .foregroundColor(Color.rfPrimary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.appName)
                                .font(RFFont.title(16))
                                .foregroundColor(Color.rfOnSurface)
                            Text(request.displayTitle)
                                .font(RFFont.caption(13))
                                .foregroundColor(Color.rfOnSurfaceVariant)
                        }
                        Spacer()
                    }

                    // Content preview
                    if let preview = request.contentPreview, !preview.isEmpty {
                        ScrollView {
                            Text(preview)
                                .font(RFFont.mono(12))
                                .foregroundColor(Color.rfOnSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 150)
                        .padding(12)
                        .background(Color.rfSurfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Remember option
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remember this choice")
                            .font(RFFont.caption(12))
                            .foregroundColor(Color.rfOnSurfaceVariant)
                        Picker("", selection: $rememberDuration) {
                            Text(PermissionEngine.RememberDuration.thisTimeOnly.label).tag(PermissionEngine.RememberDuration.thisTimeOnly)
                            Text(PermissionEngine.RememberDuration.fifteenMinutes.label).tag(PermissionEngine.RememberDuration.fifteenMinutes)
                            Text(PermissionEngine.RememberDuration.oneHour.label).tag(PermissionEngine.RememberDuration.oneHour)
                            Text(PermissionEngine.RememberDuration.fourHours.label).tag(PermissionEngine.RememberDuration.fourHours)
                            Text(PermissionEngine.RememberDuration.always.label).tag(PermissionEngine.RememberDuration.always)
                        }
                        .pickerStyle(.menu)
                        .tint(Color.rfPrimary)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 12) {
                        Button("Approve") {
                            appState.requestQueue.approve(remember: rememberDuration)
                        }
                        .buttonStyle(RFPrimaryButtonStyle())

                        Button("Deny") {
                            appState.requestQueue.deny(remember: rememberDuration)
                        }
                        .buttonStyle(RFDenyButtonStyle())
                    }
                }
                .padding(24)
            }
        }
    }
}
