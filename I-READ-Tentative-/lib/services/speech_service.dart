import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static SpeechService? _instance;
  final SpeechToText _speech = SpeechToText();
  final _resultController = StreamController<String>.broadcast();
  final _isListeningController = ValueNotifier<bool>(false);
  bool _isInitialized = false;
  String _lastRecognized = '';

  // Getters
  Stream<String> get recognitionResult => _resultController.stream;
  ValueNotifier<bool> get isListening => _isListeningController;

  // Singleton pattern
  static Future<SpeechService> getInstance() async {
    _instance ??= await _init();
    return _instance!;
  }

  // Initialize speech service
  static Future<SpeechService> _init() async {
    final service = SpeechService._internal();
    await service._initialize();
    return service;
  }

  SpeechService._internal();

  Future<void> _initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          log('Speech recognition status: $status');
          if (status == 'done') {
            _isListeningController.value = false;
          }
        },
        onError: (error) {
          log('Speech recognition error: $error');
          _resultController.addError(error.errorMsg);
          _isListeningController.value = false;
        },
      );

      if (!_isInitialized) {
        throw Exception('Speech recognition not available');
      }
    } catch (e) {
      log('Error initializing speech service: $e');
      rethrow;
    }
  }

  // Start speech recognition
  Future<void> startListening() async {
    if (!_isInitialized) {
      throw Exception('Speech recognition not initialized');
    }

    try {
      _lastRecognized = '';
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _lastRecognized = result.recognizedWords;
            _resultController.add(_lastRecognized);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
      );
      _isListeningController.value = true;
    } catch (e) {
      log('Error starting speech recognition: $e');
      _isListeningController.value = false;
      rethrow;
    }
  }

  // Stop speech recognition
  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListeningController.value = false;

      if (_lastRecognized.isNotEmpty) {
        _resultController.add(_lastRecognized);
      }
    } catch (e) {
      log('Error stopping speech recognition: $e');
      rethrow;
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    await stopListening();
    await _resultController.close();
    _isListeningController.dispose();
    _instance = null;
  }

  // Check if speech is currently being recognized
  bool get isListeningNow => _isListeningController.value;
}
