//
//  claudiable_statusApp.swift
//  claudiable_status
//
//  Created by Pham Dong on 28/2/26.
//

import SwiftUI

@main
struct claudiable_statusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window; only optional Settings
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var revealApiKey = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var toastTask: Task<Void, Never>?

    private let neonGreen = Color(red: 0.30, green: 0.80, blue: 0.35)
    private let darkBg = Color(white: 0.08)
    private let cardColor = Color(white: 0.10)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // API Key section
            VStack(alignment: .leading, spacing: 10) {
                Text("API")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(neonGreen)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)

                    Group {
                        if revealApiKey {
                            TextField("API Key", text: $apiKey)
                        } else {
                            SecureField("API Key", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)

                    Button {
                        revealApiKey.toggle()
                    } label: {
                        Image(systemName: revealApiKey ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.gray)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("API key được lưu cục bộ trong Keychain.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.gray)

                HStack(spacing: 8) {
                    Button {
                        apiKey = ""
                        saveAPIKey()
                    } label: {
                        Text("Xóa key")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        saveAPIKey()
                    } label: {
                        Text("Lưu Keychain")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(neonGreen, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(14)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // App Info section
            VStack(alignment: .leading, spacing: 10) {
                Text("Ứng dụng")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(neonGreen)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack {
                    Text("Phiên bản")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack {
                    Text("Build")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.gray)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(cardColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(20)
        .frame(width: 420)
        .background(darkBg)
        .preferredColorScheme(.dark)
        .onAppear {
            apiKey = APIKeyStore.load()
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastBanner(message: toastMessage, isError: toastIsError)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage != nil)
        .onDisappear {
            toastTask?.cancel()
        }
    }

    private func saveAPIKey() {
        if APIKeyStore.save(apiKey) {
            let message = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Đã xóa API key khỏi Keychain."
                : "Đã lưu API key vào Keychain."
            presentToast(message)
            NotificationCenter.default.post(name: .apiKeyDidChange, object: nil)
        } else {
            presentToast("Không thể lưu API key vào Keychain.", isError: true)
        }
    }

    private func presentToast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        toastMessage = message
        toastIsError = isError
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}
