import 'package:flutter_tts/flutter_tts.dart';
import 'tts.dart';

class WordBuilder {
  final List<String> _recentPredictions = [];
  String _currentWord = "";
  String _lastAppended = "";
  final SentenceProcessor ttsProcessor;

  WordBuilder(this.ttsProcessor);
  final FlutterTts _flutterTts = FlutterTts();

  // Getter for the current built word
  String get currentWord => _currentWord;

  // Add a predicted letter (from BLE/model)
  void addPrediction(String letter) async {
    // Step 1: keep sliding buffer of last 10 predictions
    _recentPredictions.add(letter);
    if (_recentPredictions.length > 10) {
      _recentPredictions.removeAt(0);
    }

    // Step 2: check stability only if buffer is full
    if (_recentPredictions.length == 10) {
      var counts = <String, int>{};
      for (var l in _recentPredictions) {
        counts[l] = (counts[l] ?? 0) + 1;
      }

      // Step 3: find most frequent letter
      String mostFrequent =
          counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      double frequency = counts[mostFrequent]! / 10.0;

      // Step 4: apply stability condition
      if (frequency >= 0.8 && mostFrequent != _lastAppended) {
        _currentWord += mostFrequent;
        _lastAppended = mostFrequent;
        print("[WordBuilder] Current Word: $_currentWord");

        // Speak the letter immediately in English
        await ttsProcessor.flutterTts.setLanguage("en-US");
        await ttsProcessor.flutterTts.speak(mostFrequent);
      }
    }
  }

  // Finalize word (called on shake or user action)
  Future<String> finalizeWord() async {
    if (_currentWord.isEmpty) return '';

    print("[WordBuilder] Final Word: $_currentWord");

    //  Speak the word in English
    await ttsProcessor.flutterTts.setLanguage("en-US");
    await ttsProcessor.flutterTts.speak(_currentWord);

    // Speak the word in Hindi using SentenceProcessor
    await ttsProcessor.speakPredictedWord(_currentWord);

    // Reset state
    _recentPredictions.clear();
    _lastAppended = "";
    _currentWord = "";
    return _currentWord;
  }

  // Reset manually (if needed)
  void reset() {
    _recentPredictions.clear();
    _lastAppended = "";
    _currentWord = "";
  }
}
