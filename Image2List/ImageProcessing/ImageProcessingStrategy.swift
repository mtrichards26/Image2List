import SwiftUI
import Vision

protocol ImageProcessingStrategy {
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [String], error: String?)
}

extension ImageProcessingStrategy{
    var chatText: String{
        return "Extract all grocery items from this image. Return them as a JSON array of strings, with each item cleaned and normalized (lowercase, no special characters). Maintain any indicators of count or measurements (e.g., '2 apples', 'Avocado x 5', '1lb Chicken')."
    }
}

enum ExtractionType: String, CaseIterable {
    case local = "Vision"
    case openai = "Chat GPT/OpenAI"
    case google = "Google AI"
}



