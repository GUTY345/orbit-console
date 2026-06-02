# Orbit Console

Orbit Console is an experimental iPadOS port/fork of the shadPS4 PlayStation 4 emulator core.
The goal of this branch is to explore a native iPad experience with UIKit, Metal/MoltenVK,
controller/touch overlays, low-memory diagnostics, and an ARM64 compatibility bridge for testing
PS4 titles on iPadOS.

> Important: this project is experimental research software. It is not a finished PS4 emulator for
> iPad yet. The current iPadOS work focuses on app shell, game library UI, input plumbing, memory
> survival, diagnostics, and early core bring-up.

## Current Status

Working or partially working:

- Native iPadOS app shell branded as **Orbit Console**
- PS4-style dashboard UI and settings panels
- Game import/library UI
- Full-screen iPad layout
- Virtual controller overlay
- Bluetooth controller input path
- Metal/MoltenVK view bridging
- iOS low-memory mode and sandbox backing file path
- StikDebug/JIT handshake delay path
- Diagnostic log file at `Documents/orbit_console_cpu.log`
- Chunked ELF segment loading diagnostics
- Experimental ARM64 custom CPU bridge scaffold

Still incomplete:

- Full x86-64 to ARM64 dynarec/JIT backend
- Complete x86-64 decoder coverage
- Complete SSE/AVX instruction support
- Full guest thread/TLS/exception parity
- Stable GPU presentation for real gameplay
- Finished audio output path on iPadOS

## Upstream Credit

This project is based on [shadPS4](https://github.com/shadps4-emu/shadPS4), an early PlayStation 4
emulator for Windows, Linux, and macOS written in C++.

All original shadPS4 copyright and GPL licensing terms remain in effect.

## Requirements

- macOS with Xcode installed
- iPad running iPadOS 18+
- Apple development signing configured in Xcode
- StikDebug or equivalent JIT/debug attach workflow for iPadOS testing
- CMake and the dependencies already prepared by the generated `build_ios` project

The current local test device used by this branch:

```text
Device ID: 00008122-001C199826FA401C
Bundle ID: com.mathachai.shadps4
App Name: Orbit Console
```

Adjust those values for your own device and developer account.

## Build for iPad

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

Example local command:

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

## Install on iPad

```sh
xcrun devicectl device install app \
  --device YOUR_DEVICE_ID \
  "build_ios/Debug-iphoneos/Orbit Console.app"
```

Example local command:

```sh
xcrun devicectl device install app \
  --device 00008122-001C199826FA401C \
  "/Users/mathachai/Downloads/shadPS4-main/build_ios/Debug-iphoneos/Orbit Console.app"
```

## Testing Games

1. Install Orbit Console on the iPad.
2. Open/attach using StikDebug before starting a game.
3. Open Orbit Console.
4. Add a game folder or `eboot.bin` through the dashboard.
5. Start the game from the dashboard.
6. If the app exits or returns to dashboard, pull the diagnostic log.

Only test games that you legally own and have dumped yourself.

## Pull Diagnostic Logs

Orbit Console writes a lightweight diagnostic log into the app container:

```text
Documents/orbit_console_cpu.log
```

Copy it from the iPad:

```sh
xcrun devicectl device copy from \
  --device YOUR_DEVICE_ID \
  --domain-type appDataContainer \
  --domain-identifier com.yourname.orbitconsole \
  --source Documents/orbit_console_cpu.log \
  --destination ~/Desktop/orbit_console_cpu.log
```

Example local command:

```sh
xcrun devicectl device copy from \
  --device 00008122-001C199826FA401C \
  --domain-type appDataContainer \
  --domain-identifier com.mathachai.shadps4 \
  --source Documents/orbit_console_cpu.log \
  --destination ~/Desktop/orbit_console_cpu.log
```

View the latest lines:

```sh
tail -300 ~/Desktop/orbit_console_cpu.log
```

Useful log markers:

```text
core stage 90: HLE libraries initialized
core stage 91: loading game module
Module loading segment bytes
ELF LoadSegment begin
ELF LoadSegment progress
ELF LoadSegment complete
CustomCPUTranslator unsupported opcode
```

## iPadOS Notes

iPadOS has stricter limits than macOS:

- No Rosetta 2 on iPadOS
- No native x86-64 execution
- JIT requires an external/debug attach path
- Free developer accounts have tighter memory limits
- Large contiguous virtual memory reservations can fail
- `shm_open` is not available the same way as desktop macOS

This fork uses a compact iOS address-space path and a sandbox backing file to get further into
module loading on device.

## CPU Bridge Status

The current ARM64 custom CPU bridge is a scaffold, not a complete replacement for Rosetta/FEX/Box64.
It currently provides:

- x86-64 register context
- RFLAGS basics
- REX/ModRM/SIB/RIP-relative decode helpers
- selected integer instructions
- selected XMM/SSE instructions
- unsupported-opcode logging with Zydis disassembly
- safe suspend path instead of crashing on unknown instructions

For real gameplay, the project still needs either:

- a real x86-64 interpreter with broad opcode/SIMD coverage, or
- a real x86-64 to AArch64 dynarec/JIT backend with block cache and iPadOS JIT support.

## Repository Hygiene

Recommended before pushing to your own GitHub repo:

```sh
git remote remove origin
git remote add origin https://github.com/GUTY345/orbit-console.git
git branch -M main
git push -u origin main
```

Do not commit local build output unless you intentionally want it in the repo. Common folders to
avoid committing:

```text
build_ios/
.codex_backups/
DerivedData/
*.xcuserdata
```

## Legal

This project does not include PS4 firmware, system modules, games, copyrighted assets, or keys.
You are responsible for using files dumped from hardware and games you legally own.

## License

Orbit Console is a fork/port of shadPS4 and remains licensed under GPL-2.0-or-later.
See [LICENSE](LICENSE) for details.
