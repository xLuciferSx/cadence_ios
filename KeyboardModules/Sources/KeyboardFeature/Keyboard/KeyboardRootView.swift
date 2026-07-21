import ComposableArchitecture
import KeyboardFoundation
import SwiftUI

struct KeyboardRootView: View {
  @Bindable var store: StoreOf<KeyboardLogic>
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    var palette = Palette.resolve(colorScheme)
    let dark = colorScheme == .dark
    // Match the classic iOS keyboard exactly: solid greyscale, one uniform tray
    // colour for the candidate strip and the key area (no seam, no translucency).
    palette.tray = dark ? Color(hex: 0x1B1B1D) : Color(hex: 0xD1D4DB)
    palette.key = dark ? Color(hex: 0x6B6B6D) : Color(hex: 0xFFFFFF)
    palette.special = dark ? Color(hex: 0x4A4A4C) : Color(hex: 0xACB1BB)
    palette.keyText = dark ? .white : Color(hex: 0x1A1A1C)
    palette.subtext = dark ? Color(hex: 0x9A9A9F) : Color(hex: 0x55555A)

    return VStack(spacing: 9) {
      topBar(palette)
      letterRows(palette)
      bottomRow(palette)
    }
    .padding(.horizontal, 4)
    .padding(.top, 6)
    .padding(.bottom, 8)
    .background(palette.tray)
    .environment(\.palette, palette)
    .onAppear { store.send(.refresh) }
  }

  // MARK: Top strip — candidates + tone/voice status, with wand & mic in the corner

  private func topBar(_ palette: Palette) -> some View {
    HStack(spacing: 6) {
      candidateArea(palette).frame(maxWidth: .infinity)

      if store.hasText, store.voice.status == .idle, !store.isRewriting, !store.toneBarVisible {
        Button { store.send(.toneBarToggled) } label: {
          Image(systemName: "wand.and.stars")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(palette.accent)
            .frame(width: 34, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      MicKey(status: store.voice.status) { store.send(.voice(.micButtonTapped)) }
        .frame(width: 40)
    }
    .frame(height: 44)
  }

  @ViewBuilder
  private func candidateArea(_ palette: Palette) -> some View {
    switch store.voice.status {
    case .recording:
      statusText(palette, "Listening…", systemImage: "waveform", color: palette.accent)
    case .transcribing:
      processingText(palette, "Cleaning up…")
    case .idle:
      if store.isRewriting {
        processingText(palette, "Rewriting…")
      } else if let error = store.voice.errorMessage {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle").font(.system(size: 12))
          Text(error).font(.system(size: 12)).lineLimit(2).minimumScaleFactor(0.85)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity)
      } else if store.toneBarVisible {
        toneBar(palette)
      } else {
        suggestionsRow(palette)
      }
    }
  }

  private func statusText(_ palette: Palette, _ text: String, systemImage: String, color: Color) -> some View {
    Label(text, systemImage: systemImage)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(color)
      .lineLimit(1)
      .frame(maxWidth: .infinity)
  }

  private func processingText(_ palette: Palette, _ text: String) -> some View {
    HStack(spacing: 8) {
      ProgressView().controlSize(.small).tint(palette.accent)
      Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.subtext)
    }
    .frame(maxWidth: .infinity)
  }

  private func toneBar(_ palette: Palette) -> some View {
    HStack(spacing: 6) {
      ForEach(ToneOption.allCases, id: \.self) { tone in
        Button { store.send(.toneSelected(tone)) } label: {
          Text(tone.label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(palette.key)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
      Button { store.send(.toneBarToggled) } label: {
        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
          .foregroundStyle(palette.subtext).frame(width: 24, height: 28).contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  private func suggestionsRow(_ palette: Palette) -> some View {
    HStack(spacing: 4) {
      if store.suggestions.isEmpty {
        Spacer()
      } else {
        ForEach(Array(store.suggestions.enumerated()), id: \.offset) { _, suggestion in
          Button { store.send(.suggestionTapped(suggestion)) } label: {
            Text(suggestion)
              .font(.system(size: 16))
              .foregroundStyle(palette.text)
              .lineLimit(1)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(suggestion == store.defaultSuggestion ? palette.key : .clear)
              .clipShape(Capsule())
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Letter rows

  private func letterRows(_ palette: Palette) -> some View {
    VStack(spacing: 9) {
      ForEach(Array(store.rows.enumerated()), id: \.offset) { index, row in
        HStack(spacing: 5) {
          if index == 2 { leftModifierKey(palette); Spacer(minLength: 0) }
          ForEach(row, id: \.self) { label in
            LetterKey(label: label) { store.send(.key(label)) }
          }
          if index == 2 { Spacer(minLength: 0); backspaceKey(palette) }
        }
      }
    }
  }

  @ViewBuilder
  private func leftModifierKey(_ palette: Palette) -> some View {
    switch store.mode {
    case .letters:
      SpecialKey(
        systemImage: store.shift == .locked ? "capslock.fill"
          : (store.shift == .enabled ? "shift.fill" : "shift"),
        highlighted: store.language.cased && store.shift != .disabled
      ) { if store.language.cased { store.send(.shiftTapped) } }
        .frame(width: 44)
        .opacity(store.language.cased ? 1 : 0.35)
    case .numbers:
      SpecialKey(label: "#+=") { store.send(.symbolModeTapped) }.frame(width: 44)
    case .symbols:
      SpecialKey(label: "123") { store.send(.numberModeTapped) }.frame(width: 44)
    }
  }

  private func backspaceKey(_ palette: Palette) -> some View {
    SpecialKey(systemImage: "delete.left") { store.send(.backspaceTapped) }.frame(width: 44)
  }

  // MARK: Bottom row

  private func bottomRow(_ palette: Palette) -> some View {
    HStack(spacing: 5) {
      SpecialKey(label: store.mode == .letters ? "123" : "ABC") {
        store.send(store.mode == .letters ? .numberModeTapped : .letterModeTapped)
      }
      .frame(width: 44)

      SpecialKey(label: store.languageCode) { store.send(.globeTapped) }
        .frame(width: 46)
        .simultaneousGesture(LongPressGesture().onEnded { _ in store.send(.globeLongPressed) })

      SpecialKey(systemImage: "gearshape") { store.send(.openApp) }.frame(width: 42)

      SpaceKey(label: store.language.nativeName) { store.send(.spaceTapped) }

      ReturnKey { store.send(.returnTapped) }.frame(width: 84)
    }
  }

  // MARK: Settings overlay

}

// MARK: - Key components

// The classic iOS keyboard gives every key the same rounded face and the same
// subtle 1pt bottom "lip" shadow — letters and function keys alike. Sharing one
// modifier keeps them consistent (previously only letter keys had a shadow, so
// the function keys looked flat next to them).
private struct KeyFace: ViewModifier {
  @Environment(\.colorScheme) private var scheme
  var fill: Color

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .background(fill)
      .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
      .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.28), radius: 0, y: 1)
  }
}

private extension View {
  func keyFace(_ fill: Color) -> some View { modifier(KeyFace(fill: fill)) }
}

private struct LetterKey: View {
  @Environment(\.palette) private var palette
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 22.5))
        .foregroundStyle(palette.keyText)
        .keyFace(palette.key)
    }
    .buttonStyle(KeyPress())
  }
}

private struct SpecialKey: View {
  @Environment(\.palette) private var palette
  var label: String?
  var systemImage: String?
  var highlighted = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if let systemImage { Image(systemName: systemImage).font(.system(size: 17)) }
        else if let label { Text(label).font(.system(size: 15, weight: .medium)) }
      }
      .foregroundStyle(highlighted ? .black : palette.keyText)
      .keyFace(highlighted ? Color.white : palette.special)
    }
    .buttonStyle(KeyPress())
  }
}

private struct SpaceKey: View {
  @Environment(\.palette) private var palette
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 13))
        .foregroundStyle(palette.subtext)
        .keyFace(palette.key)
    }
    .buttonStyle(KeyPress())
  }
}

private struct ReturnKey: View {
  @Environment(\.palette) private var palette
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text("return")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(palette.keyText)
        .keyFace(palette.special)
    }
    .buttonStyle(KeyPress())
  }
}

private struct MicKey: View {
  @Environment(\.palette) private var palette
  let status: VoiceLogic.State.Status
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if status == .transcribing {
          ProgressView().controlSize(.small).tint(.white)
        } else {
          Image(systemName: status == .recording ? "waveform" : "mic.fill")
            .font(.system(size: 16, weight: .semibold))
        }
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 40)
      .background(status == .recording ? Color.red : palette.accent)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(KeyPress())
    .disabled(status == .transcribing)
  }
}

private struct KeyPress: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
  }
}
