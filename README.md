# Gemma On-Device

A Flutter app that runs **Gemma 4 E2B** entirely on-device — no internet required after initial model download. Private, fast, offline AI chat.

> **Platform note:** Currently **Android only**. iOS support is blocked until Google ships the LiteRT-LM Swift API (the `.litertlm` model format doesn't work on iOS yet).

## What It Does

- Downloads the Gemma 4 E2B model (2.4 GB) on first launch
- Runs inference locally using GPU acceleration (OpenGL ES / Vulkan)
- Streams responses token-by-token at ~52 tokens/second
- Works 100% offline after setup — no API keys, no server, no data leaves your device

## Requirements

- **Android**: API 26+ (Android 8.0), 6+ GB RAM recommended
- **Storage**: ~3 GB free for the model file
- **First launch**: WiFi connection to download the model
- **No HuggingFace token needed** — the model is publicly hosted

## Getting Started

```bash
# Clone
git clone https://github.com/jimbo111/gemma-on-device.git
cd gemma-on-device

# Install dependencies
flutter pub get

# Run on Android device (not emulator — needs real GPU)
flutter run
```

The app will guide you through model download on first launch.

## Architecture

```
lib/
  main.dart                    — App entry + setup->chat routing
  theme/
    app_theme.dart             — Dark theme system
  services/
    gemma_service.dart         — Model download, GPU init, streaming inference
    performance_monitor.dart   — Thermal throttling + session limits
  screens/
    setup_screen.dart          — First-launch onboarding + download progress
    chat_screen.dart           — Streaming chat UI
  widgets/
    chat_bubble.dart           — Animated message bubbles
    typing_indicator.dart      — Pulsing dot indicator
```

## Performance

| Device | Backend | RAM | TTFT | Decode Speed |
|--------|---------|-----|------|-------------|
| Samsung S26 Ultra | GPU | 676 MB | 0.3s | 52.1 tok/s |
| Samsung S24 Ultra | GPU | ~700 MB | 0.3s | ~50 tok/s |

Built-in safeguards:
- 512-token generation cap to prevent thermal throttling
- 2-minute sustained generation limit with cooldown
- GPU-preferred backend for minimum memory footprint

## Tech Stack

- **Model**: [Gemma 4 E2B](https://ai.google.dev/gemma) by Google (2.3B effective params, multimodal)
- **Runtime**: LiteRT-LM via [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) v0.13.1
- **Format**: `.litertlm` with mixed 2/4/8-bit quantization
- **Framework**: Flutter 3.41+, Dart 3.11+

## Why Android Only?

Gemma 4 E2B uses the `.litertlm` model format which requires Google's LiteRT-LM runtime. On Android, this works natively. On iOS, Google hasn't shipped the LiteRT-LM Swift API yet — the iOS path still uses MediaPipe which only supports the older `.task` format. There are no Gemma 4 `.task` files available for iOS.

When Google ships the iOS LiteRT-LM API, adding iOS support will be a one-line backend change.

## License

MIT
