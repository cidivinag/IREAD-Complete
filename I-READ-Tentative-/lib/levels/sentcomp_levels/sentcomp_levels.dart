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
      List<Module> allModules = await apiService.getModules();
      
      // Filter modules for Sentence Composition category only
      final sentCompModules = allModules.where((m) => m.category == 'Sentence Composition').toList();
      
      // Initialize locks - all locked by default except Easy
      Map<String, bool> locks = {
        'Easy': false,  // Easy is always unlocked
        'Medium': true, // Locked by default
        'Hard': true,   // Locked by default
      };

      // Count total and completed modules for each difficulty level
      final levelCounts = {
        'Easy': {'total': 0, 'completed': 0},
        'Medium': {'total': 0, 'completed': 0},
        'Hard': {'total': 0, 'completed': 0},
      };

      // Calculate totals and completed counts
      for (var module in sentCompModules) {
        final level = module.difficulty;
        if (levelCounts.containsKey(level)) {
          levelCounts[level]!['total'] = (levelCounts[level]!['total'] ?? 0) + 1;
          
          // The backend sets progress to 1 when all questions are answered correctly
          // We consider a module completed if progress is 1 (100%)
          bool isCompleted = module.completed == 1;
                              
          if (isCompleted) {
            levelCounts[level]!['completed'] = (levelCounts[level]!['completed'] ?? 0) + 1;
          }
          
          print('Module: ${module.title}, Level: $level, Progress: ${module.completed}, Completed: $isCompleted');
        }
      }

      // 1. Handle Easy level (always unlocked)
      locks['Easy'] = false;
      
      // 2. Handle Medium level - unlock only if ALL Easy modules are completed
      if (levelCounts['Easy']!['total']! > 0) {
        // Check if all Easy modules are completed
        final allEasyCompleted = levelCounts['Easy']!['completed'] == levelCounts['Easy']!['total'];
        locks['Medium'] = !allEasyCompleted; // Lock if not all Easy are completed
      } else {
        // If no Easy modules exist, keep Medium locked
        locks['Medium'] = true;
      }

      // 3. Handle Hard level - unlock only if ALL Medium modules are completed AND Medium is already unlocked
      if (levelCounts['Medium']!['total']! > 0) {
        // Check if all Medium modules are completed
        final allMediumCompleted = levelCounts['Medium']!['completed'] == levelCounts['Medium']!['total'];
        // Lock if not all Medium are completed OR if Medium is still locked
        locks['Hard'] = !allMediumCompleted || locks['Medium']!;
      } else {
        // If no Medium modules exist, keep Hard locked
        locks['Hard'] = true;
      }

      print("Sentence Composition Level Locks: $locks");
      print("Level Counts: $levelCounts");

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
