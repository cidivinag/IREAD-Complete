import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/models/question.dart';
import 'package:i_read_app/services/api.dart';
import 'package:i_read_app/services/speech_service.dart';
import 'package:i_read_app/services/storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../mainmenu/modules_menu.dart';

class WordProQuiz extends StatefulWidget {
  final String moduleTitle;
  final List<String> uniqueIds;
  final String difficulty;

  const WordProQuiz({
    super.key,
    required this.moduleTitle,
    required this.uniqueIds,
    required this.difficulty,
  });

  @override
  _WordProQuizState createState() => _WordProQuizState();
}

class _WordProQuizState extends State<WordProQuiz> {
  final FlutterTts flutterTts = FlutterTts();
  final ApiService apiService = ApiService();
  final StorageService storageService = StorageService();
  late final SpeechService _speechService;
  StreamSubscription<String>? _speechSubscription;
  Timer? _recordingTimer;

  List<Question> questions = [];
  int currentQuestionIndex = 0;
  String recognizedText = '';
  bool isListening = false;
  bool isSpeaking = false;
  bool canProceedToNext = false;
  bool showNextButton = false;
  String feedbackMessage = '';
  IconData feedbackIcon = Icons.help;
  int attemptCounter = 0;
  int mistakes = 0;
  double totalAccuracy = 0;
  double bestAccuracy = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSpeechService();
    _initTTS();
    _loadQuestions();
    _initRecorder();
  }

  Future<void> _initSpeechService() async {
    try {
      _speechService = await SpeechService.getInstance();
      _speechSubscription = _speechService.recognitionResult.listen((text) {
        if (text.isNotEmpty) {
          setState(() {
            recognizedText = text;
          });
          // Auto-submit if we have a good match
          if (_isGoodMatch(text, questions[currentQuestionIndex].text)) {
            stopListening();
          }
        }
      });
      _isInitialized = true;
    } catch (e) {
      log('Error initializing speech service: $e');
      setState(() {
        feedbackMessage = 'Error initializing speech service';
        feedbackIcon = Icons.error;
      });
    }
  }

  void _initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setPitch(1.0);
    await flutterTts.awaitSpeakCompletion(true);

    flutterTts.setStartHandler(() {
      debugPrint("🔊 Speech started");
    });

    flutterTts.setCompletionHandler(() {
      debugPrint("✅ Speech completed");
      setState(() {
        isSpeaking = false;
        canProceedToNext = true;
      });
    });

    flutterTts.setErrorHandler((msg) {
      debugPrint("❌ TTS Error: $msg");
    });
  }

  Future<void> _speakQuestion() async {
    if (questions.isNotEmpty) {
      setState(() {
        isSpeaking = true;
        recognizedText = '';
      });

      final currentText = questions[currentQuestionIndex].text;
      final toSpeak = currentText != null && currentText.isNotEmpty
          ? "Please repeat after me, $currentText"
          : "Loading question";

      await flutterTts.speak(toSpeak);
    }
  }

  Future<void> _loadQuestions() async {
    try {
      List<Module> modules = await apiService.getModules();
      Module module = modules
          .where((element) =>
              element.difficulty == widget.difficulty &&
              element.category == 'Word Pronunciation')
          .last;
      setState(() {
        questions = module.questionsPerModule;
      });
      await _speakQuestion();
    } catch (e) {
      debugPrint('Error loading questions: $e');
    }
  }

  void _initRecorder() {
    // No longer needed with the new speech service
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      setState(() {
        feedbackMessage = 'Speech service not ready yet';
        feedbackIcon = Icons.error;
      });
      return;
    }

    final status = await Permission.microphone.request();
    if (status.isGranted) {
      try {
        await _speechService.startListening();
        setState(() {
          recognizedText = 'Listening...';
          feedbackMessage = '';
          feedbackIcon = Icons.mic;
          showNextButton = false;
          isListening = true;
        });

        // Auto-stop after 10 seconds
        _recordingTimer = Timer(const Duration(seconds: 10), stopListening);
      } catch (e) {
        log('Error starting speech recognition: $e');
        setState(() {
          feedbackMessage = 'Error starting speech recognition';
          feedbackIcon = Icons.error;
        });
      }
    } else {
      setState(() {
        feedbackMessage = 'Microphone permission denied';
        feedbackIcon = Icons.mic_off;
      });
    }
  }

  // Speech recognition methods are now in the SpeechService class

  bool _isProcessing = false;  // Add this line at the top of the class with other state variables

  Future<void> stopListening() async {
    // Skip if already processing
    if (_isProcessing) return;
    
    _isProcessing = true;
    _recordingTimer?.cancel();
    
    try {
      setState(() {
        isListening = false;
        if (recognizedText.isEmpty) {
          recognizedText = 'Processing...';
        }
      });

      await _speechService.stopListening();

      if (recognizedText.isNotEmpty && recognizedText != 'Listening...') {
        final expectedText = questions[currentQuestionIndex].text;
        debugPrint('=== DEBUG ===');
        debugPrint('Recognized text: "$recognizedText" (length: ${recognizedText.length})');
        debugPrint('Expected text: "$expectedText" (length: ${expectedText.length})');
        
        final isCorrect = _isGoodMatch(recognizedText, expectedText);
        debugPrint('Match result: $isCorrect');
        debugPrint('=============');
        
        setState(() {
          if (isCorrect) {
            feedbackMessage = 'Correct! Well done!';
            feedbackIcon = Icons.check_circle;
            showNextButton = true;
            canProceedToNext = true;
            totalAccuracy += 100; // Full score for correct answer
          } else {
            feedbackMessage = 'Try again. You said: $recognizedText';
            feedbackIcon = Icons.cancel;
            showNextButton = false;
            canProceedToNext = false;
            mistakes++;
          }
        });

        // Speak feedback only once
        await flutterTts.stop(); // Stop any ongoing speech
        await flutterTts.speak(isCorrect ? 'Correct! Well done!' : 'Try again');
      } else {
        setState(() {
          feedbackMessage = 'No speech detected. Try again.';
          feedbackIcon = Icons.mic_off;
          showNextButton = false;
          canProceedToNext = false;
        });
      }
    } catch (e) {
      log('Error in stopListening: $e');
      setState(() {
        feedbackMessage = 'Error processing your speech';
        feedbackIcon = Icons.error;
        showNextButton = false;
        canProceedToNext = false;
      });
    } finally {
      _isProcessing = false;  // Reset processing flag when done
    }
  }

  bool _isGoodMatch(String recognized, String expected) {
    // Extract just the word part from the expected text (after the colon and space)
    final expectedWord = expected.split(':').last.trim();
    
    // Clean both strings for comparison
    final recognizedClean = recognized.toLowerCase().trim();
    final expectedClean = expectedWord.toLowerCase().trim();
    
    debugPrint('Comparing: "$recognizedClean" with "$expectedClean"');
    
    return recognizedClean == expectedClean;
  }

  Future<void> _showAssesmentResult(Map<String, dynamic> result) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Assessment Breakdown'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Recognized Text: ${result['recognized_text']}'),
              Text('Accuracy: ${result['accuracy_score']}%'),
              Text('Fluency: ${result['fluency_score']}%'),
              Text('Pronunciation: ${result['pronunciation_score']}%'),
              Text('Completeness: ${result['completeness_score']}%'),
              if (result['prosody_score'] != null)
                Text('Prosody: ${result['prosody_score']}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _nextQuestion();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _nextQuestion() async {
    if (currentQuestionIndex < questions.length - 1 && canProceedToNext) {
      setState(() {
        currentQuestionIndex++;
        recognizedText = '';
        feedbackMessage = '';
        feedbackIcon = Icons.help;
        showNextButton = false;
        canProceedToNext = false;
      });
      await _speakQuestion();
    } else {
      await _showCompletionScreen();
    }
  }

  Future<void> _showCompletionScreen() async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Quiz Complete!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) =>
                          ModulesMenu(onModulesUpdated: (modules) {})),
                  (route) => false,
                );
              },
              child: Text('Finish'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5E8C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Word Pronunciation',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B4513),
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF5E8C7),
        padding: const EdgeInsets.all(20.0),
        child: questions.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B4513)),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    questions[currentQuestionIndex].text,
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      color: const Color(0xFF8B4513),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF8B4513), width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF8B4513).withOpacity(0.1),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      recognizedText,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        color: const Color(0xFF8B4513),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: (isListening || isSpeaking)
                        ? stopListening
                        : startListening,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isListening
                            ? Colors.red
                            : (isSpeaking || showNextButton)
                                ? Colors.grey
                                : const Color(0xFF8B4513),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_off,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    feedbackMessage,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: feedbackIcon == Icons.check_circle
                          ? Colors.green
                          : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (showNextButton)
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    _speechSubscription?.cancel();
    _recordingTimer?.cancel();
    _speechService.dispose();
    super.dispose();
  }
}