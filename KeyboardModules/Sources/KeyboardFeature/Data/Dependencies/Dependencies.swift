import Dependencies

extension TextDocumentClient: DependencyKey {
  public static let liveValue = TextDocumentClient()
  public static let testValue = TextDocumentClient()
}

extension DependencyValues {
  var textDocument: TextDocumentClient {
    get { self[TextDocumentClient.self] }
    set { self[TextDocumentClient.self] = newValue }
  }
}
