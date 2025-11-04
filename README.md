# AI Chat with Voice (Flutter)

This is a simple Flutter app demonstrating:
- Chat with an AI (Google gemini-2.5-flash by default)
- Voice input (speech_to_text)
- Text-to-speech for AI replies (flutter_tts)
- Local chat history saved to SharedPreferences

Requirements
------------
- Flutter SDK (3.x+ recommended)
- An Google gemini API key (or replace the API call with another AI provider)

Setup
-----
1. Clone / create a Flutter project and replace files with the code provided.
2. Add `.env` file in project root with:
   GEMINI_API_KEY=REPLACE_WITH_YOUR_KEY
3. Run `flutter pub get`.
4. On Android: ensure `android/app/src/main/AndroidManifest.xml` includes:
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.INTERNET" />
5. On iOS: add microphone usage description to Info.plist:
   NSMicrophoneUsageDescription
6. Run on a real device or emulator (for microphone use a real device).

Usage
-----
- Press the mic icon and speak — recognized speech populates the input.
- Press Send to send to AI.
- When the AI reply appears, press the small speaker icon to hear it.
- Clear history with the trash icon in the app bar.

Notes
-----
- This implementation uses Google gemini's Chat Completions API. If you want to use another AI provider, update `lib/services/api_service.dart`.
- Keep your API key safe (do not commit it).
