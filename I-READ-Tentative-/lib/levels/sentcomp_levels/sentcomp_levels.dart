import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/services/api.dart';
import 'package:i_read_app/models/module.dart'; // ✅ Needed for Module class

class SentenceCompositionLevels extends StatefulWidget {
  const SentenceCompositionLevels({super.key});

  @override
  _SentenceCompositionLevelsState createState() =>
      _SentenceCompositionLevelsState();
}

class _SentenceCompositionLevelsState extends State<SentenceCompositionLevels> {
  ApiService apiService = ApiService();

  Map<String, bool> levelLocks = {
    'Easy': false,
    'Medium': true,
    'Hard': true,
  };
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModuleLocks();
  }

  Future<void> _loadModuleLocks() async {
    try {
      List<Module> modules = await apiService.getModules();
      Map<String, bool> locks = {
        'Easy': false,
        'Medium': true,
        'Hard': true,
      };

      for (var module in modules) {
        if (module.category == 'Sentence Composition') {
          locks[module.difficulty] = module.isLocked;
        }
      }

      print("LOCKS FOR SENTENCE COMPOSITION: $locks");

      setState(() {
        levelLocks = locks;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load sentence composition locks: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/modules_menu');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5E8C7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
            onPressed: () {
              Navigator.pushNamed(context, '/modules_menu');
            },
          ),
          title: Text(
            'Sentence Composition Levels',
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLevelButton(context, 'Easy'),
              const SizedBox(height: 20),
              _buildLevelButton(context, 'Medium'),
              const SizedBox(height: 20),
              _buildLevelButton(context, 'Hard'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelButton(BuildContext context, String level) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        onPressed: levelLocks[level] == true
            ? () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Module Locked"),
                    content: const Text("Complete easier modules in this category first."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      )
                    ],
                  ),
                );
              }
            : () {
                switch (level) {
                  case 'Easy':
                    Navigator.pushNamed(context, '/sentcomp_easy');
                    break;
                  case 'Medium':
                    Navigator.pushNamed(context, '/sentcomp_medium');
                    break;
                  case 'Hard':
                    Navigator.pushNamed(context, '/sentcomp_hard');
                    break;
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: levelLocks[level] == true
              ? Colors.grey
              : const Color(0xFF8B4513),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
          minimumSize: const Size(400, 60),
        ),
        child: Text(
          level,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
