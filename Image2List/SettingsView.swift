import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var useOpenAI: Bool
    @Binding var openAIKey: String
    @Binding var keepScreenOn: Bool
    @AppStorage("openaiModel") private var openaiModel = OpenAIConfig.defaultModel
    @AppStorage("extractionType") private var extractionType = ExtractionType.local
    @AppStorage("googleApiKey") private var googleApiKey = ""
    
    @State private var tempOpenAIKey: String = ""
    @State private var showingKeyAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("List Extraction")) {
                    Picker("Extraction Type", selection: $extractionType) {
                        ForEach(ExtractionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if extractionType == .openai {
                        TextField("OpenAI API Key", text: $openAIKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Picker("Model", selection: $openaiModel) {
                            ForEach(OpenAIConfig.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    } else if extractionType == .google {
                        TextField("Google API Key", text: $googleApiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("Display")) {
                    Toggle("Keep Screen On", isOn: $keepScreenOn)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
} 