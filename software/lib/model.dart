import 'package:tflite_flutter/tflite_flutter.dart';

class SignLanguageModel {
  late Interpreter _interpreter;
  bool _isReady = false;

  SignLanguageModel._();

  static Future<SignLanguageModel> create() async {
    final model = SignLanguageModel._();
    await model._loadModel();`
    return model;
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/sign_language_model.tflite'); // ✅ no 'assets/'
      _isReady = true;
      print("✅ Model loaded!");
      print("Input shape: ${_interpreter.getInputTensor(0).shape}");
      print("Output shape: ${_interpreter.getOutputTensor(0).shape}");
    } catch (e) {
      print("❌ Failed to load model: $e");
      rethrow;
    }
  }

  bool get isReady => _isReady;

  String predictLetter(List<double> sensorValues) {
    const int expectedInputSize = 8; // your model input shape

    // 🧩 Ensure correct input length
    while (sensorValues.length < expectedInputSize) {
      sensorValues.add(0.0);
    }

    var input = [sensorValues];
    var output = List.generate(1, (_) => List.filled(27, 0.0));

    try {
      print("🧠 Input to model: $input");
      _interpreter.run(input, output);
      print("🧩 Model raw output: ${output[0]}");
    } catch (e) {
      print("❌ Model run failed: $e");
      return "-";
    }

    // 🧮 Find the index of the max probability
    int predictedIndex = output[0].indexWhere(
          (e) => e == output[0].reduce((a, b) => a > b ? a : b),
    );

    String predictedLetter = String.fromCharCode(65 + predictedIndex);
    print("🔤 Predicted letter: $predictedLetter (index: $predictedIndex)");

    return predictedLetter;
  }









  void close() {
    _interpreter.close();
  }
}
