import AVFoundation
import Combine

class AudioMixer: ObservableObject {
    static let shared = AudioMixer()
    @Published var lastError: String?
    private var players: [String: AVAudioPlayer] = [:]
    private var failedIDs = Set<String>()

    func process(mixerEnabled: Bool, sounds: [Sound]) {
        let active = Set(sounds.filter { mixerEnabled && $0.isEnabled }.map(\.id))
        for id in Array(players.keys) where !active.contains(id) {
            players.removeValue(forKey: id)?.stop()
        }
        failedIDs.formIntersection(active)
        for sound in sounds where active.contains(sound.id) {
            if let player = players[sound.id] {
                player.volume = sound.volume
                continue
            }
            guard !failedIDs.contains(sound.id) else { continue }
            do {
                let url = sound.customFilename.flatMap { CustomSoundStore.url(for: $0) }
                    ?? (sound.isCustom ? nil : Bundle.main.url(forResource: sound.name, withExtension: "mp3"))
                guard let url else {
                    throw NSError(domain: "AudioMixer", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Audio file not found."])
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = sound.volume
                guard player.prepareToPlay(), player.play() else {
                    throw NSError(domain: "AudioMixer", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not start playback."])
                }
                players[sound.id] = player
            } catch {
                failedIDs.insert(sound.id)
                lastError = "\(sound.name): \(error.localizedDescription)"
            }
        }
    }
}
