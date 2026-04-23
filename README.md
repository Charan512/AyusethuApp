# AyuSethu Farmer App (Mobile UI)

> **Voice-First AI Agricultural Supply Chain Assistant**

The AyuSethu Farmer mobile app empowers rural farmers by providing a native, highly accessible entry point into the AyuSethu supply chain ecosystem. Built with **Flutter**, it completely removes traditional digital literacy barriers by using native language voice-interfaces for all critical actions.

## 🚀 Key Features

- **Multilingual Voice AI Onboarding:** Powered by Google's Gemini LLM and Bhashini (for hyper-localized Indian language ASR & TTS), the app acts as conversational agent to profile the farmer, record their land size, and capture their crop details without them ever needing to type a strict form.
- **Supply Chain Batch Tracking:** Farmers can view the live progress of their harvest via their "My Crops" dashboard. The system tracks a full 240-day, 5-stage phenotypic timeline per crop.
- **Hardware-Backed Data Integrity:** To complete a growth stage, the app forces real-time hardware data capture:
  - **Camera (`image_picker`):** Captures high-res photos of the harvest.
  - **GPS Geotagging (`geolocator`):** Imprints exact lat/lng coordinates to prove origin.
- **Decentralized Storage:** Growth stage photos are intrinsically pinned to the **IPFS Filecoin Network** (via Pinata) to ensure immutable trust before being evaluated by the backend ML pipeline.

## 🛠 Tech Stack
- **Framework:** Flutter / Dart
- **AI Pipelines:** Google Gemini AI, Bhashini (ASR/TTS)
- **Data Capture:** `geolocator`, `image_picker`, `audioplayers`, `record`
- **Network / State:** `http`, `shared_preferences`

## 📦 Setup & Usage

1. **Pre-requisites:** Flutter SDK, Android Studio or Xcode.
2. **Clone & Install:**
   ```bash
   flutter pub get
   ```
3. **Environment Config:**
   Create a `.env` in the root (though sensitive keys belong in the backend, the mobile app strictly points to the backend API).
   Make sure `/lib/config/api_constants.dart` points to your backend URL (e.g. `https://ayusethuapi.onrender.com`).
4. **Run:**
   ```bash
   flutter run
   ```

## 🔐 Security Notes
APK signing keystores and `google-services.json` files are strictly excluded from source control. To compile a release APK for Android (`flutter build apk --release`), ensure you attach your own valid `key.jks` and insert your release password within `android/key.properties`.
