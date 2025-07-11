import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/models/module.dart';
import 'package:i_read_app/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:i_read_app/firebase_options.dart';
// import 'package:i_read_app/services/api.dart';
import 'package:i_read_app/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  // ApiService apiService = ApiService();
  StorageService storageService = StorageService();
  final storage = FlutterSecureStorage();

  bool _isEmailValid(String email) {
    final emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email);
  }

  void _validateEmail(String value) {
    if (value.isNotEmpty) {
      if (!_isEmailValid(value)) {
        setState(() {
          _emailError = 'Please input a valid email';
        });
      } else {
        setState(() {
          _emailError = null; // Clear error
        });
      }
    } else {
      setState(() {
        _emailError = null; // No error message for empty input
      });
    }
  }

  bool _isPasswordValid(String password) {
    return password.length >= 8;
  }

  void _validatePassword(String value) {
    if (value.isNotEmpty) {
      if (!_isPasswordValid(value)) {
        setState(() {
          _passwordError = 'Please input at least 8 characters';
        });
      } else {
        setState(() {
          _passwordError = null; // Clear error
        });
      }
    } else {
      setState(() {
        _passwordError = null; // No error message for empty input
      });
    }
  }

  void _handleLogin() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    _validateEmail(email);
    _validatePassword(password);

    if (_emailError == null && _passwordError == null) {
      // Initialize Firebase if not already initialized
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase may already be initialized, ignore error
      }

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // On successful login, navigate to /home
        Navigator.of(context).pushReplacementNamed('/home');
      } on FirebaseAuthException catch (e) {
        String errorMsg = '';
        if (e.code == 'user-not-found') {
          errorMsg = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          errorMsg = 'Wrong password provided.';
        } else {
          errorMsg = 'Login failed: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.05,
          vertical: height * 0.02,
        ),
        color: const Color(0xFFF5E8C7), // Manila paper background
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: 400), // Max width for larger screens
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/black_logo_readi.png', // Updated logo
                        width: 200,
                        height: 100),
                    const Text('where learning gets better.',
                        style: TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0), // Brown text
                            fontSize: 16)),
                    const SizedBox(height: 10),
                    const Divider(
                        color: Color(0xFF8B4513), // Brown divider
                        thickness: 1),
                    const SizedBox(height: 20),
                    Text('start your journey.',
                        style: GoogleFonts.montserrat(
                            color: const Color(0xFF8B4513), // Brown text
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'E-Mail',
                        labelStyle:
                            const TextStyle(color: Color(0xFF8B4513)), // Brown
                        filled: true,
                        fillColor: const Color(0xFF8B4513)
                            .withOpacity(0.1), // Light brown fill
                        border: const OutlineInputBorder(),
                        hintText: 'Enter E-mail here...',
                        hintStyle:
                            const TextStyle(color: Color(0xFF8B4513)), // Brown
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFF8B4513)),
                        counterText: '',
                      ),
                      style: GoogleFonts.montserrat(
                          color: const Color(0xFF8B4513)), // Brown text
                      onChanged: _validateEmail,
                    ),
                    if (_emailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_emailError!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 20),
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText: 'Access Code',
                        labelStyle:
                            const TextStyle(color: Color(0xFF8B4513)), // Brown
                        filled: true,
                        fillColor: const Color(0xFF8B4513)
                            .withOpacity(0.1), // Light brown fill
                        border: const OutlineInputBorder(),
                        hintText: 'Enter Access code here...',
                        hintStyle:
                            const TextStyle(color: Color(0xFF8B4513)), // Brown
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFF8B4513)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8B4513)), // Brown
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        counterText: '',
                      ),
                      style: GoogleFonts.montserrat(
                          color: const Color(0xFF8B4513)), // Brown text
                      onChanged: _validatePassword,
                    ),
                    if (_passwordError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_passwordError!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF8B4513), // Brown button
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text('Login',
                          style: GoogleFonts.montserrat(color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    // Uncomment and update if needed:
                    /*
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.montserrat(color: Color(0xFF8B4513)),
                        children: [
                          const TextSpan(text: "Don't have an Account? "),
                          TextSpan(
                            text: 'Sign Up here.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.of(context)
                                    .pushReplacementNamed('/register');
                              },
                          ),
                        ],
                      ),
                    ),
                    */
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
