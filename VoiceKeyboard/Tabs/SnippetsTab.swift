import KeyboardFoundation
import SwiftUI

struct SnippetsTab: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  @State private var showAdd = false
  @State private var trigger = ""
  @State private var expansion = ""

  var body: some View {
    @Bindable var store = store
    return ScrollView {
      VStack(spacing: 0) {
        GroupLabel("Your snippets (\(store.snippets.count))")

        ListGroup {
          ForEach(Array(store.snippets.enumerated()), id: \.element.id) { index, snippet in
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 2) {
                Text(snippet.trigger).font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.text)
                Text(snippet.expansion).font(.system(size: 13)).foregroundStyle(palette.subtext)
              }
              Spacer()
              DeleteButton { store.snippets.removeAll { $0.id == snippet.id } }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            if index < store.snippets.count - 1 { Divider().overlay(palette.border).padding(.leading, 16) }
          }
        }

        if showAdd {
          VStack(spacing: 8) {
            FormField(placeholder: "Say this", text: $trigger)
            FormField(placeholder: "Type this instead", text: $expansion)
            PrimaryButton(title: "Save snippet") {
              store.addSnippet(trigger: trigger, expansion: expansion)
              trigger = ""; expansion = ""; showAdd = false
            }
            .padding(.horizontal, 0)
          }
          .padding(.horizontal, 16).padding(.top, 12)
        } else {
          Button { showAdd = true } label: {
            Text("+ Add new snippet")
              .font(.system(size: 13.5, weight: .semibold))
              .foregroundStyle(palette.accent)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 11)
              .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(palette.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
              )
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 16).padding(.top, 12)
        }

        Card {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text("Team Snippets").font(.system(size: 14, weight: .bold)).foregroundStyle(palette.text)
              Text("Share a snippet pack with your team, synced automatically.")
                .font(.system(size: 12.5)).foregroundStyle(palette.subtext)
            }
            Spacer()
            Toggle("", isOn: $store.teamSnippets).labelsHidden().tint(palette.accent)
          }
        }
        .padding(.top, 14)
      }
      .padding(.bottom, 20)
    }
  }
}
