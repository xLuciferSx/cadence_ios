import AVFoundation
import SwiftUI

struct OnboardingView: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store
  @State private var showingLogin = false

  var body: some View {
    ZStack {
      palette.tray.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 0) {
          Spacer(minLength: 34)
          Image(systemName: "waveform.and.mic")
            .font(.system(size: 42, weight: .medium))
            .foregroundStyle(palette.accent)
            .frame(width: 86, height: 86)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

          Text("Your voice, in every app")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.text)
            .padding(.top, 24)
          Text("Cadence turns what you say into polished text from the keyboard you already use.")
            .font(.system(size: 16))
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.subtext)
            .padding(.horizontal, 28)
            .padding(.top, 10)

          VStack(alignment: .leading, spacing: 14) {
            feature("mic.fill", "Dictate anywhere", "Speak naturally in any text field.")
            feature("wand.and.stars", "Write with intention", "Clean up, rewrite, and match your tone.")
            feature("lock.fill", "Your settings, your control", "Choose languages, styles, and privacy options.")
          }
          .padding(18)
          .background(palette.background)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .padding(.horizontal, 16)
          .padding(.top, 28)

          PrimaryButton(title: "Get started") { showingLogin = true }
            .padding(.top, 24)
          Text("MVP preview · account sync is coming soon")
            .font(.system(size: 11))
            .foregroundStyle(palette.subtext)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
      }
    }
    .sheet(isPresented: $showingLogin) { LoginView() }
  }

  private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon).foregroundStyle(palette.accent).frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
        Text(detail).font(.system(size: 12)).foregroundStyle(palette.subtext)
      }
    }
  }
}

private struct LoginView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store
  @State private var email = ""
  @State private var password = ""
  @State private var error: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Welcome back")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(palette.text)
          Text("Sign in to finish setting up Cadence on this device.")
            .font(.system(size: 15)).foregroundStyle(palette.subtext)
          FormField(placeholder: "Email", text: $email)
            .keyboardType(.emailAddress)
          SecureField("Password", text: $password)
            .font(.system(size: 14)).foregroundStyle(palette.text)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(palette.background)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border))
          if let error { Text(error).font(.system(size: 12)).foregroundStyle(.orange) }
          PrimaryButton(title: "Continue") {
            let validEmail = email.contains("@") && email.contains(".")
            guard validEmail, password.count >= 4 else {
              error = "Enter a valid email and a password with at least 4 characters."
              return
            }
            store.signIn(email: email)
            // Prime microphone permission here, in the app, at the end of setup.
            // A keyboard extension can't present the mic prompt, so granting it
            // now means the keyboard records in place — no bounce out to the app
            // the first time the user taps the mic.
            AVAudioApplication.requestRecordPermission { _ in }
            dismiss()
          }
          Text("This MVP stores your sign-in locally. Connect your account provider before release.")
            .font(.system(size: 11)).foregroundStyle(palette.subtext)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .padding(20)
      }
      .background(palette.tray)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
    }
  }
}
