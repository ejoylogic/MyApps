import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var newRangeText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Select Video") {
                    appModel.pickSourceVideo()
                }
                Text(appModel.sourceURL?.lastPathComponent ?? "No video selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Button("Select Output Folder") {
                    appModel.pickOutputFolder()
                }
                Text(appModel.outputFolderURL?.path ?? "No folder selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ResolutionPicker(selection: $appModel.selectedResolution)

            VStack(alignment: .leading, spacing: 8) {
                Text("Clip Ranges")
                    .font(.headline)
                HStack {
                    TextField("00:02:10 - 00:02:45", text: $newRangeText)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        appModel.addClipRange(from: newRangeText)
                        newRangeText = ""
                    }
                }
                Text("Paste multiple lines to add in bulk.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                List {
                    ForEach(appModel.clips) { clip in
                        ClipRowView(clip: clip)
                    }
                    .onDelete(perform: appModel.deleteClips)
                }
                .frame(minHeight: 200)
            }

            HStack {
                Button("Export Clips") {
                    appModel.startExport()
                }
                .disabled(!appModel.canExport)

                if appModel.isExporting {
                    ProgressView(value: appModel.overallProgress)
                        .frame(width: 200)
                }
                Spacer()
            }

            if let message = appModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(appModel.statusColor)
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 520)
        .alert(item: $appModel.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct ClipRowView: View {
    let clip: ClipItem

    var body: some View {
        HStack {
            Text(clip.displayRange)
            Spacer()
            if let progress = clip.progress {
                ProgressView(value: progress)
                    .frame(width: 140)
            }
            Text(clip.status.displayText)
                .foregroundColor(clip.status.color)
        }
    }
}

struct ResolutionPicker: View {
    @Binding var selection: OutputResolution

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output Resolution")
                .font(.headline)
            Picker("Resolution", selection: $selection) {
                ForEach(OutputResolution.options) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if case .custom(let width, let height) = selection {
                HStack {
                    Text("Custom")
                    TextField("Width", value: Binding(
                        get: { width },
                        set: { selection = .custom(width: $0, height: height) }
                    ), formatter: NumberFormatter())
                    .frame(width: 80)

                    TextField("Height", value: Binding(
                        get: { height },
                        set: { selection = .custom(width: width, height: $0) }
                    ), formatter: NumberFormatter())
                    .frame(width: 80)
                }
            }
        }
    }
}
