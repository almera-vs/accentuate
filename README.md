# Accentuate

Accentuate is a macOS Input Method Kit (IMK) keyboard input source that applies SS13-style accent transformations while you type.

It ships with BeeStation accent data and includes accents such as Swedish, British, Canadian, French, Italian, Medieval, Roadman, and Scottish.

## What it does

- Buffers your current composition in the IME.
- Applies the accent engine before committing text to the app.
- Uses SS13-style ordered passes (`words`, `start`, `end`, `syllables`, optional `appends`) for parity with BeeStation behavior.

## Requirements

- macOS 13+
- Apple Silicon (current build target is `arm64-apple-macosx13.0`)
- Xcode command line tools (for `swiftc`)

## Build and install

```bash
./build.sh
./install.sh
```

Then add the input source:

1. Open `System Settings`.
2. Go to `Keyboard` -> `Text Input` -> `Edit`.
3. Press `+`, find `Accentuate`, and add it.

Optional helper to force registration if macOS has not picked it up yet:

```bash
./register.swift
```

## Usage

- Select `Accentuate` as your active input source.
- Type normally.
- Accent transformation is applied by the IME when composition is committed.
- Use the input-source menu to switch accent profile.

## Download and install (quick path)

1. Download `Accentuate.app.zip` from the latest GitHub Release.
2. Unzip it.
3. Copy `Accentuate.app` to `~/Library/Input Methods/`.
4. Run:

```bash
killall SystemUIServer
```

5. Open `System Settings` -> `Keyboard` -> `Text Input` -> `Edit` -> `+`.
6. Find `Accentuate` and add it.

## For maintainers: create release zip (no installer)

```bash
./build.sh
ditto -c -k --keepParent build/Accentuate.app Accentuate.app.zip
```

Upload `Accentuate.app.zip` to a GitHub Release so people can download and install by copying `Accentuate.app` into `~/Library/Input Methods`.

## Attribution

- Accent algorithm and data are based on BeeStation-Hornet:
  - https://github.com/BeeStation/BeeStation-Hornet
- Vendored reference used by this app is included in `reference/beestation/`.

## License

This repository is licensed under the GNU Affero General Public License v3.0. See `LICENSE`.

Third-party attribution details are in `COPYING.third-party`.
