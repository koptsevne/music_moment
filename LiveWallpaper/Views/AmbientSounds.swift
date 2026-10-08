import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AmbientSounds: View {
    @ObservedObject var userSetting = UserSetting.shared
    @ObservedObject var mixer = AudioMixer.shared
    @State private var errorMessage: String?
    @State private var importing = false
    @State private var renameID: String?
    @State private var newName = ""
    @State private var pendingDelete: Sound?
    private let columns = [GridItem(.adaptive(minimum: 185), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Toggle("Enable Ambient Sounds Mixer", isOn: $userSetting.mixerEnabled)
                    .toggleStyle(.switch)
                Spacer()
                Button(action: chooseSound) {
                    Label(importing ? "Importing…" : "Add Custom Sound", systemImage: "plus")
                }
                .disabled(importing)
            }
            Text("MP3, M4A, WAV, AIFF. Imported sounds are stored in the app and loop continuously.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = errorMessage ?? mixer.lastError {
                HStack {
                    Text(message).foregroundStyle(.red).textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") { errorMessage = nil; mixer.lastError = nil }
                }
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach($userSetting.sounds) { $sound in
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $sound.isEnabled) {
                                Text(sound.name).font(.headline).lineLimit(2).help(sound.name)
                            }
                            .toggleStyle(.switch)
                            .disabled(!userSetting.mixerEnabled)
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                Slider(value: $sound.volume, in: 0...1)
                                    .accessibilityLabel("Volume: " + sound.name)
                                Text("\(Int(sound.volume * 100))%")
                                    .monospacedDigit().font(.caption).frame(width: 36)
                            }
                            .disabled(!userSetting.mixerEnabled || !sound.isEnabled)
                            HStack {
                                Text(sound.isCustom ? "Custom sound" : "Built-in")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                if sound.isCustom {
                                    Button { newName = sound.name; renameID = sound.id } label: {
                                        Image(systemName: "pencil")
                                    }.help("Rename").accessibilityLabel("Rename " + sound.name)
                                    Button { pendingDelete = sound } label: {
                                        Image(systemName: "trash")
                                    }.help("Remove from app").accessibilityLabel("Remove " + sound.name)
                                }
                            }
                        }
                        .padding(14)
                        .frame(minHeight: 110)
                        .background(RoundedRectangle(cornerRadius: 12).fill(
                            sound.isEnabled && userSetting.mixerEnabled
                                ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.09)))
                    }
                }
            }
        }
        .padding(20)
        .navigationTitle("Ambient Sounds")
        .frame(minWidth: 550, minHeight: 400)
        .alert("Sound Name", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, let index = userSetting.sounds.firstIndex(where: { $0.id == renameID }) {
                    userSetting.sounds[index].name = name
                }
                renameID = nil
            }
            Button("Cancel", role: .cancel) { renameID = nil }
        }
        .alert("Remove custom sound?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Remove", role: .destructive) { removeSound() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Only the copy stored in the app will be removed. Your original audio file will be kept.")
        }
    }

    private func chooseSound() {
        let panel = NSOpenPanel()
        panel.title = "Add Custom Sound"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            importing = true
            Task {
                do {
                    let sound = try await Task.detached(priority: .userInitiated) {
                        try CustomSoundStore.importSound(from: url)
                    }.value
                    userSetting.sounds.insert(sound, at: 0)
                } catch { errorMessage = error.localizedDescription }
                importing = false
            }
        }
    }

    private func removeSound() {
        guard let sound = pendingDelete else { return }
        do {
            try CustomSoundStore.deleteCopy(of: sound)
            userSetting.sounds.removeAll { $0.id == sound.id }
        } catch { errorMessage = error.localizedDescription }
        pendingDelete = nil
    }
}
