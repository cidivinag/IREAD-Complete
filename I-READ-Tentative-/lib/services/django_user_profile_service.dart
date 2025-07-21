// 📄 django_user_profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:i_read_app/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Commented out Firebase

class DjangoUserProfileService {
  final String baseUrl =
      'http://10.0.2.2:8000'; // Replace with your backend URL
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<UserProfile?> fetchUserProfile() async {
    try {
      // Read token from secure storage (set during login)
      final token = await _secureStorage.read(key: 'accessToken');
      print('[DEBUG] Token from secure storage: $token');

      if (token == null) {
        print('❌ No access token found');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
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
          id: data['id']?.toString() ?? '',
          username: data['username'] ?? '',
          email: data['email'] ?? '',
          firstName: data['first_name'] ?? '',
          lastName: data['last_name'] ?? '',
          middleName: data['middle_name'] ?? '',
          isStaff: data['is_staff'] ?? false,
          isActive: data['is_active'] ?? true,
          experience: data['experience'] ?? 0,
          rank: data['rank'] ?? 0, // Ensure this matches your model's type
          section: data['section'] is Map
              ? data['section']['section'] ?? ''
              : data['section'] ?? '',
          completedModules: completedModules,
        );
      } else {
        print('❌ API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Exception in fetchUserProfile: $e');
      return null;
    }
  }
}
