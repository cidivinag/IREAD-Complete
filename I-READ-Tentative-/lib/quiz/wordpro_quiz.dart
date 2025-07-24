
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/answer.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/models/question.dart';
import 'package:i_read_app/services/api.dart';
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
  late stt.SpeechToText _speech;
  


  List<Question> questions = [];
  int currentQuestionIndex = 0;
  String recognizedText = '';
  bool isListening = false;
  bool isSpeaking = false;
  bool canProceedToNext = false;
  bool showNextButton = false;
  String feedbackMessage = '';
  IconData feedbackIcon = Icons.help;
  Timer? _silenceTimer;
  Timer? _nextButtonTimer;

  int _calculateAccuracy(String expected, String actual) {
  if (expected == actual) return 100;

  List<String> expectedWords = expected.split(' ');
  List<String> actualWords = actual.split(' ');

  int matched = 0;
  for (int i = 0; i < expectedWords.length; i++) {
    if (i < actualWords.length && expectedWords[i] == actualWords[i]) {
      matched++;
    }
  }

  return ((matched / expectedWords.length) * 100).round();
}



  @override
  void initState() {
    super.initState();
     _speech = stt.SpeechToText();
    _initTTS();
    _loadQuestions();
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
      final toSpeak = currentText.isNotEmpty
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

void startListening() async {
  final permissionStatus = await Permission.microphone.request();
  if (!permissionStatus.isGranted) {
    setState(() {
      recognizedText = 'Microphone permission denied.';
    });
    return;
  }

  bool available = await _speech.initialize(
    onStatus: (status) => debugPrint('🎙️ Speech status: $status'),
    onError: (error) => debugPrint('❌ STT error: ${error.errorMsg}'),
  );

  if (!available) {
    setState(() {
      recognizedText = 'Speech recognition not available.';
    });
    return;
  }

  setState(() {
    isListening = true;
    recognizedText = 'Listening...';
    feedbackMessage = '';
    feedbackIcon = Icons.help;
    showNextButton = false;
  });

  String expected = questions[currentQuestionIndex].text.trim().toLowerCase();

  _speech.listen(
    onResult: (result) {
      String spoken = result.recognizedWords.trim().toLowerCase();

      debugPrint('🗣️ Result: $spoken');

      setState(() {
        recognizedText = spoken;
      });

      if (spoken == expected) {
        debugPrint('✅ Matched early! Stopping STT...');
        _silenceTimer?.cancel(); // cancel timer here
        _speech.stop(); // stop only once
        _onSpeechRecognized(spoken);
      } else if (result.finalResult) {
        _onSpeechRecognized(spoken);
      }
    },
    localeId: 'en_US',
    listenMode: stt.ListenMode.confirmation,
    partialResults: true,
  );

  _silenceTimer?.cancel();
  _silenceTimer = Timer(Duration(seconds: 8), () {
    if (_speech.isListening) {
      debugPrint('⏱️ Timeout reached — stopping STT.');
      _speech.stop();
      setState(() {
        isListening = false;
        feedbackMessage = "Didn't catch that. Please try again.";
        feedbackIcon = Icons.cancel;
      });
    }
  });
}




void _onSpeechRecognized(String spoken) {
  _silenceTimer?.cancel();

  String expected = questions[currentQuestionIndex].text.trim().toLowerCase();
  spoken = spoken.trim().toLowerCase();

  int accuracy = _calculateAccuracy(expected, spoken);

  setState(() {
    isListening = false;
    recognizedText = spoken;
    feedbackMessage = 'Your pronunciation is $accuracy% accurate';
    feedbackIcon = accuracy >= 80 ? Icons.check_circle : Icons.cancel;
    showNextButton = accuracy >= 80;
  });
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
          onPressed: () => Navigator.pop(context),
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
      body: questions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B4513)),
            )
          : buildQuizUI(),
    );
  }

  Widget buildQuizUI() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF5E8C7),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              border: Border.all(color: const Color(0xFF8B4513), width: 2),
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
                ? null
                : () {
                    startListening();
                  },
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
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
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    _silenceTimer?.cancel();
    _nextButtonTimer?.cancel();

    super.dispose();
  }
}