import KeyboardFoundation
import SwiftUI

extension ThemePreference {
  var colorScheme: ColorScheme? {
    switch self {
    case .light: .light
    case .dark: .dark
    case .system: nil
    }
  }
}

struct RootView: View {
  @State private var store = CadenceStore()

  var body: some View {
    PaletteProvider {
      if store.isSignedIn {
        CadenceShell()
      } else {
        OnboardingView()
      }
    }
    .environment(store)
    .preferredColorScheme(store.themePreference.colorScheme)
    .onOpenURL { url in
      // The keyboard's ⚙ button launches the app via `cadence://settings`
      // (see KeyboardViewController.openContainingApp). Land on the tab the
      // deep link asks for so the button actually takes you somewhere.
      guard url.scheme == "cadence" else { return }
      if let tab = CadenceTab(rawValue: url.host ?? "") {
        store.selectedTab = tab
      } else {
        store.selectedTab = .settings
      }
    }
  }
}

private struct PaletteProvider<Content: View>: View {
  @Environment(\.colorScheme) private var scheme
  @ViewBuilder var content: () -> Content

  var body: some View {
    content().environment(\.palette, Palette.resolve(scheme))
  }
}

private struct CadenceShell: View {
  @Environment(\.palette) private var palette
  @Environment(CadenceStore.self) private var store

  var body: some View {
    VStack(spacing: 0) {
      titleRow
      Group {
        switch store.selectedTab {
        case .home: HomeTab()
        case .dictionary: DictionaryTab()
        case .snippets: SnippetsTab()
        case .style: StyleTab()
        case .settings: SettingsTab()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(palette.tray)
      tabBar
    }
    .background(palette.tray)
  }

  private var titleRow: some View {
    @Bindable var store = store
    return HStack(spacing: 8) {
      Image(systemName: "diamond.fill").font(.system(size: 15)).foregroundStyle(palette.accent)
      Text("Cadence").font(.system(size: 20, weight: .bold)).foregroundStyle(palette.text)
      Text("Beta")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.accent, lineWidth: 1))
      Spacer()
      Button {
        store.themePreference = store.themePreference == .dark ? .light : .dark
      } label: {
        Image(systemName: store.themePreference == .dark ? "moon.fill" : "sun.max.fill")
          .font(.system(size: 13))
          .foregroundStyle(palette.text)
          .frame(width: 28, height: 28)
          .background(palette.special)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
    .padding(.bottom, 12)
    .background(palette.background)
  }

  private var tabBar: some View {
    @Bindable var store = store
    return HStack(spacing: 0) {
      ForEach(CadenceTab.allCases) { tab in
        Button {
          store.selectedTab = tab
        } label: {
          VStack(spacing: 3) {
            Image(systemName: tab.icon).font(.system(size: 17))
            Text(tab.title).font(.system(size: 10, weight: store.selectedTab == tab ? .semibold : .regular))
          }
          .foregroundStyle(store.selectedTab == tab ? palette.accent : palette.subtext)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.bottom, 4)
    .background(palette.background)
    .overlay(Divider().overlay(palette.border), alignment: .top)
  }
}
