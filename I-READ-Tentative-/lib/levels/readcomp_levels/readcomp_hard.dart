import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';
import '../../pages/modulecontent_page.dart';

class ReadCompHard extends StatefulWidget {
  const ReadCompHard({super.key});

  @override
  _ReadCompHardState createState() => _ReadCompHardState();
}

class _ReadCompHardState extends State<ReadCompHard> {
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
            module.category == 'Reading Comprehension')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/reading_comprehension_levels');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5E8C7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
            onPressed: () {
              Navigator.pushNamed(context, '/reading_comprehension_levels');
            },
          ),
          titleSpacing: 0,
          title: Text(
            'Hard Level',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B4513),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFF5E8C7),
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<List<Module>>(
            future: _hardModulesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF8B4513),
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading modules: ${snapshot.error}',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF8B4513),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No Hard modules available',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF8B4513),
                    ),
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
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: shouldBeLocked ? Colors.grey[400] : const Color(0xFF8B4513),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: shouldBeLocked
                ? () => _showLockedModuleDialog(context)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModuleContentPage(
                          module: module,
                          backRoute: '/read_comp_hard',
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (shouldBeLocked) 
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: Icon(Icons.lock, color: Colors.white, size: 20),
                    ),
                  Expanded(
                    child: Text(
                      module.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
            'This module is still unpublished. Please contact your supervisor for more information.',
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
