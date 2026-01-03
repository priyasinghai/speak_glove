import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hand Guidance Status"),
        centerTitle: true,
      ),
      body: SingleChildScrollView( // <-- Added scroll
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔹 BLE Connection Status
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Connection Status",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ble.statusMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Raw sensor values
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Raw Sensor Values",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ble.sensorValues.isNotEmpty
                          ? ble.sensorValues.join(", ")
                          : "No values yet",
                      style: const TextStyle(fontFamily: "monospace"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Finger Guidance Cards
            _buildFingerCard("Middle Finger Guidance", ble.actualMiddleZone, ble.expectedMiddleZone),
            const SizedBox(height: 12),
            _buildFingerCard("Ring Finger Guidance", ble.actualRingZone ?? 0, ble.expectedRingZone ?? 0),
            const SizedBox(height: 12),
            _buildFingerCard("Index Finger Guidance", ble.actualIndexZone ?? 0, ble.expectedIndexZone ?? 0),

            const SizedBox(height: 20),

            // 🔹 Motor Status
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Motor Status",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildMotorStatus("Middle Motor", ble.middleMotorVibrating),
                    const SizedBox(height: 8),
                    _buildMotorStatus("Ring Motor", ble.ringMotorVibrating),
                    const SizedBox(height: 8),
                    _buildMotorStatus("Index Motor", ble.indexMotorVibrating),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFingerCard(String title, int actual, int expected) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Actual Zone: $actual", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text("Expected Zone: $expected", style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildMotorStatus(String name, bool isVibrating) {
    return Text(
      "$name: ${isVibrating ? "Vibrating" : "Stopped"}",
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isVibrating ? Colors.red : Colors.green,
      ),
    );
  }
}
