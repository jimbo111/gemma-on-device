# Gemma On-Device

A Flutter app that runs **Gemma 4 E2B** entirely on-device — no internet required after initial model download. Private, fast, offline AI chat.

> **Platform note:** Currently **Android only**. The model ships as `.litertlm`, which needs LiteRT-LM; `flutter_gemma`'s iOS plugin is MediaPipe-only.

## What It Does

- Downloads the Gemma 4 E2B model (2.6 GB) on first launch, as a foreground download with a progress notification
- Runs inference locally on the GPU (OpenCL), falling back to CPU if the GPU backend fails to initialize
- Streams responses token by token
- Works 100% offline after setup — no API keys, no server, no data leaves your device

## Requirements

- **Android**: API 26+ (Android 8.0), 6+ GB RAM recommended
- **Storage**: ~3 GB free for the model file
- **First launch**: Wi-Fi to download the model; on Android 13+ allow notifications so the download keeps running in the background
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

Run the tests with `flutter test`.

## Architecture

```
lib/
  main.dart                    — App entry + setup->chat routing
  theme/
    app_theme.dart             — Dark theme system
  services/
    gemma_service.dart         — Model download, load (GPU, CPU fallback), streaming chat
    context_budget.dart        — Context-window accounting; resets the conversation before it overflows
    performance_monitor.dart   — Sustained-generation cooldown
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

Built-in limits:
- Replies are capped at 512 tokens.
- The model's context window is 2,048 tokens. When the next prompt plus a full reply would not fit, the app starts a fresh conversation and marks it in the chat.
- After 2 minutes of sustained generation (idle gaps under 10 s count as sustained), the current reply stops and sending is paused for 10 s.

## Tech Stack

- **Model**: [Gemma 4 E2B](https://ai.google.dev/gemma) by Google (2.3B effective params, multimodal)
- **Runtime**: LiteRT-LM via [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) v0.13.1
- **Format**: `.litertlm` with mixed 2/4/8-bit quantization
- **Framework**: Flutter 3.41+, Dart 3.11+

## Why Android Only?

Gemma 4 E2B ships in the `.litertlm` format, which requires Google's LiteRT-LM runtime. On Android, `flutter_gemma` uses LiteRT-LM directly. On iOS it still uses MediaPipe, which only loads the older `.task` format, and there is no Gemma 4 E2B `.task` build.

iOS support depends on `flutter_gemma` loading `.litertlm` on iOS. The `ios/` scaffold is kept for that.

## License

MIT
