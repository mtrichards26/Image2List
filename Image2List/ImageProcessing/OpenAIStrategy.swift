//
//  OpenAIStrategy.swift
//  Image2List
//
//  Created by Matt Richards on 4/4/25.
//
import SwiftUI
import Vision

class OpenAIStrategy: ImageProcessingStrategy {
    private let apiKey: String
    private let endpoint: String
    private let model: String
    
    init(apiKey: String, endpoint: String, model: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [String], error: String?) {
        progress("Preparing image for OpenAI...")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return ([], "Failed to convert image to JPEG format")
        }
        let base64Image = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": chatText
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
            return ([], "Failed to create OpenAI request")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            progress("Sending image to OpenAI...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        return ([], "OpenAI API error: \(message)")
                    }
                    return ([], "OpenAI API error: HTTP \(httpResponse.statusCode)")
                }
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                progress("Processing OpenAI response...")
                // Clean and parse the content
                let cleanedContent = content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let jsonData = cleanedContent.data(using: .utf8),
                   let items = try? JSONDecoder().decode([String].self, from: jsonData) {
                    return (items, nil)
                } else {
                    // If JSON parsing fails, try to parse as plain text
                    let items = cleanedContent
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    return (items, nil)
                }
            }
            
            return ([], "Failed to parse OpenAI response")
        } catch {
            return ([], "OpenAI API error: \(error.localizedDescription)")
        }
    }
}
