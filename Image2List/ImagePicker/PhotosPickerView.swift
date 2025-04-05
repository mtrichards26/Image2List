//
//  PhotosPickerView.swift
//  Image2List
//
//  Created by Matt Richards on 4/5/25.
//
import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct PhotosPickerView: View {
    @State private var selectedItem: PhotosPickerItem?
    @Binding var selectedImage: UIImage?
    @State private var isProcessing = false
    let onImageSelected: (UIImage) async -> Void
    
    var body: some View {
        PhotosPicker(selection: $selectedItem,
                    matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(.bordered)
        .onChange(of: selectedItem) { oldItem, newItem in
            Task {
                if let newItem {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = image
                                isProcessing = true
                            }
                            
                            // Process the image
                            await onImageSelected(image)
                            
                            await MainActor.run {
                                isProcessing = false
                            }
                        }
                    } catch {
                        print("Error loading image: \(error)")
                        await MainActor.run {
                            isProcessing = false
                        }
                    }
                }
            }
        }
    }
}
