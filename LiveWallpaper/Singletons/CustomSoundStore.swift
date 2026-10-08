import Foundation
import AVFoundation

/// Owns copies only; imported originals are never modified.
enum CustomSoundStore {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomAmbientSounds", isDirectory: true)
    }

    static func url(for filename: String) -> URL? {
        guard !filename.isEmpty, filename == (filename as NSString).lastPathComponent,
              filename != ".", filename != ".." else { return nil }
        return directory.appendingPathComponent(filename)
    }

    static func importSound(from source: URL) throws -> Sound {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        let probe = try AVAudioPlayer(contentsOf: source)
        guard probe.duration > 0, probe.prepareToPlay() else {
            throw NSError(domain: "CustomSound", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "This file does not contain supported audio."])
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
        let destination = url(for: filename)!
        try FileManager.default.copyItem(at: source, to: destination)
        return Sound(name: source.deletingPathExtension().lastPathComponent,
                     isEnabled: false, volume: 0.5, customFilename: filename)
    }

    static func deleteCopy(of sound: Sound) throws {
        guard let filename = sound.customFilename, let url = url(for: filename) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
