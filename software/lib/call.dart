// lib/call_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'ble.dart'; // Your existing BLE manager
import 'tts_helper.dart';

class CallScreen extends StatefulWidget {
  final String appId;
  final String token; // optional
  final String channelName;
  const CallScreen({
    super.key,
    required this.appId,
    required this.channelName,
    this.token = '',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool isMuteMode = false;
  bool isAutoSpeakEnabled = true;
  String lastSpoken = '';
  bool _isMixing = false;
  StreamSubscription? _bleListenerSub;

  @override
  void initState() {
    super.initState();
    initPermissions();
    initAgora();
    // BLE listener
    final ble = Provider.of<BleManager>(context, listen: false);
    ble.addListener(_onBleUpdate);
  }

  Future<void> initPermissions() async {
    await [Permission.microphone, Permission.bluetooth, Permission.storage].request();
  }

  Future<void> initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: widget.appId));
    await _engine.enableAudio();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _joined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.joinChannel(
      token: widget.token.isEmpty ? '' : widget.token, // use empty string instead of null
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

  }

  void _onBleUpdate() async {
    final ble = Provider.of<BleManager>(context, listen: false);
    final current = ble.predictedWord.trim();
    if (!isAutoSpeakEnabled || current.isEmpty || current == lastSpoken) return;

    lastSpoken = current;

    if (isMuteMode) {
      await _speakIntoCall(current);
    }
  }

  Future<void> _speakIntoCall(String text) async {
    if (!_joined || _isMixing) return;

    final filePath = await TtsFileHelper.synthToFile(text);
    if (filePath == null) return;

    _isMixing = true;
    try {
      await _engine.startAudioMixing(
        filePath: filePath,
        loopback: false,  // remote user hears it
        cycle: 1,
        startPos: 0,
      );

      // Wait roughly for audio duration
      await Future.delayed(Duration(milliseconds: 700 + text.length * 60));

      await _engine.stopAudioMixing();
    } catch (e) {
      print('Audio mixing error: $e');
    } finally {
      _isMixing = false;
    }
  }


  @override
  void dispose() {
    final ble = Provider.of<BleManager>(context, listen: false);
    ble.removeListener(_onBleUpdate);
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _showIncomingCallDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Incoming Call'),
        content: Text('Choose call mode for this call'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => isMuteMode = false);
              Navigator.pop(context);
            },
            child: Text('Normal Call'),
          ),
          TextButton(
            onPressed: () {
              setState(() => isMuteMode = true);
              Navigator.pop(context);
            },
            child: Text('Mute-People Call'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleManager>(context);
    return Scaffold(
      appBar: AppBar(title: Text('In-App Call')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _showIncomingCallDialog,
              child: Text('Simulate Incoming Call'),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text('Predicted Word'),
                subtitle: Text(ble.predictedWord.isEmpty ? '(waiting...)' : ble.predictedWord),
                trailing: Switch(
                  value: isAutoSpeakEnabled,
                  onChanged: (v) => setState(() => isAutoSpeakEnabled = v),
                ),
              ),
            ),
            Spacer(),
            ElevatedButton(
              child: Text(_joined ? 'Leave Call' : 'Join Call'),
              onPressed: () async {
                if (_joined) {
                  await _engine.leaveChannel();
                  setState(() => _joined = false);
                } else {
                  await initAgora();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
