//
//  GeminiStrategy.swift
//  Image2List
//
//  Created by Matt Richards on 4/4/25.
//
import SwiftUI
import Vision

// Google Gemini Configuration — multimodal models (validated against ai.google.dev/gemini-api/docs/models)
struct GeminiConfig {
    static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    static let availableModels = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro"
    ]
    static let defaultModel = "gemini-2.5-flash"
}

class GeminiStrategy: ImageProcessingStrategy {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String = GeminiConfig.defaultModel) {
        self.apiKey = apiKey
        self.model = model
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [GroceryItemResult], error: String?) {
        progress("Preparing image for Google Gemini...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return ([], "Failed to convert image to JPEG format")
        }
        let base64Image = imageData.base64EncodedString()
        
        let endpoint = "\(GeminiConfig.baseURL)/\(model):generateContent"
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": chatText
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
            return ([], "Failed to create Gemini request")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            progress("Sending image to Google Gemini...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        return ([], "Gemini API error: \(message)")
                    }
                    return ([], "Gemini API error: HTTP \(httpResponse.statusCode)")
                }
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                progress("Processing Gemini response...")
                let cleanedContent = text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let items = parseGroceryItemsFromJSON(cleanedContent) {
                    return (items, nil)
                }
                let fallbackItems = cleanedContent
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map { GroceryItemResult(text: $0, section: .other) }
                return (fallbackItems, nil)
            }
            
            return ([], "Failed to parse Gemini response")
        } catch {
            return ([], "Gemini API error: \(error.localizedDescription)")
        }
    }
} 
