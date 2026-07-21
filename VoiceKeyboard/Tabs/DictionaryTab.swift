import KeyboardFoundation
import SwiftUI

struct DictionaryTab: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  @State private var showAdd = false
  @State private var word = ""
  @State private var note = ""

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        GroupLabel("Your words (\(store.dictionary.count))")

        ListGroup {
          ForEach(Array(store.dictionary.enumerated()), id: \.element.id) { index, entry in
            HStack {
              Text(entry.label).font(.system(size: 14.5)).foregroundStyle(palette.text)
              Spacer()
              DeleteButton { store.dictionary.removeAll { $0.id == entry.id } }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            if index < store.dictionary.count - 1 { Divider().overlay(palette.border).padding(.leading, 16) }
          }
        }

        if showAdd {
          VStack(spacing: 8) {
            FormField(placeholder: "Word (e.g. a name or term)", text: $word)
            FormField(placeholder: "Expands to (optional)", text: $note)
            PrimaryButton(title: "Save word") {
              store.addWord(word, expandsTo: note)
              word = ""; note = ""; showAdd = false
            }
            .padding(.horizontal, 0)
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
        } else {
          Button { showAdd = true } label: {
            Text("+ Add new word")
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
          .padding(.horizontal, 16)
          .padding(.top, 12)
        }
      }
      .padding(.bottom, 20)
    }
  }
}
