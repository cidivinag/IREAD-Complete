import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:i_read_app/models/module.dart';

class FirestoreModuleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Module>> getModules({bool onlyPublished = true}) async {
    Query query = _firestore.collection('modules');
    if (onlyPublished) {
      query = query.where('is_published', isEqualTo: 'true');
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Convert Firestore string fields to expected types in Module
      return Module(
        id: data['id'] ?? doc.id,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        difficulty: data['difficulty'] ?? '',
        category: data['category'] ?? '',
        slug: data['slug'] ?? '',
        createdBy: data['created_by_id'] ?? '',
        createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: data['updated_at'] != null && data['updated_at'] != '' ? DateTime.tryParse(data['updated_at']) : null,
        questionsPerModule: [], // To be filled if you want to fetch questions here
        materials: [], // To be filled if you want to fetch materials here
        isLocked: false, // You can set logic here if needed
        completed: 0, // Set based on user progress if needed
        fileUrl: data['file_url'] ?? '',
      );
    }).toList();
  }
}
