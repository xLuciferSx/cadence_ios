import KeyboardFoundation
import SwiftUI

struct HomeTab: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  private let history: [(text: String, time: String)] = [
    ("Sounds good, let's schedule it for tomorrow.", "13:39"),
    ("¿Puedes enviarme el informe actualizado?", "13:24"),
    ("Labi, parunāsim rīt.", "11:05"),
  ]

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        Card {
          VStack(alignment: .leading, spacing: 4) {
            Text("Clarity Score").font(.system(size: 13)).foregroundStyle(palette.subtext)
            Text("92%").font(.system(size: 34, weight: .bold)).foregroundStyle(palette.accent)
            Text("Fewer edits needed than last week — keep dictating.")
              .font(.system(size: 12)).foregroundStyle(palette.subtext)
          }
        }
        .padding(.top, 12)

        Card {
          VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Language Blend").font(.system(size: 14, weight: .bold)).foregroundStyle(palette.text)
              Text("Switch languages mid-sentence — Cadence detects and re-types without breaking your flow.")
                .font(.system(size: 12.5)).foregroundStyle(palette.subtext)
            }
            HStack(spacing: 6) {
              ForEach(store.activeLanguageChips, id: \.self) { Chip(text: $0) }
            }
          }
        }

        Card {
          VStack(alignment: .leading, spacing: 2) {
            Text("Context Memory").font(.system(size: 14, weight: .bold)).foregroundStyle(palette.text)
            Text("Remembers the tone you use per app — Slack stays casual, email stays formal, automatically.")
              .font(.system(size: 12.5)).foregroundStyle(palette.subtext)
          }
        }

        VStack(spacing: 0) {
          GroupLabel("Recent dictations")
          ListGroup {
            ForEach(Array(history.enumerated()), id: \.offset) { index, item in
              VStack(alignment: .leading, spacing: 2) {
                Text(item.text).font(.system(size: 14.5)).foregroundStyle(palette.text)
                Text(item.time).font(.system(size: 11.5)).foregroundStyle(palette.subtext)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 16)
              .padding(.vertical, 13)
              if index < history.count - 1 { Divider().overlay(palette.border).padding(.leading, 16) }
            }
          }
        }

        PrimaryButton(title: "Set up the keyboard") { store.selectedTab = .settings }
          .padding(.top, 4)
      }
      .padding(.bottom, 20)
    }
  }
}
