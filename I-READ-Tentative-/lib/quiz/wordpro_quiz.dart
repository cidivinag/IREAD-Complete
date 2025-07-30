
    import 'dart:async';
    import 'package:flutter/material.dart';
    import 'package:speech_to_text/speech_to_text.dart' as stt;
    import 'package:flutter_tts/flutter_tts.dart';
    import 'package:google_fonts/google_fonts.dart';
    import 'package:i_read_app/models/answer.dart';
    import 'package:i_read_app/models/module.dart';
    import 'package:i_read_app/models/question.dart';
    import 'package:i_read_app/services/api.dart';
    import 'package:permission_handler/permission_handler.dart';
    import 'package:i_read_app/services/storage.dart';

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
  State<WordProQuiz> createState() => _WordProQuizState();
}

class _WordProQuizState extends State<WordProQuiz> {
  final FlutterTts flutterTts = FlutterTts();
  final ApiService apiService = ApiService();
  final StorageService storageService = StorageService();
  late stt.SpeechToText _speech;
  
  late String moduleId;
  List<Answer> answers = [];
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
    if (expected.isEmpty || actual.isEmpty) return 0;
    if (expected == actual) return 100;

    expected = expected.toLowerCase().trim();
    actual = actual.toLowerCase().trim();
    
    List<String> expectedWords = expected.split(' ');
    List<String> actualWords = actual.split(' ');

    int matched = 0;
    for (int i = 0; i < expectedWords.length && i < actualWords.length; i++) {
      if (expectedWords[i] == actualWords[i]) {
        matched++;
      }
    }

    return ((matched / expectedWords.length) * 100).round();
  }

  void _onSpeechResult(dynamic result) {
    if (!mounted) return;
    
    setState(() {
      recognizedText = result.recognizedWords;
      
      // Cancel and restart the silence timer on new speech
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(seconds: 2), _onSilenceDetected);

      // If this is a final result, process it
      if (result.finalResult) {
        _processFinalResult(result.recognizedWords);
      }
    });
  }

  void _onSilenceDetected() {
    if (!isListening) return;
    
    _speech.stop().then((_) {
      if (!mounted) return;
      
      setState(() {
        isListening = false;
        if (recognizedText.isNotEmpty && recognizedText != 'Listening...') {
          _processFinalResult(recognizedText);
        } else {
          feedbackMessage = 'No speech detected. Try again.';
          feedbackIcon = Icons.error;
          showNextButton = true;
        }
      });
    }).catchError((error) {
      if (!mounted) return;
      
      setState(() {
        isListening = false;
        feedbackMessage = 'Error stopping speech recognition';
        feedbackIcon = Icons.error;
        showNextButton = true;
      });
    });
  }

  void _onSpeechComplete() {
    if (!mounted) return;
    
    setState(() {
      isListening = false;
      if (recognizedText.isNotEmpty && recognizedText != 'Listening...') {
        _processFinalResult(recognizedText);
      } else {
        feedbackMessage = 'Speech completed without any recognized text';
        feedbackIcon = Icons.error;
        showNextButton = true;
      }
    });
  }

  void _processFinalResult(String recognizedText) {
    if (!mounted) return;
    
    if (recognizedText.isEmpty || recognizedText == 'Listening...') {
      setState(() {
        feedbackMessage = 'Could not recognize speech. Try again.';
        feedbackIcon = Icons.error;
        showNextButton = true;
      });
      return;
    }

    final currentQuestion = questions[currentQuestionIndex];
    final accuracy = _calculateAccuracy(currentQuestion.text, recognizedText);
    final isCorrect = accuracy >= 80; // 80% accuracy threshold

    setState(() {
      this.recognizedText = recognizedText;
      isListening = false;
      canProceedToNext = isCorrect;
      showNextButton = true;

      if (isCorrect) {
        feedbackMessage = 'Correct! 🎉';
        feedbackIcon = Icons.check_circle;

        // Auto-proceed to next question after a short delay
        _nextButtonTimer?.cancel();
        _nextButtonTimer = Timer(const Duration(seconds: 1), _nextQuestion);
      } else {
        feedbackMessage = 'Almost! Try again.';
        feedbackIcon = Icons.error;
      }

      // Save the answer
      answers.add(Answer(
        questionId: currentQuestion.id,
        answer: recognizedText,
        correct: isCorrect,
      ));
    });
    debugPrint('Saved answer: ${currentQuestion.text} -> $recognizedText (Correct: $isCorrect, Accuracy: $accuracy%)');
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
    if (questions.isEmpty) return;
    
    setState(() {
      isSpeaking = true;
      recognizedText = '';
      feedbackMessage = 'Listen carefully...';
      feedbackIcon = Icons.hearing;
      showNextButton = false;
    });

    final currentText = questions[currentQuestionIndex].text;
    final toSpeak = currentText.isNotEmpty
        ? "Please repeat after me, $currentText"
        : "Loading question";

    await flutterTts.speak(toSpeak);
    
    if (mounted) {
      setState(() {
        isSpeaking = false;
      });
    }
  }

  Future<void> _loadQuestions() async {
    try {
      List<Module> modules = await apiService.getModules();
      debugPrint('🔍 Found ${modules.length} total modules');
      
      // Find all matching modules for better debugging
      final matchingModules = modules.where((element) {
        final matches = element.difficulty == widget.difficulty &&
                      element.category == 'Word Pronunciation';
        if (matches) {
          debugPrint('✅ Found matching module: ${element.id} - ${element.title} (${element.difficulty})');
        }
        return matches;
      }).toList();
      
      if (matchingModules.isEmpty) {
        throw Exception('No matching module found for difficulty: ${widget.difficulty}');
      }
      
      // Use first matching module instead of last to be consistent
      final module = matchingModules.first;
      debugPrint('📌 Selected module: ${module.id} - ${module.title}');

      setState(() {
        questions = module.questionsPerModule;
        moduleId = module.id; // Ensure we're using the correct module ID
        debugPrint('📝 Loaded ${questions.length} questions for module: $moduleId');
      });

      await _speakQuestion();
    } catch (e) {
      debugPrint('❌ Error loading questions: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  Future<void> startListening() async {
    final permissionStatus = await Permission.microphone.request();
    if (!permissionStatus.isGranted) {
      setState(() {
        recognizedText = 'Microphone permission denied.';
        feedbackMessage = 'Please enable microphone access in settings';
        feedbackIcon = Icons.mic_off;
        showNextButton = true;
      });
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎙️ Speech status: $status');
          if (status == 'done') {
            _onSpeechComplete();
          }
        },
      );

      if (!mounted) return;

      if (available) {
        setState(() {
          isListening = true;
          recognizedText = 'Listening...';
          feedbackMessage = 'Speak now';
          feedbackIcon = Icons.mic;
          showNextButton = false;
        });

        await _speech.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 5),
          cancelOnError: true,
          partialResults: true,
        );

        // Start the silence detection timer
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 5), _onSilenceDetected);
      } else {
        setState(() {
          recognizedText = 'Speech recognition not available';
          feedbackMessage = 'Speech recognition not available on this device';
          feedbackIcon = Icons.error;
          showNextButton = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        recognizedText = 'Error initializing speech recognition';
        feedbackMessage = 'Error: $e';
        feedbackIcon = Icons.error;
        showNextButton = true;
      });
    }
  }

  Future<void> _nextQuestion() async {
    if (!mounted) return;
    
    if (currentQuestionIndex < questions.length - 1) {
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
    try {
      debugPrint('📤 Submitting answers for module: $moduleId');
      debugPrint('📝 Answers to submit: ${answers.map((a) => '${a.questionId}: ${a.answer} (${a.correct ? 'correct' : 'incorrect'})').join('\n')}');
      
      final response = await apiService.postSubmitModuleAnswer(moduleId, answers);
      debugPrint('✅ Submission response: $response');

      final int totalScore = response['score'] ?? 0;
      final int totalXP = response['points_gained'] ?? 0;
      final int totalQuestions = response['total_questions'] ?? questions.length;

      if (!mounted) return;
      
      // Refresh modules to ensure progress is updated
      try {
        final modules = await apiService.getModules();
        await storageService.storeModules(modules);
        debugPrint('🔄 Refreshed modules data');
      } catch (e) {
        debugPrint('⚠️ Failed to refresh modules: $e');
      }

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (dialogContext) {
          return WillPopScope(
            onWillPop: () async => false, // Prevent back button
            child: AlertDialog(
              title: Text(
                '${widget.moduleTitle} ${widget.difficulty} Quiz Complete',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF8B4513), // Brown
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score: $totalScore / $totalQuestions',
                      style: GoogleFonts.montserrat(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mistakes: ${(totalQuestions - totalScore).clamp(0, totalQuestions)}',
                      style: GoogleFonts.montserrat(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'XP Earned: $totalXP',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => ModulesMenu(
                          onModulesUpdated: (modules) {},
                          key: UniqueKey(), // Force rebuild
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513), // Brown
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to submit answers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit answers: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Still navigate back even if submission fails
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ModulesMenu(onModulesUpdated: (modules) {}),
          ),
          (route) => false,
        );
      }
    }
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
    _silenceTimer?.cancel();
    _nextButtonTimer?.cancel();
    flutterTts.stop();
    _speech.stop().catchError((_) {
      // Ignore errors when stopping speech recognition
    });
    super.dispose();
  }
}