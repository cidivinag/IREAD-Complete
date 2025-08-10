import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';
import '../../pages/modulecontent_page.dart';

class SentCompHard extends StatefulWidget {
  const SentCompHard({super.key});

  @override
  _SentCompHardState createState() => _SentCompHardState();
}

class _SentCompHardState extends State<SentCompHard> {
  final ApiService apiService = ApiService();
  late Future<List<Module>> _hardModulesFuture;

  @override
  void initState() {
    super.initState();
    _hardModulesFuture = _fetchHardModules();
  }

  Future<List<Module>> _fetchHardModules() async {
    List<Module> modules = await apiService.getModules();
    return modules
        .where((module) =>
            module.difficulty == 'Hard' &&
            module.category == 'Sentence Composition')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/sentcomp_levels');
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
              Navigator.pushNamed(context, '/sentcomp_levels');
            },
          ),
          title: Text(
            'Hard',
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
            future: _hardModulesFuture,
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
                    'No Hard modules available',
                    style:
                        GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
                  ),
                );
              }

              final hardModules = snapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  children: hardModules
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
                        backRoute: '/sentcomp_hard',
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
                  padding: EdgeInsets.only(left: 16.0, right: 8.0),
                  child: Icon(Icons.lock, color: Colors.white, size: 20),
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
