import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class SentenceProcessor extends ChangeNotifier {
  final FlutterTts flutterTts = FlutterTts();


  String latencyText = "";
  String correctedText = "";
  Timer? _debounce;

  final String apiKey = "";
  final String apiUrl = "https://api.groq.com/openai/v1/chat/completions";

  SentenceProcessor() {
    _initTts();
  }

  void _initTts() {
    flutterTts.setLanguage("en-IN");
    flutterTts.setSpeechRate(0.45);
    flutterTts.setPitch(1.0);
    flutterTts.setVolume(1.0);
  }

  /// Called when BLE finishes a word (Hindi TTS flow)
  Future<void> speakPredictedWord(String word) async {
    if (word.trim().isEmpty) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      await flutterTts.stop();

      final corrected = await correctText(word.trim());

      correctedText = corrected;
      notifyListeners();

      await flutterTts.speak(corrected);
    });
  }

  /// API call: English correction → Hindi translation
  Future<String> correctText(String inputText) async {
    try {
      final start = DateTime.now();

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": """
You correct English spelling & grammar, do NOT extend the word and do NOT convert it into a sentence.
""",
            },
            {"role": "user", "content": inputText}
          ],
          "temperature": 0.1
        }),
      );

      final end = DateTime.now();
      latencyText = "Latency: ${end.difference(start).inMilliseconds} ms";
      notifyListeners();

      if (response.statusCode != 200) {
        correctedText = "Error ${response.statusCode}";
        notifyListeners();
        return inputText;
      }

      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"].toString().trim();
    } catch (e) {
      correctedText = "Error: $e";
      notifyListeners();
      return inputText;
    }
  }

  /// ⭐ NEW: Update correctedText from the STT "Write" button

  void updateCorrectedText(String text) {
    correctedText = text;
    notifyListeners();
  }
  Future<void> processLetters(List<String> letters) async {
    // later: send to BLE, match zones, vibrate motors
    print("Processed Letters for Glove: $letters");
  }
}
