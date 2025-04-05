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
    
    func processImage(_ image: UIImage, progress: @escaping (String) -> Void) async -> (items: [String], error: String?) {
        progress("Initializing Vision...")
        guard let cgImage = image.cgImage else { 
            return ([], "Failed to process image: Invalid image format")
        }
        
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
            
            guard let observations = request.results else { 
                return ([], "No text found in image")
            }
            
            progress("Extracting text from image...")
            let items = observations.enumerated().compactMap { (index, observation) -> String? in
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
