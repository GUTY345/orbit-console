<p align="center">
  <img src="documents/orbit-console/assets/app-icon.png" alt="Orbit Console app icon" width="128">
</p>

<h1 align="center">Orbit Console</h1>

<p align="center">
  Experimental iPadOS port of the shadPS4 PlayStation 4 emulator core.
</p>

<p align="center">
  <strong>Native iPad UI</strong> · <strong>Metal / MoltenVK</strong> · <strong>Touch + Controller Input</strong> · <strong>ARM64 Bring-up</strong>
</p>

## Screenshots

<img src="documents/orbis-console/screenshots/users.PNG" width="120" height="80"/>
<img src="documents/orbis-console/screenshots/home.PNG" width="120" height="80"/>
<img src="documents/orbis-console/screenshots/settings.PNG" width="120" height="80"/>

## About

Orbit Console is a personal experimental fork of [shadPS4](https://github.com/shadps4-emu/shadPS4)
focused on exploring whether the emulator core can be brought up inside a native iPadOS app shell.

The app side is designed around a console-style experience:

- PS4-inspired dashboard layout
- game library import flow
- profile/user selection flow
- settings menu for system, graphics, audio, input, appearance, and debug options
- virtual DualShock-style touch controller
- Bluetooth controller navigation
- in-game overlay for FPS/RAM/debug status and quick actions

The core side is currently focused on iPadOS survival work:

- compact iOS address-space layout
- sandbox-friendly memory backing file
- StikDebug/JIT handshake delay path
- low-memory diagnostics
- Metal/MoltenVK surface bridge
- chunked ELF segment loading logs
- experimental ARM64 custom CPU bridge scaffold

## Current Status

This repository is not a finished iPad PS4 emulator yet. It is a work-in-progress research port.

Working or partially working:

- Orbit Console native iPadOS app shell
- full-screen iPad dashboard
- game import and library UI
- settings panels
- virtual controller overlay
- external controller input path
- diagnostics log output
- early shadPS4 core initialization on iPadOS
- HLE library registration
- module loading diagnostics

Still incomplete:

- full x86-64 to ARM64 dynarec/JIT backend
- broad x86-64 interpreter coverage
- complete SSE/AVX support
- complete guest thread/TLS/exception behavior
- stable GPU presentation for real gameplay
- finished iPadOS audio output

## Requirements

- macOS with Xcode
- iPadOS 18+
- iPad with Apple Silicon, tested during development on iPad Air M3
- Apple development signing configured
- StikDebug or equivalent debug/JIT attach workflow
- legally dumped PS4 games and firmware/system modules where required

## Build

From the repository root:

```sh
xcodebuild \
  -project build_ios/shadPS4.xcodeproj \
  -scheme shadps4 \
  -configuration Debug \
  -destination 'id=YOUR_DEVICE_ID' \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  PRODUCT_BUNDLE_IDENTIFIER=com.yourname.orbitconsole \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development' \
  build
```

Local example:

```sh
xcodebuild \
  -project build_ios/shadPS4.xcodeproj \
  -scheme shadps4 \
  -configuration Debug \
  -destination 'id=00008122-001C199826FA401C' \
  DEVELOPMENT_TEAM=4HX756P7TJ \
  PRODUCT_BUNDLE_IDENTIFIER=com.mathachai.shadps4 \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY='Apple Development' \
  build
```

## Install

```sh
xcrun devicectl device install app \
  --device YOUR_DEVICE_ID \
  "build_ios/Debug-iphoneos/Orbit Console.app"
```

Local example:

```sh
xcrun devicectl device install app \
  --device 00008122-001C199826FA401C \
  "/Users/mathachai/Downloads/shadPS4-main/build_ios/Debug-iphoneos/Orbit Console.app"
```

## Test Flow

1. Install Orbit Console on the iPad.
2. Attach/open the app through StikDebug before starting a game.
3. Add a dumped game folder or `eboot.bin` from the dashboard.
4. Press Start Game.
5. If the app exits, copy `orbit_console_cpu.log` from the device.

## Diagnostic Logs

Orbit Console writes its device-side diagnostic log here:

```text
Documents/orbit_console_cpu.log
```

Copy the log from the iPad:

```sh
xcrun devicectl device copy from \
  --device YOUR_DEVICE_ID \
  --domain-type appDataContainer \
  --domain-identifier com.yourname.orbitconsole \
  --source Documents/orbit_console_cpu.log \
  --destination ~/Desktop/orbit_console_cpu.log
```

Local example:

```sh
xcrun devicectl device copy from \
  --device 00008122-001C199826FA401C \
  --domain-type appDataContainer \
  --domain-identifier com.mathachai.shadps4 \
  --source Documents/orbit_console_cpu.log \
  --destination ~/Desktop/orbit_console_cpu.log
```

View the latest entries:

```sh
tail -300 ~/Desktop/orbit_console_cpu.log
```

Useful markers:

```text
core stage 90: HLE libraries initialized
core stage 91: loading game module
Module loading segment bytes
ELF LoadSegment begin
ELF LoadSegment progress
ELF LoadSegment complete
CustomCPUTranslator unsupported opcode
```

## App Icon and Screenshot Assets

Use these paths when adding images to the repository:

```text
documents/orbit-console/assets/app-icon.png
documents/orbit-console/screenshots/dashboard.png
documents/orbit-console/screenshots/settings.png
documents/orbit-console/screenshots/game-overlay.png
documents/orbit-console/screenshots/profile.png
```

After adding or replacing images:

```sh
git add documents/orbit-console README.md
git commit -m "Add Orbit Console screenshots"
git push
```

## iPadOS Notes

iPadOS is not macOS:

- there is no Rosetta 2 on iPadOS
- x86-64 PS4 code cannot run natively on ARM64
- JIT/debug permission needs an attach workflow such as StikDebug
- free developer accounts have tighter memory ceilings
- large contiguous virtual memory mappings can fail
- desktop-only APIs such as `shm_open` need iOS-safe alternatives

## CPU Bridge Status

The current ARM64 custom CPU bridge is an early scaffold, not a complete emulator backend.

It currently includes:

- guest x86-64 register context
- RFLAGS basics
- REX/ModRM/SIB/RIP-relative decode helpers
- selected integer instructions
- selected XMM/SSE instructions
- Zydis-based unsupported opcode logging
- safe suspend path for unsupported instructions

Real gameplay still requires a much deeper solution:

- broad interpreter coverage, or
- x86-64 to AArch64 dynarec/JIT with block cache, syscall/HLE dispatch, thread/TLS handling, and
  exception bridging.

## Repository

GitHub:

```text
https://github.com/GUTY345/orbit-console
```

Recommended ignored local output:

```text
build_ios/
.codex_backups/
.zhanlu/
DerivedData/
*.xcuserdata
```

## Legal

This repository does not include PS4 firmware, system modules, games, copyrighted assets, or keys.
Only use files dumped from hardware and games you legally own.

## Upstream and License

Orbit Console is based on [shadPS4](https://github.com/shadps4-emu/shadPS4).

This project remains licensed under GPL-2.0-or-later. See [LICENSE](LICENSE).

