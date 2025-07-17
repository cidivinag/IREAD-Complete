import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/models/user.dart';
import 'package:i_read_app/services/api.dart';
// import 'package:i_read_app/services/firestore_module_service.dart';
import 'package:i_read_app/services/storage.dart';
import '../help.dart';
import '../levels/readcomp_levels/readcomp_levels.dart';
import '../levels/sentcomp_levels/sentcomp_levels.dart';
import '../levels/vocabskills_levels/vocabskills_levels.dart';
import '../levels/wordpro_levels/wordpro_levels.dart';

class HomeMenu extends StatefulWidget {
  final List<String> uniqueIds;

  const HomeMenu({super.key, required this.uniqueIds});

  @override
  // ignore: library_private_types_in_public_api
  _HomeMenuState createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu>
    with SingleTickerProviderStateMixin {
  List<CompletedModule>? completedModules = [];
  List<Module> allModules = [];
  ApiService apiService = ApiService();
 // final FirestoreModuleService firestoreModuleService = FirestoreModuleService();
  StorageService storageService = StorageService();
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadModules();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<UserProfile?> _fetchUserStats() {
    return apiService.getProfile();
  }
  // TODO: Migrate user profile fetching to Firestore
  // Future<UserProfile?> _fetchUserStats() async => null;

  Module _defaultModule() {
    return Module(
      id: '',
      title: '',
      description: '',
      difficulty: '',
      category: '',
      slug: '',
      createdBy: '',
      createdAt: DateTime.now(),
      questionsPerModule: [],
      materials: [],
      isLocked: false,
      completed: 0,
      fileUrl: '',
    );
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('[DEBUG] Fetching modules from API');
      List<Module> storedModules = await apiService.getModules();
      print('[DEBUG] Received ${storedModules.length} modules');
      
      List<Module> fetchedModules = [];

      // Debug each module category lookup
      try {
        Module rcModule = storedModules.firstWhere(
            (module) => module.category == 'Reading Comprehension',
            orElse: _defaultModule);
        print('[DEBUG] Reading Comprehension module: ${rcModule.title}');
        fetchedModules.add(rcModule);
      } catch (e) {
        print('[ERROR] Reading Comprehension module error: $e');
        fetchedModules.add(_defaultModule());
      }

      try {
        Module wpModule = storedModules.firstWhere(
            (module) => module.category == 'Word Pronunciation',
            orElse: _defaultModule);
        print('[DEBUG] Word Pronunciation module: ${wpModule.title}');
        fetchedModules.add(wpModule);
      } catch (e) {
        print('[ERROR] Word Pronunciation module error: $e');
        fetchedModules.add(_defaultModule());
      }

      try {
        Module vsModule = storedModules.firstWhere(
            (module) => module.category == 'Vocabulary Skills',
            orElse: _defaultModule);
        print('[DEBUG] Vocabulary Skills module: ${vsModule.title}');
        fetchedModules.add(vsModule);
      } catch (e) {
        print('[ERROR] Vocabulary Skills module error: $e');
        fetchedModules.add(_defaultModule());
      }

      try {
        Module scModule = storedModules.firstWhere(
            (module) => module.category == 'Sentence Composition',
            orElse: _defaultModule);
        print('[DEBUG] Sentence Composition module: ${scModule.title}');
        fetchedModules.add(scModule);
      } catch (e) {
        print('[ERROR] Sentence Composition module error: $e');
        fetchedModules.add(_defaultModule());
      }

      setState(() {
        allModules = fetchedModules;
        _isLoading = false;
      });
    } catch (e) {
      print('[ERROR] Module loading failed: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load modules';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getRandomModules() async {
    var rng = Random();
    List<Map<String, dynamic>> randomModules = [];
    
    try {
      for (var module in allModules) {
        if (module.title == null || module.category == null) {
          print('[WARNING] Skipping module with null fields: $module');
          continue;
        }
        
        randomModules.add({
          'title': module.title!,
          'category': module.category!,
          'status': module.completed == 3 ? 'COMPLETED' : 'NOT FINISHED',
        });
      }
      
      if (randomModules.isEmpty) {
        print('[WARNING] No valid modules found');
        return [];
      }
      
      randomModules.shuffle(rng);
      return randomModules.take(3).toList();
    } catch (e) {
      print('[ERROR] Error getting random modules: $e');
      return [];
    }
  }

  void _navigateToQuiz(Map<String, dynamic> module) {
    String? moduleTitle = module['title'] as String?;
    
    if (moduleTitle == null || moduleTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module data is incomplete')),
      );
      return;
    }

    switch (moduleTitle) {
      case 'Reading Comprehension':
        _navigateToModule(context, ReadingComprehensionLevels());
        break;
      case 'Word Pronunciation':
        _navigateToModule(context, WordPronunciationLevels());
        break;
      case 'Sentence Composition':
        _navigateToModule(context, SentenceCompositionLevels());
        break;
      case 'Vocabulary Skills':
        _navigateToModule(context, VocabularySkillsLevels());
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown module type')),
        );
    }
  }

  void _navigateToModule(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              color: const Color(0xFFF5E8C7), // Manila paper background
              padding: EdgeInsets.symmetric(
                  horizontal: width * 0.05, vertical: height * 0.05),
              child: FutureBuilder<UserProfile?>(
                future: _fetchUserStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF8B4513)));
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: GoogleFonts.montserrat(
                                color: const Color(0xFF8B4513))));
                  } else if (snapshot.hasData) {
                    final data = snapshot.data;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Image.asset(
                                'assets/black_logo_readi.png', // Black logo
                                width: 120,
                                height: 60,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => HelpPage()),
                                  );
                                },
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF8B4513), // Brown button
                                  ),
                                  child: Center(
                                    child: Text(
                                      '?',
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B4513)
                                .withOpacity(0.1), // Light brown
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(15),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ranking: ${data?.rank}',
                                  style: GoogleFonts.montserrat(
                                      color: const Color(0xFF8B4513))),
                              Text('XP Earned: ${data?.experience}',
                                  style: GoogleFonts.montserrat(
                                      color: const Color(0xFF8B4513))),
                              Text(
                                'Modules Completed: ${data?.completedModules.length}',
                                style: GoogleFonts.montserrat(
                                    color: const Color(0xFF8B4513)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Recommended Modules',
                            style: GoogleFonts.montserrat(
                                fontSize: width * 0.05,
                                color: const Color(0xFF8B4513))),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF8B4513)))
                              : _hasError
                                  ? Center(
                                      child: Text(_errorMessage,
                                          style: GoogleFonts.montserrat(
                                              color: const Color(0xFF8B4513))))
                                  : FutureBuilder<List<Map<String, dynamic>>>(
                                      future: _getRandomModules(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                              child: CircularProgressIndicator(
                                                  color: Color(0xFF8B4513)));
                                        } else if (snapshot.hasError) {
                                          return Center(
                                              child: Text('Error: ${snapshot.error}',
                                                  style: GoogleFonts.montserrat(
                                                      color: const Color(0xFF8B4513))));
                                        } else if (snapshot.hasData &&
                                            snapshot.data!.isNotEmpty) {
                                          return ListView.builder(
                                            itemCount: snapshot.data!.length,
                                            itemBuilder: (context, index) {
                                              var module = snapshot.data![index];

                                              return Card(
                                                margin: const EdgeInsets.symmetric(
                                                    vertical: 10),
                                                color: const Color.fromARGB(
                                                    255, 249, 222, 194),
                                                child: ListTile(
                                                  title: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        module['title'],
                                                        style: GoogleFonts.montserrat(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18,
                                                          color: const Color(
                                                              0xFF8B4513), // Brown
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        'Status: ${module['status']}',
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 14,
                                                          color: const Color(
                                                              0xFF8B4513), // Brown
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  onTap: () => _navigateToQuiz(module),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                        return Center(
                                            child: Text('No modules available.',
                                                style: GoogleFonts.montserrat(
                                                    color: const Color(0xFF8B4513))));
                                      },
                                    ),
                        ),
                      ],
                    );
                  }
                  return Center(
                      child: Text('User document does not exist.',
                          style: GoogleFonts.montserrat(
                              color: const Color(0xFF8B4513))));
                },
              ),
            ),
            if (_isMenuOpen)
              Container(
                color: Colors.black.withOpacity(0.5), // Less dim (50% opacity)
              ),
            Positioned(
              bottom: 20,
              left: width / 2 - 30, // Center the button
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF8B4513), // Brown button
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 30),
                ),
              ),
            ),
            if (_isMenuOpen)
              Positioned(
                bottom: 90,
                left: width / 2 - 100, // Left side for Modules
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () {
                      _toggleMenu();
                      Navigator.pushNamed(context, '/modules_menu');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B4513),
                      ),
                      child: const Icon(Icons.book, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (_isMenuOpen)
              Positioned(
                bottom: 140,
                left: width / 2 - 25, // Top for Profile
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () {
                      _toggleMenu();
                      Navigator.pushNamed(context, '/profile_menu');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B4513),
                      ),
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (_isMenuOpen)
              Positioned(
                bottom: 90,
                left: width / 2 + 50, // Right side for Settings
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: GestureDetector(
                    onTap: () {
                      _toggleMenu();
                      Navigator.pushNamed(context, '/settings_menu');
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF8B4513),
                      ),
                      child: const Icon(Icons.settings, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
