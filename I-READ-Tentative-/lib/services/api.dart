import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:i_read_app/constant.dart';
import 'package:i_read_app/models/access_token.dart';
import 'package:i_read_app/models/answer.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/models/question.dart';
import 'package:i_read_app/models/user.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Commented out Firebase

class ApiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Commented out Firebase token getter
  // Future<String?> _getFirebaseIdToken() async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     return await user?.getIdToken();
  //   } catch (e) {
  //     log('Error getting Firebase ID token: $e');
  //     return null;
  //   }
  // }

  Future<AccessToken?> postGenerateToken(String email, String password) async {
    try {
      print("🔐 Attempting token request...");
      Map<String, String> requestBody = {"email": email, "password": password};
      Map<String, String> requestHeader = {"Content-Type": 'application/json'};

      var url = Uri.parse('${Constants.baseUrl}/api/token/');
      var response = await http
          .post(url, headers: requestHeader, body: jsonEncode(requestBody))
          .timeout(const Duration(seconds: 10));
      print("Response body: ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AccessToken accessToken = AccessToken.fromJson(data);
        await _secureStorage.write(
            key: 'accessToken', value: accessToken.accessToken);
        String? stored = await _secureStorage.read(key: 'accessToken');
        print("✅ Stored token (from secure storage): $stored");
        return accessToken;
      } else {
        log('Failed to retrieve access token. Status code: ${response.statusCode}');
        throw 'Failed to retrieve access token. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<UserProfile?> getProfile() async {
    try {
      String? idToken =
          await getStoredAccessToken(); // replaced Firebase token with stored Django token
      print('Stored token after login: $idToken');
      Map<String, String> requestHeader = {
        "Content-Type": 'application/json',
        "Authorization": 'Bearer $idToken',
      };

      var url = Uri.parse('${Constants.baseUrl}/api/profile');
      var response = await http.get(url, headers: requestHeader);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data);
      } else {
        log('Failed to retrieve profile. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw 'Failed to retrieve profile. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<List<Module>> getModules() async {
    try {
      String? idToken = await getStoredAccessToken(); // replaced Firebase token
      print('Stored token: $idToken');

      Map<String, String> requestHeader = {
        "Content-Type": 'application/json',
        "Authorization": 'Bearer $idToken',
      };

      var url = Uri.parse('${Constants.baseUrl}/api/modules');
      var response = await http.get(url, headers: requestHeader);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((moduleJson) => Module.fromJson(moduleJson)).toList();
      } else {
        log('Failed to retrieve modules. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw 'Failed to retrieve modules. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<List<Question>?> getModuleQuestions(String moduleId) async {
    try {
      String? idToken = await getStoredAccessToken();
      Map<String, String> requestHeader = {
        "Content-Type": 'application/json',
        "Authorization": 'Bearer $idToken',
      };

      var url =
          Uri.parse('${Constants.baseUrl}/api/modules/$moduleId/questions');
      var response = await http.get(url, headers: requestHeader);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((moduleJson) => Question.fromJson(moduleJson)).toList();
      } else {
        log('Failed to retrieve questions. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw 'Failed to retrieve questions. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> getQuestionAnswer(String questionId) async {
    try {
      String? idToken = await getStoredAccessToken();
      Map<String, String> requestHeader = {
        "Content-Type": 'application/json',
        "Authorization": 'Bearer $idToken',
      };

      var url = Uri.parse('${Constants.baseUrl}/api/questions/$questionId');
      var response = await http.get(url, headers: requestHeader);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['answer'];
      } else {
        log('Failed to retrieve questions. Status code: ${response.statusCode}');
        throw 'Failed to retrieve questions. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> postSubmitModuleAnswer(
      String moduleId, List<Answer> answers) async {
    try {
      Map<String, List<Answer>> requestBody = {"answers": answers};
      String? idToken = await getStoredAccessToken();
      Map<String, String> requestHeader = {
        "Content-Type": 'application/json',
        "Authorization": 'Bearer $idToken',
      };

      var url = Uri.parse('${Constants.baseUrl}/api/modules/$moduleId/answer');
      var response = await http.post(
        url,
        headers: requestHeader,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log('Failed to submit module answer. Status code: ${response.statusCode}');
        throw 'Failed to submit module answer. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> postAssessPronunciation(
    String filePath,
    String referenceText,
    questionId,
  ) async {
    try {
      String? idToken = await getStoredAccessToken();
      Map<String, String> requestHeader = {
        "Authorization": 'Bearer $idToken',
        //"Content-Type": "multipart/form-data",
      };

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/api/assess/pronunciation'),
      );

      request.headers.addAll(requestHeader);
      request.files
          .add(await http.MultipartFile.fromPath('audio_file', filePath));
      request.fields['reference_text'] = referenceText;
      request.fields['question_id'] = questionId;
      //request.fields['Authorization'] = 'Bearer $idToken';

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await http.Response.fromStream(response);
        log('File uploaded successfully: ${responseBody.body}');
        return jsonDecode(responseBody.body);
      } else {
        log('File upload failed with status: ${response.statusCode}');
        throw 'Failed to upload file. Status code: ${response.statusCode}';
      }
    } catch (e) {
      log('Error occurred: $e');
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> postModuleAnswers({
  required String moduleId,
  required List<Map<String, dynamic>> answers,
}) async {
  try {
    String? idToken = await getStoredAccessToken();
    Map<String, String> requestHeader = {
      "Content-Type": 'application/json',
      "Authorization": 'Bearer $idToken',
    };

    var url = Uri.parse('${Constants.baseUrl}/api/modules/$moduleId/answer');
    var response = await http.post(
      url,
      headers: requestHeader,
      body: jsonEncode({"answers": answers}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      log('❌ Failed to submit answers. Status: ${response.statusCode}');
      log('Response body: ${response.body}');
      throw 'Failed to submit answers.';
    }
  } catch (e) {
    log('⚠️ Error in postModuleAnswers: $e');
    rethrow;
  }
}

  Future<String?> getStoredAccessToken() async {
    return await _secureStorage.read(key: 'accessToken');
  }

  Future<void> clearAccessToken() async {
    await _secureStorage.delete(key: 'accessToken');
  }
}
