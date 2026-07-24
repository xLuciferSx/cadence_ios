import KeyboardFeature
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {

  private var hosting: UIHostingController<KeyboardFeatureView>!

  override func viewDidLoad() {
    super.viewDidLoad()

    let host = WeakHolder(self)

    let textDocument = TextDocumentClient(
      insert: { text in
        MainActor.assumeIsolated { host.value?.textDocumentProxy.insertText(text) }
      },
      deleteBackward: {
        MainActor.assumeIsolated { host.value?.textDocumentProxy.deleteBackward() }
      },
      advanceToNextInputMode: {
        MainActor.assumeIsolated { host.value?.advanceToNextInputMode() }
      },
      openApp: {
        MainActor.assumeIsolated { host.value?.openContainingApp() }
      },
      contextBeforeInput: {
        MainActor.assumeIsolated { host.value?.textDocumentProxy.documentContextBeforeInput ?? "" }
      },
      traits: {
        MainActor.assumeIsolated {
          guard let proxy = host.value?.textDocumentProxy else { return .default }
          return TextInputTraits(
            capitalization: capitalizationMode(proxy.autocapitalizationType ?? .sentences),
            autocorrect: proxy.autocorrectionType != .no,
            smartQuotes: proxy.smartQuotesType != .no,
            smartDashes: proxy.smartDashesType != .no
          )
        }
      },
      hasFullAccess: {
        MainActor.assumeIsolated { host.value?.hasFullAccess ?? false }
      }
    )

    let hosting = UIHostingController(rootView: KeyboardFeatureView(textDocument: textDocument))
    hosting.view.backgroundColor = .clear
    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.didMove(toParent: self)
    self.hosting = hosting

    // The input view's own background matches the keyboard tray, so the system's
    // rounded top corners (and any pixel of slack around the SwiftUI content)
    // blend in instead of showing a mismatched shade or the host underneath.
    view.backgroundColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.106, green: 0.106, blue: 0.114, alpha: 1)
        : UIColor(red: 0.820, green: 0.831, blue: 0.859, alpha: 1)
    }

    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    // Size the keyboard to its content height so there is no empty band at the
    // bottom. 270 = top pad 6 + candidate 44 + 9 + three 44 rows (150) + 9 +
    // bottom row 44 + bottom pad 8.
    let height = view.heightAnchor.constraint(equalToConstant: 270)
    height.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      height,
    ])
  }
}

private extension UIInputViewController {
  // A real @objc method so `#selector` resolves; the walk below skips `self`
  // and performs the selector on the UIApplication in the responder chain,
  // whose own `openURL:` actually launches the container app. Requires the
  // keyboard's "Allow Full Access" to be enabled.
  @objc func openURL(_ url: URL) {}

  func openContainingApp() {
    guard let url = URL(string: "cadence://settings") else { return }
    // For keyboard extensions, `extensionContext.open` is unreliable — it's
    // really meant for share/action extensions and can report success without
    // actually launching. The proven path is walking the responder chain to
    // UIApplication's `openURL:`. Try that first, then fall back to
    // extensionContext. Both require the keyboard's "Allow Full Access".
    if openViaResponderChain(url) { return }
    extensionContext?.open(url, completionHandler: nil)
  }

  @discardableResult
  private func openViaResponderChain(_ url: URL) -> Bool {
    let selector = #selector(openURL(_:))
    var responder: UIResponder? = next // skip self; self's openURL is the dummy below
    while let current = responder {
      if current.responds(to: selector) {
        current.perform(selector, with: url)
        return true
      }
      responder = current.next
    }
    return false
  }
}

private func capitalizationMode(_ type: UITextAutocapitalizationType) -> CapitalizationMode {
  switch type {
  case .none: .none
  case .words: .words
  case .allCharacters: .allCharacters
  default: .sentences
  }
}

private final class WeakHolder<T: AnyObject>: @unchecked Sendable {
  weak var value: T?
  init(_ value: T?) { self.value = value }
}
