// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble.dart';
import 'tts.dart';
import 'statuspage.dart';
import 'decomposition.dart';
import 'mapping.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZoneMapping().loadCsv();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleManager()),
        ChangeNotifierProvider(create: (_) => SentenceProcessor()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Glove App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final DecompositionService _decomposer = DecompositionService();

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ------------------ STT Functions ------------------
  void _listen() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('STT Status: $val'),
      onError: (val) => print('STT Error: $val'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _controller.text = val.recognizedWords;
          });
        },
        partialResults: true,
        localeId: 'en_US',
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      print("User denied STT permission");
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // ------------------ Build UI ------------------
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
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Finger Positions:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),

              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: bleManager.fingerNames.length,
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
              ElevatedButton(
                onPressed: () {
                  bleManager.predictFromRecentInputs();
                },
                child: const Text("Predict from Last BLE Input"),
              ),

              const SizedBox(height: 20),
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

              // ------------------ STT + Speaking Guidance ------------------
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          FloatingActionButton(
                            onPressed: _isListening ? _stopListening : _listen,
                            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                          ),
                          const SizedBox(width: 10),
                          const Text("Tap to Speak"),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Text Field for showing spoken text
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: "Spoken Text",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🔥 Write button — starts speaking guidance pipeline
                      ElevatedButton(
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            // 1️⃣ Update the displayed corrected text (UI)
                            sentenceProcessor.updateCorrectedText(_controller.text);

                            // 2️⃣ Decompose into letters for glove processing
                            List<String> letters = _decomposer.decomposeToLetters(_controller.text);

                            if (letters.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("No letters found to guide.")),
                              );
                              return;
                            }

                            // 3️⃣ Start speaking guidance in BLE manager
                            bleManager.startSpeakingGuidance(letters);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Guidance started for: ${letters.join()}")),
                            );
                          }
                        },
                        child: const Text("Write"),
                      ),

                      const SizedBox(height: 10),

                      // Stop guidance (optional control)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          bleManager.stopSpeakingGuidance();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Guidance stopped")),
                          );
                        },
                        child: const Text("Stop Guidance"),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Corrected Text",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        sentenceProcessor.correctedText,
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
