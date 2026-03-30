import SwiftUI

@MainActor final class QuoteStore: ObservableObject {
    @Published var quote: String?

    func ensureQuote(generate: () async -> String) async {
        if quote == nil {
            let generatedQuote = await generate()
            if self.quote == nil {
                self.quote = generatedQuote
            }
        }
    }

    func currentOrPlaceholder(_ placeholder: String) -> String {
        return quote ?? placeholder
    }
}
