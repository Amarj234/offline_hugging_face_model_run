# AI Chat Offline — Professional LLM Messenger

A premium, cross-platform Flutter application designed for high-performance, private, and 100% offline Large Language Model (LLM) inference. Powered by `llama.cpp` and optimized for both flagship and budget-to-mid-range hardware.

---

## 🌟 Key Features

- **Private & Offline** — All AI inference happens 100% on-device. No data ever leaves your machine.
- **Global Model Discovery** — Search and download thousands of GGUF models directly from the Hugging Face hub.
- **Professional Indigo Theme** — A sophisticated "Deep Slate & Indigo" aesthetic with premium typography (Inter) and adaptive UI components.
- **Smart Persistence** — The app remembers your last used model and automatically loads it on startup.
- **Hardware Optimized** — Intelligent inference settings and safety timeouts ensure stability on devices with limited RAM.
- **Streaming & Non-Streaming** — Versatile chat modes for the best balance of speed and stability.

---

## 📖 How to Use AI Chat Offline

Follow these simple steps to get started with your private AI assistant:

### Step 1: Open the Explore Models Page
Tap the **Explore Models** icon (or the model chip in the chat bar) to manage your AI models.

### Step 2: Discover New Models
Switch to the **DISCOVER** tab. Use the **Search Bar** to find specific models (e.g., search for "Llama 3.2" or "Phi-3").

### Step 3: Download a Model
Tap the download icon on your chosen model. Select a **Quantization** (version) from the list. 
> [!TIP]
> For most mobile devices, **1B to 3B** parameter models with **Q4** quantization offer the best balance of speed and intelligence.

### Step 4: Select Your Model
Once the download completes, go to the **LOCAL** tab. Tap on your downloaded model to select it.

### Step 5: Start Chatting!
Go back to the chat screen. The app will load your model automatically. Type your message and enjoy a 100% private conversation.

---

## 🛠️ Requirements (Developers)

- **Flutter SDK** (Channel: Stable)
- **Dart SDK** (>= 3.0.0)
- **Android NDK** (24+) & **CMake** (3.22.1+)
- **Memory** — 4GB+ RAM recommended for smooth inference.

---

## 📦 Getting Started

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Amarj234/offline_hugging_face_model_run.git
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Native Setup**  
   The `flutter_llama` package requires the `llama.cpp` sources in the package cache:
   ```bash
   cd ~/.pub-cache/hosted/pub.dev/flutter_llama-1.1.2/
   git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

---

## 🏗️ Project Structure

```text
lib/
├── core/                # Professional Theme, Constants, and File Utilities
├── features/
│   ├── chat/            # Optimized Chat UI & Llama Service
│   ├── models/          # HF Model Browser & Download Management
│   └── settings/        # Premium Settings & Inference Preferences
└── main.dart            # App Entry Point
```

---

## 📝 License

This project is licensed under the MIT License.
