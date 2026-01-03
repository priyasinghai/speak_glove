package com.example.speak_glove


import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourapp/tts"
    private var tts: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.getDefault()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "synthesizeToFile") {
                val text = call.argument<String>("text") ?: ""
                synthesizeToFile(text, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun synthesizeToFile(text: String, result: MethodChannel.Result) {
        try {
            val fileName = "tts_${System.currentTimeMillis()}.wav"
            val dir = this.filesDir
            val outFile = File(dir, fileName)

            val params = Bundle()
            val utteranceId = System.currentTimeMillis().toString()

            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    runOnUiThread { result.success(outFile.absolutePath) }
                }
                override fun onError(utteranceId: String?) {
                    runOnUiThread { result.error("TTS_ERROR", "Synthesis failed", null) }
                }
            })

            tts?.synthesizeToFile(text, params, outFile, utteranceId)
        } catch (e: Exception) {
            result.error("TTS_EXCEPTION", e.localizedMessage, null)
        }
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}