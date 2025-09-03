import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';
import 'package:url_launcher/url_launcher.dart';
// Removed webview_flutter import as it's not needed for URL launching

import '../quiz/app_quiz.dart';
import '../quiz/wordpro_quiz.dart';

class ModuleContentPage extends StatefulWidget {
  final Module module;
  final String backRoute;
  late final ApiService apiService;

  ModuleContentPage({super.key, required this.module, required this.backRoute}) {
    apiService = ApiService();
  }

  @override
  State<ModuleContentPage> createState() => _ModuleContentPageState();
}

class _ModuleContentPageState extends State<ModuleContentPage> {

  Future<void> _downloadFile(String url, BuildContext context) async {
    log('🔍 Attempting to open URL in browser: $url');
    
    try {
      final Uri uri = Uri.parse(url);
      log('✅ Parsed URI: $uri');
      
      // Always try to open in external browser first
      log('🌐 Attempting to open in external browser...');
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          log('✅ Successfully opened in browser');
          return;
        } else {
          log('⚠️ Could not launch browser, trying alternative method...');
        }
      } catch (e) {
        log('❌ Error launching browser: $e');
      }
      
      // Fallback: Try with platform default
      try {
        log('🔄 Trying platform default launcher...');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        
        if (launched) {
          log('✅ Successfully opened with platform default');
          return;
        }
      } catch (e) {
        log('❌ Error with platform default: $e');
      }
      
      // If we get here, all launch attempts failed
      log('🔍 Verifying URL accessibility...');
      try {
        final response = await http.head(uri);
        log('📡 Server response: ${response.statusCode}');
        
        if (!mounted) return;
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open PDF. Please try again or check your browser settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error (${response.statusCode}). Please try again later.'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        log('❌ Error checking URL: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to the server. Please check your internet connection.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      log('❌ Error in _downloadFile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while opening the file.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Check if the quiz is completed using the 'completed' field
  Future<bool> _isQuizCompleted(String moduleId) async {
    try {
      List<Module> modules = await widget.apiService.getModules();
      Module updatedModule = modules.firstWhere((m) => m.id == moduleId);
      log('Module ${updatedModule.title} completion status: ${updatedModule.completed}');
      return updatedModule.completed > 0;
    } catch (e) {
      log('Error checking quiz completion: $e');
      return false; // Default to false if check fails
    }
  }

  // Show confirmation dialog for completed quiz
  Future<bool> _showReattemptConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF5E8C7), // Manila paper
              title: Text(
                'Quiz Already Completed',
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF8B4513),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'The quiz you\'re about to take is already completed. Answering it again won\'t earn you points, and all answers will be marked as mistakes. Do you want to continue?',
                style: GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // No
                  child: Text(
                    'No',
                    style:
                        GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // Yes
                  child: Text(
                    'Yes',
                    style:
                        GoogleFonts.montserrat(color: const Color(0xFF8B4513)),
                  ),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dismissed
  }

  @override
  Widget build(BuildContext context) {
    // Access module and backRoute through widget
    final module = widget.module;
    final backRoute = widget.backRoute;
    log('Module: ${module.title}, Materials count: ${module.materials.length}');
    if (module.materials.isNotEmpty) {
      log('First material: ${module.materials[0].name}, URL: ${module.materials[0].fileUrl}');
    }

    final String fileTitle = module.materials.isNotEmpty
        ? module.materials[0].name
        : 'Untitled File';
    final String fileUrl = module.materials.isNotEmpty
        ? 'http://10.0.2.2:8000${module.materials[0].fileUrl.startsWith('/') ? '' : '/'}${module.materials[0].fileUrl}'
        : '';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, widget.backRoute);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5E8C7), // Manila paper
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
            onPressed: () {
              Navigator.pushReplacementNamed(context, widget.backRoute);
            },
          ),
          title: Text(
            'Module Description',
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
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF8B4513),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 2, color: const Color(0xFF8B4513)), // Divider
                const SizedBox(height: 20),
                Text(
                  'Description:',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF8B4513),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  module.description,
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFF8B4513),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Container(height: 2, color: const Color(0xFF8B4513)), // Divider
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fileTitle,
                        style: GoogleFonts.montserrat(
                          color: const Color(0xFF8B4513),
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.download, color: Color(0xFF8B4513)),
                      onPressed: fileUrl.isNotEmpty
                          ? () => _downloadFile(fileUrl, context)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(height: 2, color: const Color(0xFF8B4513)), // Divider
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 400,
                    child: ElevatedButton(
                      onPressed: () async {
                        bool isCompleted = await _isQuizCompleted(module.id);
                        if (isCompleted) {
                          bool proceed = await _showReattemptConfirmation(context);
                          if (!proceed) return;
                        }
                        if (module.category == 'Word Pronunciation') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WordProQuiz(
                                moduleTitle: module.title,
                                uniqueIds: [module.id],
                                difficulty: module.difficulty,
                              ),
                            ),
                          ).then((_) {
                            Navigator.pushReplacementNamed(context, '/modules_menu');
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AppQuiz(
                                module: module,
                                backRoute: backRoute,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        padding: const EdgeInsets.symmetric(vertical: 25),
                      ),
                      child: Text(
                        'Start Quiz',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

