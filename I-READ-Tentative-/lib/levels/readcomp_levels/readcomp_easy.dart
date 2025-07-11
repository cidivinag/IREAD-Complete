import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';

import '../../pages/modulecontent_page.dart';

// tests

class ReadCompEasy extends StatefulWidget {
  const ReadCompEasy({super.key});sfasf

  @override
  _ReadCompEasyState createState() => _ReadCompEasyState();
}

class _ReadCompEasyState extends State<ReadCompEasy> {
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
            module.category == 'Reading Comprehension')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context,
            '/reading_comprehension_levels'); // Navigate back to ReadingComprehensionLevels
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
              Navigator.pushNamed(context, '/reading_comprehension_levels');
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
                  child: CircularProgressIndicator(
                    color: Color(0xFF8B4513), // Brown
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading modules: ${snapshot.error}',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF8B4513), // Brown
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No Easy modules available',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF8B4513), // Brown
                    ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: SizedBox(
        width: 400, // Increased width
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ModuleContentPage(
                  module: module,
                  backRoute: '/read_comp_easy',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B4513), // Brown
            padding: const EdgeInsets.symmetric(vertical: 25),
          ),
          child: Text(
            module.title,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white, // White text
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
