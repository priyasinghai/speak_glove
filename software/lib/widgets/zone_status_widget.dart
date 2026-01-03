// widgets/zone_status_widget.dart
import 'package:flutter/material.dart';

class ZoneStatusWidget extends StatelessWidget {
  final List<int> expected;
  final List<int> actual;

  const ZoneStatusWidget({
    super.key,
    required this.expected,
    required this.actual,
  });

  @override
  Widget build(BuildContext context) {
    final fingers = ["Thumb", "Index", "Middle", "Ring", "Pinky"];

    return Column(
      children: [
        const Text(
          "Motor Guidance Status",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...List.generate(5, (i) {
          bool match = expected[i] == actual[i];
          return Card(
            child: ListTile(
              leading: Icon(match ? Icons.check_circle : Icons.vibration,
                  color: match ? Colors.green : Colors.red),
              title: Text(
                fingers[i],
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text("Expected Zone: ${expected[i]}, Live: ${actual[i]}"),
            ),
          );
        })
      ],
    );
  }
}
