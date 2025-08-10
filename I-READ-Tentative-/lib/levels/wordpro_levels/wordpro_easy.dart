import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';
import '../../pages/modulecontent_page.dart';

class WordProEasy extends StatefulWidget {
  const WordProEasy({super.key});

  @override
  _WordProEasyState createState() => _WordProEasyState();
}

class _WordProEasyState extends State<WordProEasy> {
  final ApiService apiService = ApiService();
  late Future<List<Module>> _easyModulesFuture;

  @override
  void initState() {
    super.initState();
    _easyModulesFuture = _fetchEasyModules();
  }

  Future<List<Module>> _fetchEasyModules() async {
    List<Module> modules = await apiService.getModules();
    return modules
        .where((module) =>
            module.difficulty == 'Easy' &&
            module.category == 'Word Pronunciation')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    
    // Debug: Print all modules being rendered when the future completes
    _easyModulesFuture.then((modules) {
      print('Modules in WordProEasy:');
      for (var module in modules) {
        print('Module: ${module.id} - ${module.title} (${module.difficulty})');
        print('  isLocked: ${module.isLocked}');
        print('  isPublished: ${module.isPublished}');
        print('  category: ${module.category}');
      }
    });

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/wordpro_levels');
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5E8C7), // Manila paper
          elevation: 0, // Flat look
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: Color(0xFF8B4513)), // Brown back arrow
            onPressed: () {
              Navigator.pushNamed(context, '/wordpro_levels');
            },
          ),
          title: Text(
            'Easy',
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
          color: const Color(0xFFF5E8C7), // Manila paper background
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<List<Module>>(
            future: _easyModulesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B4513)),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading modules: ${snapshot.error}',
                    style:
                        GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No Easy modules available',
                    style:
                        GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
                  ),
                );
              }

              final easyModules = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  children: easyModules
                      .map((module) => _buildModuleButton(context, module))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModuleButton(BuildContext context, Module module) {
    // Debug: Print module details when building button
    print('Building button for module: ${module.id} - ${module.title}');
    print('  isLocked: ${module.isLocked}');
    print('  isPublished: ${module.isPublished}');
    print('  category: ${module.category}');
    print('  difficulty: ${module.difficulty}');
    
    // Determine if module should be locked based on both isLocked and isPublished
    final bool shouldBeLocked = module.isLocked || !module.isPublished;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SizedBox(
        width: 400,
        child: ElevatedButton(
          onPressed: shouldBeLocked
              ? () => _showLockedModuleDialog(context)
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModuleContentPage(
                        module: module,
                        backRoute: '/wordpro_easy',
                      ),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: shouldBeLocked 
                ? Colors.grey[400]  // Gray for locked modules
                : const Color(0xFF8B4513), // Brown for unlocked modules
            padding: const EdgeInsets.symmetric(vertical: 25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (shouldBeLocked) 
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.lock, color: Colors.white),
                ),
              Expanded(
                child: Text(
                  module.title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLockedModuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5E8C7), // Match app theme
          title: Text(
            'Module Locked',
            style: GoogleFonts.montserrat(
              color: const Color(0xFF8B4513),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This module is still locked. Please contact your supervisor for more information.',
            style: GoogleFonts.montserrat(
              color: Colors.black87,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF8B4513),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
