import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class FirestoreUserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      // Parse completed modules as a list of CompletedModule
      final completedModulesRaw = data['completed_modules'] ?? [];
      final completedModules = (completedModulesRaw as List)
          .map((m) => CompletedModule.fromJson(m as Map<String, dynamic>))
          .toList();

      return UserProfile(
        id: data['id'] ?? doc.id,
        username: data['username'] ?? '',
        email: data['email'] ?? '',
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        middleName: data['middle_name'] ?? '',
        isStaff: data['is_staff'] ?? false,
        isActive: data['is_active'] ?? true,
        experience: data['experience'] ?? 0,
        rank: data['rank'] ?? 0,
        strand: data['strand'] ?? '',
        completedModules: completedModules,
        section: data['section'] ?? '',
      );
    } catch (e) {
      print('Failed to fetch user profile: $e');
      return null;
    }
  }
}
