import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var useOpenAI: Bool
    @Binding var openAIKey: String
    @Binding var keepScreenOn: Bool
    @Binding var extractionType: ExtractionType
    @Binding var googleApiKey: String
    @Binding var openaiModel: String
    
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
                        SecureField("OpenAI API Key", text: $openAIKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            
                        Picker("Model", selection: $openaiModel) {
                            ForEach(OpenAIConfig.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    } else if extractionType == .google {
                        SecureField("Google API Key", text: $googleApiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("Display")) {
                    Toggle("Keep Screen On", isOn: $keepScreenOn)
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("GrocerySnap")
                                .font(.headline)
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
} 
