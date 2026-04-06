# Gemma On-Device

A Flutter app that runs **Gemma 4 E2B** entirely on-device — no internet required after initial model download. Private, fast, offline AI chat for iOS and Android.

## What It Does

- Downloads the Gemma 4 E2B model (2.58 GB) on first launch
- Runs inference locally using GPU acceleration (Metal on iOS, OpenGL/Vulkan on Android)
- Streams responses token-by-token at ~52 tokens/second
- Works 100% offline after setup — no API keys, no server, no data leaves your device

## Requirements

- **iOS**: iPhone 14+ (6 GB RAM), iOS 16.0+
- **Android**: API 26+ (Android 8.0), 6+ GB RAM recommended
- **Storage**: ~3 GB free for the model file
- **First launch**: WiFi connection to download the model

## Getting Started

```bash
# Clone
git clone https://github.com/jimmykim/gemma-on-device.git
cd gemma-on-device

# Install dependencies
flutter pub get

# Run on device (not simulator — needs real GPU)
flutter run
```

The app will guide you through model download on first launch.

## Architecture

```
lib/
  main.dart                    — App entry + setup→chat routing
  services/
    gemma_service.dart         — Model download, GPU init, streaming inference
    performance_monitor.dart   — Thermal throttling + session limits
  screens/
    setup_screen.dart          — First-launch onboarding + download progress
    chat_screen.dart           — Streaming chat UI
  widgets/
    chat_bubble.dart           — Message bubbles
    typing_indicator.dart      — Typing animation
```

## Performance

| Device | Backend | RAM | TTFT | Decode Speed |
|--------|---------|-----|------|-------------|
| Samsung S26 Ultra | GPU | 676 MB | 0.3s | 52.1 tok/s |
| iPhone 17 Pro | GPU | 1,450 MB | 0.3s | 56.5 tok/s |

Built-in safeguards:
- 512-token generation cap to prevent thermal throttling
- 2-minute sustained generation limit with cooldown
- GPU-preferred backend for minimum memory footprint

## Tech Stack

- **Model**: [Gemma 4 E2B](https://ai.google.dev/gemma) by Google (2.3B effective params, multimodal)
- **Runtime**: LiteRT-LM (Android) / MediaPipe (iOS) via [`flutter_gemma`](https://pub.dev/packages/flutter_gemma)
- **Format**: `.litertlm` with mixed 2/4/8-bit quantization
- **Framework**: Flutter 3.41+, Dart 3.11+

## License

MIT
