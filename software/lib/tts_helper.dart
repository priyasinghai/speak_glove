// lib/tts_file_helper.dart
import 'package:flutter/services.dart';

class TtsFileHelper {
  static const MethodChannel _channel = MethodChannel('com.speak_glove/tts');

  /// Returns absolute file path of synthesized audio or null on error.
  static Future<String?> synthToFile(String text) async {
    try {
      final String? path = await _channel.invokeMethod('synthesizeToFile', {'text': text});
      return path;
    } on PlatformException catch (e) {
      print('TTS synth error: $e');
      return null;
    }
  }
}
