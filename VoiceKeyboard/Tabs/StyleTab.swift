import KeyboardFoundation
import SwiftUI

struct StyleTab: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        GroupLabel("Default tone").padding(.bottom, -6)

        ForEach(CadenceCatalog.styles) { preset in
          let selected = preset.id == store.selectedStyleID
          Button { store.selectedStyleID = preset.id } label: {
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(preset.name).font(.system(size: 15, weight: .bold)).foregroundStyle(palette.text)
                Spacer()
                if selected {
                  Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(palette.accent)
                }
              }
              Text(preset.detail).font(.system(size: 12.5)).foregroundStyle(palette.subtext)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? palette.accent : palette.border, lineWidth: selected ? 1.5 : 1)
            )
            .padding(.horizontal, 16)
          }
          .buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 6) {
          Text(store.selectedStyle.preview)
            .font(.system(size: 13.5))
            .foregroundStyle(palette.text)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bubbleIn)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
      }
      .padding(.top, 12)
      .padding(.bottom, 20)
    }
  }
}
