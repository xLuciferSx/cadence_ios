import KeyboardFoundation
import SwiftUI

struct GroupLabel: View {
  @Environment(\.palette) private var palette
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 12, weight: .semibold))
      .kerning(0.4)
      .foregroundStyle(palette.subtext)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.top, 14)
      .padding(.bottom, 6)
  }
}

struct Card<Content: View>: View {
  @Environment(\.palette) private var palette
  var padding: CGFloat = 16
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(palette.background)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .padding(.horizontal, 16)
  }
}

struct ListGroup<Content: View>: View {
  @Environment(\.palette) private var palette
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: 0) { content() }
      .background(palette.background)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .padding(.horizontal, 16)
  }
}

struct AccentToggleRow: View {
  @Environment(\.palette) private var palette
  let title: String
  let subtitle: String
  @Binding var isOn: Bool
  var showsDivider: Bool = true

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(palette.text)
          Text(subtitle).font(.system(size: 12)).foregroundStyle(palette.subtext)
        }
        Spacer()
        Toggle("", isOn: $isOn).labelsHidden().tint(palette.accent)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      if showsDivider { Divider().overlay(palette.border).padding(.leading, 16) }
    }
  }
}

struct DeleteButton: View {
  @Environment(\.palette) private var palette
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(palette.subtext)
        .frame(width: 26, height: 26)
        .background(palette.special)
        .clipShape(Circle())
    }
    .buttonStyle(.plain)
  }
}

struct PrimaryButton: View {
  @Environment(\.palette) private var palette
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(palette.accent)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16)
  }
}

struct Chip: View {
  @Environment(\.palette) private var palette
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(palette.accent)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(palette.accent, lineWidth: 1)
      )
  }
}

struct FormField: View {
  @Environment(\.palette) private var palette
  let placeholder: String
  @Binding var text: String

  var body: some View {
    TextField(placeholder, text: $text)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .font(.system(size: 14))
      .foregroundStyle(palette.text)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(palette.background)
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(palette.border, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}
