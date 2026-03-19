//
//  VisionStrategy.swift
//  Image2List
//
//  Created by Matt Richards on 4/4/25.
//
import SwiftUI
import Vision

class VisionStrategy: ImageProcessingStrategy {
    private let customWords: [String]
    
    init(customWords: [String]) {
        self.customWords = customWords
    }
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [GroceryItemResult], error: String?) {
        progress("Initializing Vision...")
        guard let cgImage = image.cgImage else {
            return ([], "Failed to process image: Invalid image format")
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01
        request.customWords = customWords
        
        do {
            progress("Processing image with Vision...")
            try requestHandler.perform([request])
            
            guard let observations = request.results else {
                return ([], "No text found in image")
            }
            
            progress("Extracting text from image...")
            let items: [GroceryItemResult] = observations.enumerated().compactMap { (_, observation) in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                let cleanedText = cleanText(text)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleanedText.count > 1 else { return nil }
                return GroceryItemResult(text: cleanedText, section: .other)
            }
            return (items, nil)
        } catch {
            return ([], "Vision processing error: \(error.localizedDescription)")
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
