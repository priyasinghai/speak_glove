import 'package:flutter/material.dart';

class ZoneDebugWidget extends StatelessWidget {
  final List<int> expected;
  final List<int> live;
  final String letter;

  const ZoneDebugWidget({
    super.key,
    required this.expected,
    required this.live,
    required this.letter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Orientation Debug (Letter: $letter)",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Table UI
            Table(
              border: TableBorder.all(color: Colors.black26),
              children: [
                _headerRow(),
                _dataRow("Thumb", 0),
                _dataRow("Index", 1),
                _dataRow("Middle", 2),
                _dataRow("Ring", 3),
                _dataRow("Pinky", 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _headerRow() {
    return const TableRow(children: [
      Padding(
        padding: EdgeInsets.all(8),
        child: Text("Finger", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child: Text("Expected Zone",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child:
        Text("Live Zone", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  TableRow _dataRow(String fingerName, int index) {
    bool match = expected[index] == live[index];

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(fingerName),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text("${expected[index]}"),
        ),
        Container(
          color: match ? Colors.green.shade300 : Colors.red.shade300,
          padding: const EdgeInsets.all(8),
          child: Text("${live[index]}"),
        ),
      ],
    );
  }
}
