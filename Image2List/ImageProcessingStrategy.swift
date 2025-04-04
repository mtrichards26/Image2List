import SwiftUI
import Vision

protocol ImageProcessingStrategy {
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> [String]
}

enum ExtractionType: String, CaseIterable {
    case local = "Local"
    case openai = "OpenAI"
    case google = "Google AI"
}

class VisionStrategy: ImageProcessingStrategy {
    private let customWords: [String]
    
    init(customWords: [String]) {
        self.customWords = customWords
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> [String] {
        progress("Initializing Vision...")
        guard let cgImage = image.cgImage else { return [] }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        
        // Configure the request for better accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01
        request.customWords = customWords
        
        do {
            progress("Processing image with Vision...")
            try requestHandler.perform([request])
            
            guard let observations = request.results else { return [] }
            
            progress("Extracting text from image...")
            return observations.enumerated().compactMap { (index, observation) -> String? in
                guard let textObservation = observation as? VNRecognizedTextObservation,
                      let text = textObservation.topCandidates(1).first?.string else { return nil }
                
                // Clean up the text while preserving quantities and packaging
                let cleanedText = cleanText(text)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty or very short items
                guard cleanedText.count > 1 else { return nil }
                
                return cleanedText
            }
        } catch {
            print("Failed to perform recognition: \(error)")
            return []
        }
    }
    
    private func cleanText(_ text: String) -> String {
        // Define allowed characters (English alphabet, numbers, and common punctuation)
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,()/\\- ")
        
        // Convert the text to lowercase first
        let lowercaseText = text.lowercased()
        
        // Filter out any characters that aren't in our allowed set
        let cleanedText = lowercaseText.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map { String($0) }
            .joined()
        
        return cleanedText
    }
}

class OpenAIStrategy: ImageProcessingStrategy {
    private let apiKey: String
    private let endpoint: String
    private let model: String
    
    init(apiKey: String, endpoint: String, model: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> [String] {
        progress("Preparing image for OpenAI...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG data")
            return []
        }
        let base64Image = imageData.base64EncodedString()
        print("Image converted to base64, length: \(base64Image.count)")
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Extract all items from this image. Return them as a JSON array of strings, with each item cleaned and normalized (lowercase, no special characters)."
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)"
                        ]
                    ]
                ]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 1000
        ]
        
        guard let url = URL(string: endpoint),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to create request URL or JSON data")
            return []
        }
        print("Created request URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            progress("Sending image to OpenAI...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Received response with status code: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Successfully parsed JSON response")
                
                if let choices = json["choices"] as? [[String: Any]] {
                    
                    if let firstChoice = choices.first {
                        if let message = firstChoice["message"] as? [String: Any] {
                            if let content = message["content"] as? String {
                                
                                progress("Processing OpenAI response...")
                                // Clean and parse the content
                                let cleanedContent = content
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .replacingOccurrences(of: "```json", with: "")
                                    .replacingOccurrences(of: "```", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                print("Cleaned content: \(cleanedContent)")
                                
                                if let jsonData = cleanedContent.data(using: .utf8),
                                   let items = try? JSONDecoder().decode([String].self, from: jsonData) {
                                    print("Successfully parsed JSON array with \(items.count) items")
                                    return items
                                } else {
                                    print("Failed to parse as JSON, trying plain text")
                                    let plainTextItems = cleanedContent
                                        .components(separatedBy: .newlines)
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                    print("Parsed \(plainTextItems.count) items as plain text")
                                    return plainTextItems
                                }
                            } else {
                                print("Failed to get content from message")
                            }
                        } else {
                            print("Failed to get message from choice")
                        }
                    } else {
                        print("No choices found in response")
                    }
                } else {
                    print("Failed to get choices from response")
                }
            } else {
                print("Failed to parse response as JSON")
            }
        } catch {
            print("OpenAI API error: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
        
        print("Returning empty array due to processing failure")
        return []
    }
}

class GeminiStrategy: ImageProcessingStrategy {
    private let apiKey: String
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-exp-03-25:generateContent"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> [String] {
        progress("Preparing image for Google Gemini...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return []
        }
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Extract all grocery items from this image. Return them as a JSON array of strings, with each item cleaned and normalized (lowercase, no special characters)."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)"),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            progress("Sending image to Google Gemini...")
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                progress("Processing Gemini response...")
                // Clean and parse the content
                let cleanedContent = text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let jsonData = cleanedContent.data(using: .utf8),
                   let items = try? JSONDecoder().decode([String].self, from: jsonData) {
                    return items
                } else {
                    // If JSON parsing fails, try to parse as plain text
                    return cleanedContent
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            }
        } catch {
            print("Gemini API error: \(error)")
        }
        
        return []
    }
} 
