
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
      setState(() {
        recognizedText = result.recognizedWords;
        
        // Cancel and restart the silence timer on new speech
        _silenceTimer?.cancel();
        _silenceTimer = Timer(Duration(seconds: 2), _onSilenceDetected);

        // If this is a final result, process it
        if (result.finalResult) {
          _processFinalResult(result.recognizedWords);
        }
      });
    }

    void _onSilenceDetected() {
      if (!isListening) return;
      
      _speech.stop();
      setState(() {
        isListening = false;
        if (recognizedText.isNotEmpty && recognizedText != 'Listening...') {
          _processFinalResult(recognizedText);
        } else {
          feedbackMessage = 'No speech detected. Try again.';
          feedbackIcon = Icons.error;
        }
      });
    }

    void _onSpeechComplete() {
      if (!mounted) return;
      setState(() {
        isListening = false;
        if (recognizedText.isNotEmpty && recognizedText != 'Listening...') {
          _processFinalResult(recognizedText);
        }
      });
    }

    void _processFinalResult(String recognizedText) {
      if (recognizedText.isEmpty || recognizedText == 'Listening...') {
        setState(() {
          feedbackMessage = 'Could not recognize speech. Try again.';
          feedbackIcon = Icons.error;
          showNextButton = false;
        });
        return;
      }

      final currentQuestion = questions[currentQuestionIndex];
      final expectedText = currentQuestion.text.toLowerCase();
      final accuracy = _calculateAccuracy(expectedText, recognizedText.toLowerCase());
      
      final isCorrect = accuracy >= 80; // 80% threshold for correctness
      
      setState(() {
        if (isCorrect) {
          feedbackMessage = 'Correct! 🎉';
          feedbackIcon = Icons.check_circle;
          showNextButton = true;
          
          // Auto-proceed to next question after a short delay
          _nextButtonTimer?.cancel();
          _nextButtonTimer = Timer(Duration(seconds: 2), () {
            if (mounted) {
              _nextQuestion();
            }
          });
        } else {
          feedbackMessage = 'Try again. Listen carefully to the word.';
          feedbackIcon = Icons.error;
          showNextButton = true;
        }
      });
      
      // Save the answer
      answers.add(Answer(
        questionId: currentQuestion.id,
        answer: recognizedText,
        correct: isCorrect,
      ));
      
      // Log the answer for debugging
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
      Module module = modules
        .where((element) =>
          element.difficulty == widget.difficulty &&
          element.category == 'Word Pronunciation')
        .last;

      setState(() {
        questions = module.questionsPerModule;
        moduleId = module.id;
      });

      await _speakQuestion();
    } catch (e) {
      debugPrint('❌ Error loading questions: $e');
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
        onStatus: (status) {
          debugPrint('🎙️ Speech status: $status');
          if (status == 'done') {
            _onSpeechComplete();
          }
        },
        onError: (error) {
          debugPrint('❌ STT error: ${error.errorMsg}');
          setState(() {
            isListening = false;
            feedbackMessage = 'Error: ${error.errorMsg}';
            feedbackIcon = Icons.error;
          });
        },
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
        feedbackMessage = 'Speak now!';
        feedbackIcon = Icons.mic;
        showNextButton = false;
        canProceedToNext = false;
      });

      // Start listening with partial results
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(seconds: 10),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
      );

      // Start a timer to handle silence
      _silenceTimer?.cancel();
      _silenceTimer = Timer(Duration(seconds: 5), _onSilenceDetected);
    }

      // Removed duplicate _showCompletionScreen method

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
      final response = await apiService.postSubmitModuleAnswer(moduleId, answers);

      final int totalScore = response['score'] ?? 0;
      final int totalXP = response['points_gained'] ?? 0;
      final int totalQuestions = response['total_questions'] ?? questions.length;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('${widget.moduleTitle} ${widget.difficulty} Quiz Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score: $totalScore / $totalQuestions'),
                Text('Mistakes: ${(totalQuestions - totalScore).clamp(0, totalQuestions)}'),
                Text('XP Earned: $totalXP'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => ModulesMenu(onModulesUpdated: (modules) {})),
                    (route) => false,
                  );
                },
                child: Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to submit answers: $e');
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
        flutterTts.stop();
        _speech.cancel();
        _silenceTimer?.cancel();
        _nextButtonTimer?.cancel();
        super.dispose();
      }
    }