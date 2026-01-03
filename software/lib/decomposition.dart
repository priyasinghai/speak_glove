// decomposition.dart

class DecompositionService {
  // Clean sentence → break into letters → return List<String>
  List<String> decomposeToLetters(String input) {
    if (input.isEmpty) return [];

    // 1️⃣ Convert to uppercase
    String cleaned = input.toUpperCase();

    // 2️⃣ Keep only A–Z letters
    cleaned = cleaned.replaceAll(RegExp(r'[^A-Z]'), '');

    // 3️⃣ Convert to list of characters
    List<String> letters = cleaned.split('');

    print("[Decomposition] Letters: $letters");
    return letters;
  }
}
