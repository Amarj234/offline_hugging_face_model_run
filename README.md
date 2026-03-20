# Llama Chat — Offline AI Messenger

A cross-platform Flutter application that runs Large Language Models (LLMs) locally on-device. It uses `llama.cpp` for high-performance inference and supports the GGUF model format.

---

## 🚀 Features

- **Local Inference** — Run AI models entirely offline for maximum privacy and zero latency.
- **Hugging Face Integration** — Browse and download GGUF models directly from Hugging Face.
- **Real-time Progress** — Track model downloads with persistent progress indicators and banners.
- **Streaming Chat** — Experience real-time token streaming for a natural conversation flow.
- **Customizable Parameters** — Full control over `temperature`, `max_tokens`, and `top_p`.
- **Modern UI** — Material 3 design with full Dark/Light mode support.

---

## 🛠️ Requirements

- **Flutter SDK** (Channel: Stable)
- **Dart SDK** (>= 3.0.0)
- **Android NDK** (24+) & **CMake** (3.22.1+)
- **Memory** — At least 4GB RAM is recommended for small models (e.g., Q4_K_M quantizations).

---

## 📦 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/Amarj234/offline_hugging_face_model_run.git
cd offline_hugging_face_model_run
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Native Setup (CRITICAL)
The `flutter_llama` package currently requires manual cloning of `llama.cpp` sources due to native build requirements.

```bash
# Clone llama.cpp into the package root (adjust path as needed)
cd ~/.pub-cache/hosted/pub.dev/flutter_llama-1.1.2/
git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
```

### 4. Run the App
```bash
flutter run
```

---

## 🏗️ Project Structure

```text
lib/
├── core/                # Constants, theme, and file utilities
├── features/
│   ├── chat/            # Chat screen, Llama service, and state providers
│   ├── models/          # Model browser, download service, and providers
│   └── settings/        # App settings and preference management
└── main.dart            # App entry point
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
