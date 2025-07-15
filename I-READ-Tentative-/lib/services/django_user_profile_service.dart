// 📄 django_user_profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_read_app/models/user.dart'; // Reuse your existing models
import 'package:firebase_auth/firebase_auth.dart';

class DjangoUserProfileService {
  final String baseUrl =
      'https://your-api.com'; // replace with actual backend URL

  Future<UserProfile?> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final completedModulesRaw = data['completed_modules'] ?? [];
      final completedModules = (completedModulesRaw as List)
          .map((m) => CompletedModule.fromJson(m))
          .toList();

      return UserProfile(
        id: user?.uid ?? '',
        username: data['username'] ?? '',
        email: data['email'] ?? '',
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        middleName: data['middle_name'] ?? '',
        isStaff: data['is_staff'] ?? false,
        isActive: data['is_active'] ?? true,
        experience: data['experience'] ?? 0,
        rank: data['rank'] ?? 'Unranked',
        section: data['section'] ?? '',
        completedModules: completedModules,
      );
    } else {
      print('Error: ${response.statusCode} ${response.body}');
      return null;
    }
  }
}
