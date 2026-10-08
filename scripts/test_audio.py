from pathlib import Path
import subprocess, wave, struct, math, tempfile
root=Path(__file__).resolve().parent.parent
folder=Path(tempfile.mkdtemp(prefix='livewallpaper-audio-tests-'))
folder.mkdir(exist_ok=True)
with wave.open(str(folder/'source.wav'),'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000)
    w.writeframes(b''.join(struct.pack('<h', int(1000*math.sin(i*2*math.pi*440/8000))) for i in range(1600)))
(folder/'invalid.wav').write_text('not audio')
model=(root/'LiveWallpaper/Singletons/UserSetting.swift').read_text()
sound=model[model.index('struct Sound:'):model.index('class UserSetting:')]
(folder/'Sound.swift').write_text('import Foundation\n'+sound)
store=(root/'LiveWallpaper/Singletons/CustomSoundStore.swift').read_text()
start=store.index('        FileManager.default.urls')
end=store.index('\n    }',start)
store=store[:start]+'        URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("copies")'+store[end:]
(folder/'CustomSoundStore.swift').write_text(store)
(folder/'Tests.swift').write_text(r'''import Foundation
import AVFoundation

@main struct Tests {
 static func main() throws {
    let dir = URL(fileURLWithPath: CommandLine.arguments[1])
    let legacy = Data(#"[{"name":"rain","isEnabled":false,"volume":0.5}]"#.utf8)
    let builtins = try JSONDecoder().decode([Sound].self, from: legacy)
    precondition(!builtins[0].isCustom && builtins[0].id == "builtin:rain")
    var first = try CustomSoundStore.importSound(from: dir.appendingPathComponent("source.wav"))
    var second = try CustomSoundStore.importSound(from: dir.appendingPathComponent("source.wav"))
    precondition(first.name == second.name && first.id != second.id)
    precondition(CustomSoundStore.url(for: "../source.wav") == nil)
    let copy = CustomSoundStore.url(for: first.customFilename!)!
    let bytes = try Data(contentsOf: copy)
    precondition(bytes == (try? Data(contentsOf: dir.appendingPathComponent("source.wav"))))
    try FileManager.default.moveItem(at: dir.appendingPathComponent("source.wav"), to: dir.appendingPathComponent("moved.wav"))
    let probe = try AVAudioPlayer(contentsOf: copy)
    precondition(probe.duration > 0)
    first.name = "My custom sound"
    first.isEnabled = true; first.volume = 0
    second.isEnabled = true; second.volume = 0
    let saved = try JSONEncoder().encode([first, second])
    try saved.write(to: dir.appendingPathComponent("saved.json"))
    let restored = try JSONDecoder().decode([Sound].self, from: Data(contentsOf: dir.appendingPathComponent("saved.json")))
    precondition(restored[0].name == "My custom sound" && restored[0].id == first.id && restored[0].isEnabled)
    let mixer = AudioMixer()
    func players() -> [String: AVAudioPlayer] {
        Mirror(reflecting: mixer).children.first { $0.label == "players" }!.value as! [String: AVAudioPlayer]
    }
    mixer.process(mixerEnabled: true, sounds: restored)
    precondition(players().count == 2 && players().values.allSatisfy { $0.isPlaying && $0.numberOfLoops == -1 })
    first.volume = 0.001
    mixer.process(mixerEnabled: true, sounds: [first, second])
    precondition(players()[first.id]!.volume == 0.001)
    mixer.process(mixerEnabled: true, sounds: [second])
    precondition(players().count == 1 && players()[first.id] == nil)
    mixer.process(mixerEnabled: false, sounds: [second])
    precondition(players().isEmpty)
    do {
        _ = try CustomSoundStore.importSound(from: dir.appendingPathComponent("invalid.wav"))
        fatalError("invalid audio accepted")
    } catch {}
    try CustomSoundStore.deleteCopy(of: first)
    precondition(!FileManager.default.fileExists(atPath: copy.path))
    precondition(FileManager.default.fileExists(atPath: dir.appendingPathComponent("moved.wav").path))
    mixer.process(mixerEnabled: true, sounds: [first])
    precondition(mixer.lastError != nil && players().isEmpty)
    try CustomSoundStore.deleteCopy(of: second)
    print("PASS: legacy settings, duplicate names, import validation, owned copies, moved original, persistence, rename, mixing, loop, volume, stop on delete, master toggle, missing-file error, safe deletion")
 }
}
''')
subprocess.run(['swiftc','-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-swift-version','5',str(folder/'Sound.swift'),str(folder/'CustomSoundStore.swift'),str(root/'LiveWallpaper/Singletons/AudioMixer.swift'),str(folder/'Tests.swift'),'-o',str(folder/'CustomSoundTests')],check=True)
subprocess.run([str(folder/'CustomSoundTests'),str(folder)],check=True)
