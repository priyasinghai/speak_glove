// ble.dart
// 🧤 BLE Manager for Smart Glove (nRF52840)
// Compatible with Arduino code sending: "v1,v2,v3,v4,v5"

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import 'mapping.dart';
import 'wordbuilder.dart';
import 'tts.dart';

// ---------- BLE Configuration ----------
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHARACTERISTIC_TX_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String CHARACTERISTIC_MOTOR_UUID = "12345678-1234-5678-1234-56789abcdef0";
const String GLOVE_NAME = "Smart Glove";
const String FILE_NAME = "sensor_values.txt";

enum GloveMode { talking, listening }

GloveMode _mode = GloveMode.talking;

class BleManager extends ChangeNotifier {
  // ---------- Variables ----------
  String _statusMessage = "Starting...";
  StreamSubscription? _scanSubscription;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _charSubscription;
  BluetoothDevice? _connectedDevice;

  // characteristic references
  BluetoothCharacteristic? _writeChar; // for sending motor commands if available

  String _predictedLetter = '-';
  String _bleBuffer = "";
  bool middleMotorVibrating = false;
  bool ringMotorVibrating = false;
  bool indexMotorVibrating = false;



  String get predictedLetter => _predictedLetter;
  String get predictedWord => _wordBuilder.currentWord;

  final SentenceProcessor ttsProcessor;
  final WordBuilder _wordBuilder;

  BleManager()
      : ttsProcessor = SentenceProcessor(),
        _wordBuilder = WordBuilder(SentenceProcessor()) {
    _initAll();
  }

  final List<String> _fingerNames = ["Thumb", "Index", "Middle", "Ring", "Pinky"];
  List<String> _fingerZones = ["", "", "", "", ""];
  List<int> _sensorValues = [];

  // thresholds = [ [t1,t2], [t1,t2], ... 5 fingers ]
  List<List<int>> _fingerThresholds = List.generate(5, (_) => [80, 160]);

  List<List<int>> get fingerThresholds => _fingerThresholds;
  List<int> get sensorValues => _sensorValues;
  List<String> get fingerNames => _fingerNames;
  List<String> get fingerZones => _fingerZones;
  String get statusMessage => _statusMessage;

  late File _sensorFile;

  // ---------------- Speaking guidance state ----------------
  bool _speakingActive = false;
  List<String> _speakingQueue = [];
  int _speakingIndex = 0;
  List<int>? _currentExpectedZones; // expected zones for current letter
  Timer? _advanceTimer;
  int actualMiddleZone = 0;      // live value of middle finger zone
  int expectedMiddleZone = 0;    // expected zone for current letter
  int actualRingZone = 0;      // live value of middle finger zone
  int expectedRingZone = 0;
  int actualIndexZone = 0;      // live value of middle finger zone
  int expectedIndexZone = 0;
  bool get isMiddleMotorVibrating => middleMotorVibrating;
  bool get isRingMotorVibrating => ringMotorVibrating;
  bool get isIndexMotorVibrating => indexMotorVibrating;


  // ---------- Constructor ----------

  // ---------- Setup and Initialization ----------
  Future<void> _initAll() async {
    _statusMessage = "Preparing...";
    notifyListeners();

    Directory dir = await getApplicationDocumentsDirectory();
    _sensorFile = File("${dir.path}/$FILE_NAME");
    if (!await _sensorFile.exists()) await _sensorFile.create();

    _statusMessage = "Ready (will scan).";
    notifyListeners();

    _checkPermissionsAndStartScan();

    // Periodic file reader as fallback (keeps UI updated if BLE writes file)
    Timer.periodic(const Duration(milliseconds: 500), (_) => _readSensorFile());
  }

  // ---------- Permissions ----------
  Future<void> _checkPermissionsAndStartScan() async {
    bool granted = await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.location.isGranted;

    if (!granted) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      granted = statuses.values.every((status) => status == PermissionStatus.granted);
    }

    if (granted) {
      _startScan();
    } else {
      _statusMessage = "Bluetooth permissions denied.";
      notifyListeners();
    }
  }

  // ---------- BLE Scanning ----------
  void _startScan() async {
    _statusMessage = "Scanning for glove...";
    notifyListeners();

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final deviceName = r.device.platformName;
        final advName = r.advertisementData.localName;

        if (deviceName == GLOVE_NAME || advName == GLOVE_NAME) {
          _connectToDevice(r.device);
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
  }

  // ---------- Connect to Device ----------
  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();

    _statusMessage = "Connecting to glove...";
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;
      _statusMessage = "Connected to ${device.platformName}";
      notifyListeners();

      _deviceStateSubscription = device.state.listen((state) {
        if (state == BluetoothDeviceState.disconnected) {
          _statusMessage = "Disconnected. Reconnecting...";
          _connectedDevice = null;
          notifyListeners();
          Future.delayed(const Duration(seconds: 5), _startScan);
        }
      });

      _discoverServices(device);
    } catch (e) {
      _statusMessage = "Connection failed: $e";
      notifyListeners();
      Future.delayed(const Duration(seconds: 5), _startScan);
    }
  }

  // ---------- Discover Services ----------
  void _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var characteristic in service.characteristics) {
            String charUUID = characteristic.uuid.toString().toLowerCase();
            if (characteristic.uuid.toString().toLowerCase() ==
                CHARACTERISTIC_TX_UUID.toLowerCase()) {
              await characteristic.setNotifyValue(true);
              _charSubscription = characteristic.value.listen(_processIncomingData);
            }
            if (charUUID == CHARACTERISTIC_MOTOR_UUID.toLowerCase()) {
              _writeChar = characteristic;
              print("✅ Motor characteristic found!");
            }

            // capture any writable characteristic to send motor commands
            if (characteristic.properties.write == true) {
              _writeChar = characteristic;
            }
          }
          break;
        }
      }
    } catch (e) {
      _statusMessage = "Service discovery failed: $e";
      notifyListeners();
    }
  }


  // ---------- Helper: send motor/command to Arduino ----------
  Future<void> _sendMotorCommand(String cmd) async {
    if (_connectedDevice == null) return;

    // Lazily discover write characteristic if missing
    if (_writeChar == null) {
      try {
        List<BluetoothService> services = await _connectedDevice!.discoverServices();
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.write == true) {
              _writeChar = characteristic;
              break;
            }
          }
          if (_writeChar != null) break;
        }
      } catch (e) {
        print("⚠️ Write characteristic discovery failed: $e");
      }
    }

    if (_writeChar == null) {
      print("⚠️ No write characteristic available to send command: $cmd");
      return;
    }

    try {
      // Encode the command
      List<int> bytes = utf8.encode(cmd);
      int chunkSize = 20; // BLE max payload

      // Send in chunks if necessary
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
        List<int> chunk = bytes.sublist(i, end);

        await _writeChar!.write(chunk, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 50)); // small delay for stability
        print("🔔 Motor CMD chunk → ${utf8.decode(chunk)}");
      }

      // --- Reset motor flags ---
      middleMotorVibrating = false;
      ringMotorVibrating = false;
      indexMotorVibrating = false;

      // --- Parse command to update motor state ---
      List<String> parts = cmd.split(';');
      for (var part in parts) {
        List<String> kv = part.split(':');
        if (kv.length != 2) continue;
        String key = kv[0].trim();
        String val = kv[1].trim();
        if (key == "MIDDLE") middleMotorVibrating = val == "V";
        if (key == "RING") ringMotorVibrating = val == "V";
        if (key == "INDEX") indexMotorVibrating = val == "V";
      }

      notifyListeners();
    } catch (e) {
      print("⚠️ Motor write failed: $e");
    }
  }


  // ---------- Process Incoming BLE Data ----------
  void _processIncomingData(List<int> value) async {
    if (value.isEmpty) return;

    // Append BLE chunk to buffer
    _bleBuffer += utf8.decode(value, allowMalformed: true);

    // Process full packets separated by newline
    while (_bleBuffer.contains("\n")) {
      String packet = _bleBuffer.split("\n").first.trim();
      _bleBuffer = _bleBuffer.substring(packet.length + 1);

      if (packet.isEmpty) continue;

      print("📩 [BLE PACKET] $packet");

      List<String> parts = packet.split(",").map((e) => e.trim()).toList();
      if (parts.length != 5) {
        print("⚠️ Invalid packet skipped");
        continue;
      }

      List<int> flexValues = parts.map((e) => int.tryParse(e) ?? 0).toList();

      _sensorValues = flexValues;
      notifyListeners(); // refresh UI for raw values

      await _sensorFile.writeAsString(packet + "\n", mode: FileMode.append);

      // Convert values → zones (same logic as before)
      List<int> zones = [];
      for (int i = 0; i < 5; i++) {
        int v = flexValues[i];
        int t1 = _fingerThresholds[i][0];
        int t2 = _fingerThresholds[i][1];

          // Other fingers keep original logic
          zones.add(v < t1 ? 1 : v < t2 ? 2 : 3);

      }

      // Keep existing talking prediction unchanged
      _predictFromZones(zones);

      // --- NEW: speaking guidance comparison (separate pipeline) ---
      if (_speakingActive) {
        _handleSpeakingZones(zones);
      }
    }
  }

  // ---------- Manual Trigger for Prediction ----------
  void predictFromRecentInputs() {
    if (_sensorValues.isEmpty) {
      print("⚠️ No recent sensor values to predict from.");
      return;
    }

    List<int> zoneValues = [];
    for (int i = 0; i < 5; i++) {
      int v = _sensorValues[i];
      int t1 = _fingerThresholds[i][0];
      int t2 = _fingerThresholds[i][1];

    zoneValues.add(v < t1 ? 1 : v < t2 ? 2 : 3);

    }

    print("🧠 Manual prediction from recent inputs: $zoneValues");
    _predictFromZones(zoneValues);
  }

  // ---------- Prediction Logic (middle+ring only, A/C/R) ----------
  void _predictFromZones(List<int> zoneValues) {
    try {
      // use middle(index=2) and ring(index=3)
      int middle = zoneValues[2];
      int ring = zoneValues[3];


      String predicted = '';

      if ( middle == 1 && ring == 1) {
        predicted = 'A';
      } else if ( middle == 3 && ring == 3) {
        predicted = 'C';
      } else if (middle == 3 && ring == 1) {
        predicted = 'R';
      }
      else if (middle == 1 && ring == 3) {
        _wordBuilder.finalizeWord();
      } else {
        predicted = '';
      }

      _predictedLetter = predicted;
    } catch (e) {
      print("⚠️ Prediction failed: $e");
      _predictedLetter = '-';
    }

    // Update UI display names
    _fingerZones = zoneValues.map((z) {
      if (z == 1) return "Straight";
      if (z == 2) return "Bent";
      return "Folded";
    }).toList();

    // Build word and notify UI
    _wordBuilder.addPrediction(_predictedLetter);
    notifyListeners();
  }

  // ---------- Speaking guidance functions ----------

  /// Start speaking guidance with a list of letters.
  /// Example: ["H","E","L","L","O"]
  void startSpeakingGuidance(List<String> letters) {
    if (letters.isEmpty) return;
    _speakingQueue = letters.map((e) => e.toUpperCase()).toList();
    _speakingIndex = 0;
    _speakingActive = true;
    _currentExpectedZones = null;
    _advanceTimer?.cancel();

    _loadExpectedForCurrentLetterAndAct();
    notifyListeners();
    print("▶ Speaking guidance started: $_speakingQueue");
  }

  /// Stop speaking guidance immediately
  void stopSpeakingGuidance() {
    _speakingActive = false;
    _speakingQueue = [];
    _speakingIndex = 0;
    _currentExpectedZones = null;
    _advanceTimer?.cancel();
    // ensure motor off
    _sendMotorCommand("S");
    notifyListeners();
    print("⏹ Speaking guidance stopped");
  }

  void _loadExpectedForCurrentLetterAndAct() {
    if (!_speakingActive) return;
    if (_speakingIndex < 0 || _speakingIndex >= _speakingQueue.length) {
      // finished queue
      stopSpeakingGuidance();
      return;
    }

    final letter = _speakingQueue[_speakingIndex];
    final expected = ZoneMapping().getZonesForLetter(letter);

    if (expected == null || expected.length < 3) {
      print("⚠️ No mapping for letter '$letter' — skipping");
      // advance immediately
      _advanceToNextLetter(delayMs: 200);
      return;
    }

    _currentExpectedZones = expected;
    print("🔎 Guided letter '${letter}' expected zones: $_currentExpectedZones");
    // actual motor decisions will happen when _handleSpeakingZones is called with live zones
  }

  /// Called on every incoming zone update when speakingActive
  void _handleSpeakingZones(List<int> liveZones) {
    if (!_speakingActive || _currentExpectedZones == null) return;
    if (liveZones.length < 5) return;

    // Compare only middle finger (index 2) with mapping (order: Thumb,Index,Middle,Ring,Pinky)
    int expectedMiddle = _currentExpectedZones![2];
    int expectedRing   = _currentExpectedZones![3];
    int expectedIndex   = _currentExpectedZones![1];
    int liveMiddle = liveZones[2];
    int liveRing   = liveZones[3];
    int liveIndex   = liveZones[1];

    expectedIndexZone = expectedIndex;
    actualIndexZone = liveIndex;
    expectedMiddleZone = expectedMiddle;
    actualMiddleZone = liveMiddle;
    expectedRingZone = expectedRing;
    actualRingZone = liveRing;
    // Determine motor command for middle finger
    String middleCmd = (liveMiddle == expectedMiddle) ? "S" : "V";
    // Determine motor command for ring finger
    String ringCmd   = (liveRing == expectedRing) ? "S" : "V";
    String indexCmd   = (liveIndex == expectedIndex) ? "S" : "V";

    // Combine command in Arduino-friendly format
    String combinedCmd = "I:$indexCmd;M:$middleCmd;R:$ringCmd";

    _sendMotorCommand(combinedCmd);

    // Advance to next letter if BOTH are correct
    if (liveIndex == expectedIndex && liveMiddle == expectedMiddle && liveRing == expectedRing) {
      _advanceToNextLetter(delayMs: 400);
    }
  }

  void _advanceToNextLetter({int delayMs = 400}) {
    // If there's already a scheduled advance, reset it
    _advanceTimer?.cancel();
    _advanceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_speakingActive) return;

      _speakingIndex++;
      if (_speakingIndex >= _speakingQueue.length) {
        // finished
        stopSpeakingGuidance();
      } else {
        _loadExpectedForCurrentLetterAndAct();
      }
    });
  }

  // ---------- Periodic File Reader ----------
  void _readSensorFile() async {
    try {
      if (!await _sensorFile.exists()) return;

      List<String> lines = await _sensorFile.readAsLines();
      if (lines.isEmpty) return;

      String lastLine = lines.last.trim();
      if (lastLine.isEmpty) return;

      List<String> flexParts = lastLine.split(',').map((e) => e.trim()).toList();
      if (flexParts.length < 5) return;

      List<int> flexValues = flexParts.map((e) => int.tryParse(e) ?? 0).toList();

      List<int> zoneValues = [];
      for (int i = 0; i < 5; i++) {
        int v = flexValues[i];
        int t1 = _fingerThresholds[i][0];
        int t2 = _fingerThresholds[i][1];
        zoneValues.add(v < t1 ? 1 : v < t2 ? 2 : 3);
      }

      _predictFromZones(zoneValues);
      if (_speakingActive) {
        _handleSpeakingZones(zoneValues);
      }
      _sensorValues = List<int>.from(flexValues);
    } catch (e) {
      print("⚠️ File read error: $e");
    }
  }

  // ---------- Threshold Setter ----------
  void setFingerThreshold(int fingerIndex, int zone1, int zone2) {
    if (fingerIndex < 0 || fingerIndex >= _fingerThresholds.length) return;
    _fingerThresholds[fingerIndex] = [zone1, zone2];
    notifyListeners();
  }

  // ---------- Cleanup ----------
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _charSubscription?.cancel();
    _connectedDevice?.disconnect();
    _advanceTimer?.cancel();
    super.dispose();
  }
}
