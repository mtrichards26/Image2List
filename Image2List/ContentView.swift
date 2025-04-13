import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var checklistItems: [ChecklistItem] = []
    @State private var isShowingCamera = false
    @State private var isShowingImagePicker = false
    @State private var isShowingImage = false
    @State private var draggedItem: ChecklistItem?
    @State private var isShowingPhotoMenu = false
    @State private var isAddingNewItem = false
    @State private var newItemText = ""
    @State private var editingItem: ChecklistItem?
    @State private var editingText = ""
    @State private var isShowingSettings = false
    @AppStorage("useOpenAI") private var useOpenAI = false
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("keepScreenOn") private var isScreenLockDisabled = false
    @FocusState private var isEditingFocused: Bool
    @State private var isImagePickerPresented = false
    @State private var isCameraPresented = false
    @State private var recognizedItems: [String] = []
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @AppStorage("openaiEndpoint") private var openaiEndpoint = ""
    @AppStorage("customWords") private var customWordsString = ""
    @AppStorage("openaiModel") private var openaiModel = OpenAIConfig.defaultModel
    @AppStorage("extractionType") private var extractionType = ExtractionType.local
    @AppStorage("googleApiKey") private var googleApiKey = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @AppStorage("savedChecklistItems") private var savedChecklistItemsData: Data = Data()
    
    private var customWords: [String] {
        customWordsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private var imageProcessor: ImageProcessingStrategy {
        switch extractionType {
        case .local:
            return VisionStrategy(customWords: customWords)
        case .openai:
            return OpenAIStrategy(apiKey: openAIKey, endpoint: "https://api.openai.com/v1/chat/completions", model: openaiModel)
        case .google:
            return GeminiStrategy(apiKey: googleApiKey)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if isAddingNewItem {
                                HStack(spacing: 12) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(.gray)
                                    
                                    TextField("New item", text: $newItemText)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.black)
                                        .focused($isEditingFocused)
                                        .onSubmit {
                                            if !newItemText.isEmpty {
                                                let newItem = ChecklistItem(text: newItemText, originalIndex: checklistItems.count)
                                                checklistItems.append(newItem)
                                                newItemText = ""
                                                isAddingNewItem = false
                                            }
                                        }
                                    
                                    Button(action: {
                                        isAddingNewItem = false
                                        newItemText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.95, green: 0.97, blue: 0.95))
                            }
                            
                            ForEach($checklistItems) { $item in
                                VStack(spacing: 0) {
                                    if editingItem?.id == item.id {
                                        HStack(spacing: 12) {
                                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22))
                                                .foregroundColor(item.isChecked ? Color(red: 0.4, green: 0.7, blue: 0.4) : Color(red: 0.6, green: 0.6, blue: 0.6))
                                            
                                            TextField("Edit item", text: $editingText)
                                                .textFieldStyle(PlainTextFieldStyle())
                                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                                .focused($isEditingFocused)
                                                .onAppear {
                                                    editingText = item.text
                                                    isEditingFocused = true
                                                }
                                                .onSubmit {
                                                    if !editingText.isEmpty {
                                                        item.text = editingText
                                                        editingItem = nil
                                                        editingText = ""
                                                    }
                                                }
                                            
                                            Button(action: {
                                                editingItem = nil
                                                editingText = ""
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(red: 0.95, green: 0.97, blue: 0.95))
                                    } else {
                                        ChecklistItemRow(item: $item, onCheck: {
                                            checklistItems.sort()
                                        }, onDelete: {
                                            if let index = checklistItems.firstIndex(where: { $0.id == item.id }) {
                                                checklistItems.remove(at: index)
                                            }
                                        })
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 0.5)
                                                .onEnded { _ in
                                                    editingItem = item
                                                    editingText = item.text
                                                    isEditingFocused = true
                                                }
                                        )
                                        .onDrag {
                                            draggedItem = item
                                            return NSItemProvider(object: item.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: DropViewDelegate(item: item, items: $checklistItems, draggedItem: $draggedItem))
                                    }
                                    
                                    if item.id != checklistItems.last?.id {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.97))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(
                            Color(red: 0.95, green: 0.97, blue: 0.95)
                                .onTapGesture {
                                    // Close editor when tapping outside
                                    if editingItem != nil {
                                        editingItem = nil
                                        editingText = ""
                                    }
                                }
                        )
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            isShowingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                                .padding(12)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.4).opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        if selectedImage != nil {
                            Button(action: {
                                isShowingImage = true
                            }) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("View Image")
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.4).opacity(0.1))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            isAddingNewItem = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                                .padding(12)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.4).opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            isShowingPhotoMenu = true
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                                .padding(12)
                                .background(Color(red: 0.4, green: 0.7, blue: 0.4).opacity(0.1))
                                .clipShape(Circle())
                        }
                        .confirmationDialog("Add Photo", isPresented: $isShowingPhotoMenu) {
                            Button("Take Photo") {
                                isCameraPresented = true
                            }
                            Button("Choose Photo") {
                                isImagePickerPresented = true
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        
                        if selectedImage != nil {
                            Button(action: {
                                withAnimation {
                                    self.selectedImage = nil
                                    checklistItems = []
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(red: 0.7, green: 0.3, blue: 0.3))
                                    .padding(12)
                                    .background(Color(red: 0.7, green: 0.3, blue: 0.3).opacity(0.1))
                            }
                        }
                    }
                    .padding()
                }
                
                if isProcessing {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text(processingMessage)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            .background(Color(red: 0.95, green: 0.97, blue: 0.95))
            .navigationTitle("GrocerySnap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text("GrocerySnap")
                        if isScreenLockDisabled {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(
                Color(red: 0.4, green: 0.7, blue: 0.4),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: isScreenLockDisabled) { oldValue, newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
            .onAppear {
                // Apply screen lock setting when app launches
                UIApplication.shared.isIdleTimerDisabled = isScreenLockDisabled
                loadSavedState()
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraView(image: $selectedImage, onImageSelected: processImage)
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(image: $selectedImage, onImageSelected: processImage)
            }
            .sheet(isPresented: $isShowingImage) {
                if let selectedImage {
                    NavigationView {
                        GeometryReader { geometry in
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .navigationTitle("Image")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    isShowingImage = false
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(
                    isPresented: $isShowingSettings,
                    useOpenAI: $useOpenAI,
                    openAIKey: $openAIKey,
                    keepScreenOn: $isScreenLockDisabled,
                    extractionType: $extractionType,
                    googleApiKey: $googleApiKey,
                    openaiModel: $openaiModel
                )
            }
            .alert("Error", isPresented: $showingError, presenting: errorMessage) { _ in
                Button("OK") {
                    showingError = false
                }
                Button("Copy Error") {
                    UIPasteboard.general.string = errorMessage
                }
            } message: { error in
                Text(error)
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: checklistItems) { _, newItems in
            saveChecklistItems(newItems)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                saveImage(image)
            } else {
                deleteSavedImage()
            }
        }
    }
    
    private func loadSavedState() {
        // Load checklist items
        if !savedChecklistItemsData.isEmpty {
            if let decodedItems = try? JSONDecoder().decode([ChecklistItem].self, from: savedChecklistItemsData) {
                checklistItems = decodedItems
            }
        }
        
        // Load image
        if let image = loadSavedImage() {
            selectedImage = image
        }
    }
    
    private func saveChecklistItems(_ items: [ChecklistItem]) {
        if let encodedData = try? JSONEncoder().encode(items) {
            savedChecklistItemsData = encodedData
        }
    }
    
    private func saveImage(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("savedImage.jpg")
                try? data.write(to: fileURL)
            }
        }
    }
    
    private func loadSavedImage() -> UIImage? {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("savedImage.jpg")
            if fileManager.fileExists(atPath: fileURL.path) {
                if let data = try? Data(contentsOf: fileURL) {
                    return UIImage(data: data)
                }
            }
        }
        return nil
    }
    
    private func deleteSavedImage() {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("savedImage.jpg")
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    private func processImage(_ image: UIImage) async {
        isProcessing = true
        processingMessage = "Starting image processing..."
        errorMessage = nil
        
        let result = await imageProcessor.processImage(image) { message in
            processingMessage = message
        }
        
        DispatchQueue.main.async {
            if let error = result.error {
                errorMessage = error
                showingError = true
            } else {
                checklistItems = result.items.enumerated().map { (index, text) in
                    ChecklistItem(text: text, originalIndex: index)
                }
            }
            isProcessing = false
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: ChecklistItem
    @Binding var items: [ChecklistItem]
    @Binding var draggedItem: ChecklistItem?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem.id != item.id,
              let from = items.firstIndex(where: { $0.id == draggedItem.id }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        withAnimation {
            let item = items.remove(at: from)
            items.insert(item, at: to)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}


// Add this extension to help with text field cursor positioning
extension UITextField {
    static var current: UITextField? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first?.findFirstResponder() as? UITextField
        }
        return nil
    }
}

extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let firstResponder = subview.findFirstResponder() {
                return firstResponder
            }
        }
        return nil
    }
}
