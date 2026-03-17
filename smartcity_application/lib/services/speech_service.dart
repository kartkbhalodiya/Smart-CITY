import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isInitialized = false;
  bool isListening = false;
  bool isRecording = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = await _speech.initialize();
      await _tts.setLanguage("en-IN");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    }
  }

  Future<void> startListening(Function(String) onResult) async {
    await initialize();
    if (_isInitialized && !isListening) {
      isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        localeId: 'en_IN',
      );
    }
  }

  Future<void> stopListening() async {
    if (isListening) {
      isListening = false;
      await _speech.stop();
    }
  }

  Future<Uint8List?> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        isRecording = true;
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        return null;
      }
    } catch (e) {
      print('Recording error: $e');
    }
    return null;
  }

  Future<Uint8List?> stopRecording() async {
    try {
      if (isRecording) {
        isRecording = false;
        final path = await _recorder.stop();
        if (path != null) {
          // Read audio file and return bytes
          // You'll need to implement file reading here
          return null; // Placeholder
        }
      }
    } catch (e) {
      print('Stop recording error: $e');
    }
    return null;
  }

  Future<void> speak(String text, {String? language}) async {
    await initialize();
    if (language != null) {
      await _tts.setLanguage(language);
    }
    await _tts.speak(text);
  }

  Future<void> speakHindi(String text) async {
    await _tts.setLanguage("hi-IN");
    await _tts.speak(text);
  }

  Future<void> speakGujarati(String text) async {
    await _tts.setLanguage("gu-IN");
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await stopListening();
    await _tts.stop();
    if (isRecording) {
      await _recorder.stop();
      isRecording = false;
    }
  }

  void dispose() {
    _speech.cancel();
    _tts.stop();
    _recorder.dispose();
  }
}
