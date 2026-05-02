import SwiftUI
import Vision

/// Result of extracting one grocery item (text + store section).
struct GroceryItemResult {
    let text: String
    let section: StoreSection
}

/// JSON shape returned by AI (item + section string). Use section raw value to get StoreSection.
struct GroceryItemResponse: Codable {
    let item: String
    let section: String
}

func parseGroceryItemsFromJSON(_ cleanedContent: String) -> [GroceryItemResult]? {
    guard let jsonData = cleanedContent.data(using: .utf8) else { return nil }
    if let responses = try? JSONDecoder().decode([GroceryItemResponse].self, from: jsonData) {
        return responses.map { GroceryItemResult(text: $0.item, section: StoreSection(rawValue: $0.section) ?? .other) }
    }
    if let strings = try? JSONDecoder().decode([String].self, from: jsonData) {
        return strings.map { GroceryItemResult(text: $0, section: .other) }
    }
    return nil
}

protocol ImageProcessingStrategy {
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [GroceryItemResult], error: String?)
}

extension ImageProcessingStrategy {
    var chatText: String {
        let storeSectionsPrompt = StoreSection.orderedForPrompt.map(\.promptDescription).joined(separator: " ")
        return """
        Extract all grocery items from this image. For each item return: the item text (cleaned and normalized, lowercase; keep count/measurements e.g. '2 apples', '1lb chicken') and the store section where it is found.

        Sections (use exactly these strings): \(storeSectionsPrompt)

        Return a JSON array of objects, each with "item" and "section". Example: [{"item": "milk", "section": "Dairy/Eggs"}, {"item": "bananas", "section": "Produce"}].
        """
    }
}

enum ExtractionType: String, CaseIterable {
    case local = "Vision"
    case openai = "Chat GPT/OpenAI"
    case google = "Google AI"
}



