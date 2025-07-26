import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/services/api.dart';
import 'package:i_read_app/services/django_user_profile_service.dart';
import 'package:i_read_app/services/storage.dart';

class ModulesMenu extends StatefulWidget {
  const ModulesMenu({
    super.key,
    required Null Function(dynamic modules) onModulesUpdated,
  });

  @override
  _ModulesMenuState createState() => _ModulesMenuState();
}

class _ModulesMenuState extends State<ModulesMenu> {
  List<Map<String, dynamic>> modules = [];
  bool isLoading = true;
  int completedModulesCount = 0;
  int totalModulesCount = 0;

  final ApiService apiService = ApiService();

  String _getStatus() {
    if (completedModulesCount == 0) return 'NOT FINISHED';
    if (completedModulesCount == totalModulesCount) return 'COMPLETED';
    return 'IN PROGRESS';
  }

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
  try {
    Map<String, dynamic> progressData = await apiService.getCategoryProgress();

    List<Map<String, dynamic>> categoryList = [];
    int totalCount = 0;
    int completedCount = 0;

    progressData.forEach((category, data) {
      final int total = data['total'];
      final int completed = data['completed'];

      categoryList.add({
        'category': category,
        'total': total,
        'completed': completed,
      });

      totalCount += total;
      completedCount += completed;
    });

    setState(() {
      modules = categoryList;
      totalModulesCount = totalCount;
      completedModulesCount = completedCount;
      isLoading = false;
    });
  } catch (e) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load module progress: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5E8C7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B4513)),
          onPressed: () => Navigator.pushNamed(context, '/home'),
        ),
        title: Text(
          'Modules',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8B4513),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF5E8C7),
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.05,
          vertical: height * 0.02,
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B4513)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Progress',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: totalModulesCount > 0
                              ? completedModulesCount / totalModulesCount
                              : 0,
                          backgroundColor: Colors.grey[300],
                          color: const Color(0xFF8B4513),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completedModulesCount / $totalModulesCount completed',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Status: ${_getStatus()}',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: const Color(0xFF8B4513),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        String currentModule = modules[index]['category'];
                        int completed = modules[index]['completed'] as int;
                        int total = modules[index]['total'] as int;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: const Color.fromARGB(255, 249, 222, 194),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentModule,
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: const Color(0xFF8B4513),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                LinearProgressIndicator(
                                  value: total > 0 ? completed / total : 0,
                                  backgroundColor: Colors.grey[300],
                                  color: const Color(0xFF8B4513),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '$completed / $total completed',
                                  style: GoogleFonts.montserrat(
                                    color: const Color(0xFF8B4513),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (currentModule == 'Reading Comprehension') {
                                Navigator.pushNamed(
                                  context,
                                  '/reading_comprehension_levels',
                                );
                              } else if (currentModule == 'Word Pronunciation') {
                                Navigator.pushNamed(
                                  context,
                                  '/wordpro_levels',
                                );
                              } else if (currentModule == 'Sentence Composition') {
                                Navigator.pushNamed(
                                  context,
                                  '/sentcomp_levels',
                                );
                              } else if (currentModule == 'Vocabulary Skills') {
                                Navigator.pushNamed(
                                  context,
                                  '/vocabskills_levels',
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
