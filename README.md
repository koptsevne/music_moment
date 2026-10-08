# LiveWallpaper Custom Sounds

A macOS video wallpaper app with a built-in ambient mixer and support for your own audio files.

Based on [LiveWallpaper by Bao Nguyen](https://github.com/ducbao414/live-wallpaper).
This is an independently modified version, not an official upstream release.
The original MIT license and copyright are preserved in [LICENSE](LICENSE).

## Custom sounds

- Import an audio file from **Ambient Sounds → Add Custom Sound**.
- Imported audio is copied into the app's own storage. Moving or deleting the original does not break playback.
- Each sound has its own on/off switch and volume slider.
- Rename or remove custom sounds using the pencil and trash buttons.
- Custom sounds loop continuously and can play alongside the built-in sounds.
- Names, volume levels, and enabled states are saved between launches.
- Files with the same name are kept separately.
- Removing a sound deletes only the app's copy, never your original file.
- Invalid or missing audio files produce a visible error.

MP3, M4A, WAV, and AIFF are typical supported formats. Actual decoding depends on macOS's audio support; protected or unsupported files cannot be imported.

## Usage

1. Launch LiveWallpaper.
2. Add a video and choose **Set as Wallpaper**.
3. Open **Ambient Sounds**, click **Add Custom Sound**, and choose an audio file.
4. Enable **Enable Ambient Sounds Mixer**, then turn on your custom sound and adjust its volume.

After closing the main window, use the box icon in the macOS menu bar and select **Open Main UI** to reopen it.
The mixer is independent from the video's audio; mute the wallpaper video if you only want the ambient sounds.

## Build from source

Use a Mac with Xcode and a macOS SDK supporting the project's SwiftUI APIs.

```sh
xcodebuild -project LiveWallpaper.xcodeproj \
  -scheme LiveWallpaper -configuration Release \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The result is `build/Build/Products/Release/LiveWallpaper.app`.
For running locally, sign the application with your own development identity or an ad-hoc signature:

```sh
codesign --force --sign - \
  --entitlements LiveWallpaper/LiveWallpaper.entitlements \
  build/Build/Products/Release/LiveWallpaper.app
```

Local builds are not notarized by Apple. The app retains the upstream sandbox and read-only access to files selected by the user.
The default bundle identifier matches upstream, so installing this build can use the existing LiveWallpaper data container. Use a different bundle identifier when testing side by side.

## Tests

With Python 3 and the Swift command-line tools installed:

```sh
python3 scripts/test_audio.py
```

The tests generate their own audio in a temporary folder. They exercise legacy sound decoding, duplicate names, import validation, copied-file independence, persistence, renaming, looping, simultaneous playback, volume updates, stopping removed sounds, master mute, and missing-file errors. They do not read your wallpapers or audio library.

Manual interface checks cover importing through the file picker, renaming, switching sounds on and off, changing volume, and persistence after restarting the app.

## Upstream features

Video wallpapers, built-in ambient sounds, adaptive appearance, and power-saving controls are inherited from the original project.
