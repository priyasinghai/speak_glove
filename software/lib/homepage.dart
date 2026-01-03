import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble.dart';
import 'tts.dart';
import 'statuspage.dart';

class HomePage extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bleManager = Provider.of<BleManager>(context);
    final sentenceProcessor = Provider.of<SentenceProcessor>(context);

    return Scaffold(
        appBar: AppBar(
          title: const Text("BLE Glove App"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatusPage()),
                );
              },
            ),

          ],
        ),

        body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // 🔹 Finger Zones Cards (Horizontal Scroll)
              const Text("Finger Positions:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      width: 150,
                      child: Card(
                        margin: const EdgeInsets.only(right: 8),
                        color: Colors.blue[50],
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(
                                bleManager.fingerNames[index],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bleManager.fingerZones.isNotEmpty
                                    ? bleManager.fingerZones[index]
                                    : "-",
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 10),

                              // 🔸 Zone 1 Input
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: "Zone 1",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(6),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  int z1 = int.tryParse(val) ?? bleManager.fingerThresholds[index][0];
                                  int z2 = bleManager.fingerThresholds[index][1];
                                  bleManager.setFingerThreshold(index, z1, z2);
                                },
                              ),
                              const SizedBox(height: 6),

                              // 🔸 Zone 2 Input
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: "Zone 2",
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(6),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) {
                                  int z1 = bleManager.fingerThresholds[index][0];
                                  int z2 = int.tryParse(val) ?? bleManager.fingerThresholds[index][1];
                                  bleManager.setFingerThreshold(index, z1, z2);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Predict Button
              ElevatedButton(
                onPressed: () {
                  bleManager.predictFromRecentInputs(); // ✅ Use your BleManager method
                },
                child: const Text("Predict from Last BLE Input"),
              ),

              const SizedBox(height: 20),

              // 🔹 Predicted Letter Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("Predicted Letter",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        bleManager.predictedLetter,
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 Predicted Word Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("Predicted Word",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        bleManager.predictedWord,
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),



            ],
          ),
        ),
      ),
    );
  }
}
