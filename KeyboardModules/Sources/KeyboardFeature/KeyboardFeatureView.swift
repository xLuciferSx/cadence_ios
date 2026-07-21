import ComposableArchitecture
import SwiftUI

public struct KeyboardFeatureView: View {
  @State private var store: StoreOf<KeyboardLogic>

  public init(textDocument: TextDocumentClient) {
    _store = State(
      wrappedValue: Store(initialState: KeyboardLogic.State()) {
        KeyboardLogic()
      } withDependencies: {
        $0.textDocument = textDocument
      }
    )
  }

  public var body: some View {
    KeyboardRootView(store: store)
  }
}
