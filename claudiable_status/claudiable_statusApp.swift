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

    var body: some View {
        Form {
            Section("API") {
                VStack(alignment: .leading, spacing: 8) {
                    if revealApiKey {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Toggle("Hiện API key", isOn: $revealApiKey)
                        Spacer()
                        Button("Lưu Keychain") {
                            saveAPIKey()
                        }
                        .keyboardShortcut(.return, modifiers: [])

                        Button("Xóa key") {
                            apiKey = ""
                            saveAPIKey()
                        }
                    }

                    Text("API key được lưu cục bộ trong Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                }
            }

            LabeledContent("Phiên bản") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }
            LabeledContent("Build") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
        }
        .padding(20)
        .frame(width: 420)
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
