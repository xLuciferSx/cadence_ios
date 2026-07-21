import AVFoundation
import KeyboardFoundation
import SwiftUI
import UIKit

struct SettingsTab: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  @State private var micStatus = AVAudioApplication.shared.recordPermission

  var body: some View {
    @Bindable var store = store
    return ScrollView {
      VStack(spacing: 0) {
        GroupLabel("Cadence Intelligence")
        ListGroup {
          AccentToggleRow(
            title: "Language Blend",
            subtitle: "Auto-detect and switch languages mid-sentence",
            isOn: $store.languageBlend
          )
          AccentToggleRow(
            title: "Context Memory",
            subtitle: "Remember tone per app",
            isOn: $store.contextMemory,
            showsDivider: false
          )
        }

        GroupLabel("Privacy")
        ListGroup {
          AccentToggleRow(
            title: "On-device only",
            subtitle: "Process dictation locally, nothing leaves your phone",
            isOn: $store.onDeviceOnly,
            showsDivider: false
          )
        }

        GroupLabel("Appearance")
        ListGroup {
          HStack {
            Text("Theme").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
            Spacer()
            Picker("", selection: $store.themePreference) {
              ForEach(ThemePreference.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .tint(palette.accent)
          }
          .padding(.horizontal, 16).padding(.vertical, 8)
        }

        GroupLabel("Active languages (pick up to 3)")
        ListGroup {
          ForEach(Array(CadenceCatalog.languages.enumerated()), id: \.element.id) { index, lang in
            let active = store.activeLanguages.contains(lang.code)
            Button { store.toggleLanguage(lang.code) } label: {
              HStack {
                Text(lang.name)
                  .font(.system(size: 14.5, weight: active ? .semibold : .regular))
                  .foregroundStyle(active ? palette.accent : palette.text)
                Spacer()
                if active { Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.accent) }
              }
              .padding(.horizontal, 16).padding(.vertical, 12)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if index < CadenceCatalog.languages.count - 1 { Divider().overlay(palette.border).padding(.leading, 16) }
          }
        }

        GroupLabel("Transcription")
        ListGroup {
          AccentToggleRow(
            title: "Clean up with AI",
            subtitle: "Backend removes filler words and fixes punctuation before inserting",
            isOn: $store.cleanupEnabled,
            showsDivider: false
          )
        }

        GroupLabel("Backend")
        ListGroup {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text("Connected").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
              Text(backendHost).font(.system(size: 12)).foregroundStyle(palette.subtext)
                .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(.green)
          }
          .padding(.horizontal, 16).padding(.vertical, 12)
        }
        Text("Cadence talks to your own backend, which holds the OpenAI key. The address and access token are built into the app.")
          .font(.system(size: 12)).foregroundStyle(palette.subtext)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20).padding(.top, 6)

        GroupLabel("Set up the keyboard")
        ListGroup {
          settingsStep("Microphone access", trailing: micLabel, accentTrailing: micStatus != .granted) { requestMicrophone() }
          settingsStep("Open iOS Settings", trailing: "Open", accentTrailing: true) {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
          }
        }

        GroupLabel("Account")
        ListGroup {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(store.accountEmail ?? "Signed in").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
              Text("MVP device account").font(.system(size: 12)).foregroundStyle(palette.subtext)
            }
            Spacer()
            Button("Sign out") { store.signOut() }.foregroundStyle(palette.accent)
          }
          .padding(.horizontal, 16).padding(.vertical, 12)
        }

        Text("Settings › General › Keyboard › Keyboards → Cadence, then turn on Allow Full Access (required for the mic and network). The app can't read this switch, so it isn't shown here — check it in iOS Settings.")
          .font(.system(size: 12)).foregroundStyle(palette.subtext)
          .padding(.horizontal, 20).padding(.top, 8)
      }
      .padding(.bottom, 24)
    }
    .onAppear {
      micStatus = AVAudioApplication.shared.recordPermission
    }
  }

  private var backendHost: String {
    AppConfig.backendURL?.host ?? "your backend"
  }

  private var micLabel: String {
    switch micStatus {
    case .granted: "Granted"
    case .denied: "Open Settings"
    case .undetermined: "Allow"
    @unknown default: "Open Settings"
    }
  }

  private func requestMicrophone() {
    if micStatus == .denied {
      if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
      return
    }
    AVAudioApplication.requestRecordPermission { _ in
      DispatchQueue.main.async { micStatus = AVAudioApplication.shared.recordPermission }
    }
  }

  private func settingsStep(_ title: String, trailing: String, accentTrailing: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
        Spacer()
        Text(trailing).font(.system(size: 14)).foregroundStyle(accentTrailing ? palette.accent : palette.subtext)
      }
      .padding(.horizontal, 16).padding(.vertical, 13)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

}
