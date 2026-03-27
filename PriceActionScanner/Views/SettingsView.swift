import SwiftUI

struct SettingsView: View {
    @ObservedObject private var storage = StorageService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenRouter API Key") {
                    SecureField("sk-or-...", text: $storage.openRouterAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if storage.openRouterAPIKey.isEmpty {
                        Label("需要 API Key 才能使用 AI 分析功能", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section("AI 模型") {
                    Picker("模型", selection: $storage.selectedModel) {
                        ForEach(availableModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("数据管理") {
                    Button(role: .destructive) {
                        StorageService.shared.clearAnalysisHistory()
                    } label: {
                        Label("清除分析历史", systemImage: "trash")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PriceAction Scanner v1.0")
                            .font(.subheadline).fontWeight(.medium)
                        Text("基于 Al Brooks 价格行为学")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("仅供学习参考，不构成投资建议")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
