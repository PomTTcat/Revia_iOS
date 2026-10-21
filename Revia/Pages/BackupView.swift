import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var language: AppLanguage
    @EnvironmentObject private var store: Store
    @State private var importing = false
    @State private var exportFile: SharedFile?
    @State private var exportURL: URL?
    @State private var backupMessage: String?
    var body: some View {
        let _ = language.code
        Form {
            Section {
                Button { exportBackup() } label: { Label(L("export_json"), systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label(L("import_json"), systemImage: "square.and.arrow.down") }
            } header: { Text(L("backup")) } footer: { Text(L("backup_note")) }
        }
        .navigationTitle(L("backup_menu"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let count = try store.importBackup(Data(contentsOf: url))
                backupMessage = L("import_done", count)
            } catch { backupMessage = error.localizedDescription }
        }
        .sheet(item: $exportFile, onDismiss: {
            if let exportURL { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent()) }
            exportURL = nil
        }) { file in
            ShareSheet(url: file.url)
        }
        .alert(L("backup"), isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
            Button(L("ok"), role: .cancel) { backupMessage = nil }
        } message: { Text(backupMessage ?? "") }
    }
    private func exportBackup() {
        do {
            let data = try store.exportBackup()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Revia-\(Schedule.key(Date())).json")
            try data.write(to: url, options: .atomic)
            exportURL = url
            exportFile = SharedFile(url: url)
        } catch { backupMessage = error.localizedDescription }
    }

}
