import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/services/storage.dart';
import 'package:i_read_app/models/module.dart';

import 'package:i_read_app/services/api.dart';

class ReadingComprehensionLevels extends StatefulWidget {
  const ReadingComprehensionLevels({super.key});

  @override
  _ReadingComprehensionLevelsState createState() =>
      _ReadingComprehensionLevelsState();
}

class _ReadingComprehensionLevelsState
    extends State<ReadingComprehensionLevels> {
  String userId = '';
  final String moduleName = 'Reading Comprehension';
  StorageService storageService = StorageService();
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
      
      // Filter modules for Reading Comprehension category only
      final readCompModules = allModules.where((m) => m.category == 'Reading Comprehension').toList();
      
      // Initialize locks - all locked by default except Easy
      Map<String, bool> locks = {
        'Easy': false,  // Easy is always unlocked
        'Medium': true, // Locked by default
        'Hard': true,   // Locked by default
      };

      // Count total published and completed published modules for each difficulty level
      final levelCounts = {
        'Easy': {'published': 0, 'completed': 0},
        'Medium': {'published': 0, 'completed': 0},
        'Hard': {'published': 0, 'completed': 0},
      };

      // Calculate published and completed counts
      for (var module in readCompModules) {
        final level = module.difficulty;
        if (levelCounts.containsKey(level)) {
          // Only count published modules
          if (module.isPublished) {
            levelCounts[level]!['published'] = (levelCounts[level]!['published'] ?? 0) + 1;
            
            // Check if this published module is completed
            bool isCompleted = module.completed == 1;
            if (isCompleted) {
              levelCounts[level]!['completed'] = (levelCounts[level]!['completed'] ?? 0) + 1;
            }
            
            print('Module: ${module.title}, Level: $level, Published: ${module.isPublished}, Completed: $isCompleted');
          }
        }
      }

      // 1. Handle Easy level (always unlocked)
      locks['Easy'] = false;
      
      // 2. Handle Medium level - unlock only if ALL published Easy modules are completed
      if (levelCounts['Easy']!['published']! > 0) {
        // Check if all published Easy modules are completed
        final allEasyCompleted = levelCounts['Easy']!['completed'] == levelCounts['Easy']!['published'];
        locks['Medium'] = !allEasyCompleted; // Lock if not all published Easy are completed
        print('Medium level lock status: ${locks['Medium']} (${levelCounts['Easy']!['completed']}/${levelCounts['Easy']!['published']} Easy completed)');
      } else {
        // If no published Easy modules exist, keep Medium locked
        locks['Medium'] = true;
        print('No published Easy modules found, keeping Medium locked');
      }

      // 3. Handle Hard level - unlock only if ALL published Medium modules are completed AND Medium is already unlocked
      if (levelCounts['Medium']!['published']! > 0) {
        // Check if all published Medium modules are completed
        final allMediumCompleted = levelCounts['Medium']!['completed'] == levelCounts['Medium']!['published'];
        // Lock if not all published Medium are completed OR if Medium is still locked
        locks['Hard'] = !allMediumCompleted || locks['Medium']!;
        print('Hard level lock status: ${locks['Hard']} (${levelCounts['Medium']!['completed']}/${levelCounts['Medium']!['published']} Medium completed)');
      } else {
        // If no published Medium modules exist, keep Hard locked
        locks['Hard'] = true;
        print('No published Medium modules found, keeping Hard locked');
      }

      print("Reading Comprehension Level Locks: $locks");
      print("Level Counts: $levelCounts");

      setState(() {
        levelLocks = locks;
        isLoading = false;
      });
    } catch (e) {
      print("Failed to load reading comp locks: $e");
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
            'Reading Comprehension Levels',
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
                    Navigator.pushNamed(context, '/read_comp_easy');
                    break;
                  case 'Medium':
                    Navigator.pushNamed(context, '/read_comp_medium');
                    break;
                  case 'Hard':
                    Navigator.pushNamed(context, '/read_comp_hard');
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

