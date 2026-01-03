import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class ZoneMapping {
  static final ZoneMapping _instance = ZoneMapping._internal();
  factory ZoneMapping() => _instance;
  ZoneMapping._internal();

  /// Map:  'A' → [0,1,2,0,1]
  Map<String, List<int>> letterToZones = {};

  /// Load CSV once at the start
  Future<void> loadCsv() async {
    final raw = await rootBundle.loadString('assets/zones.csv');
    final rows = const LineSplitter().convert(raw);

    for (String row in rows) {
      final cols = row.split(',');

      if (cols.length < 6) continue; // Letter + 5 zones

      String letter = cols[0].trim().toUpperCase();
      List<int> zones = [
        int.parse(cols[1]),
        int.parse(cols[2]),
        int.parse(cols[3]),
        int.parse(cols[4]),
        int.parse(cols[5]),
      ];

      letterToZones[letter] = zones;
    }

    print("✓ Zone Mapping Loaded: ${letterToZones.length} letters");
  }

  /// Get expected zone pattern for a letter
  List<int>? getZonesForLetter(String letter) {
    return letterToZones[letter.toUpperCase()];
  }
}
