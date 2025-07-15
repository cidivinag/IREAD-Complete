import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_read_app/services/api.dart';
import 'package:i_read_app/services/storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Commented out Firebase imports
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:i_read_app/firebase_options.dart';

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
  final ApiService apiService = ApiService();
  final StorageService storageService = StorageService();
  final storage = FlutterSecureStorage();

  bool _isEmailValid(String email) {
    final emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email);
  }

  void _validateEmail(String value) {
    if (value.trim().isNotEmpty) {
      if (!_isEmailValid(value)) {
        setState(() {
          _emailError = 'Please input a valid email';
        });
      } else {
        setState(() {
          _emailError = null;
        });
      }
    } else {
      setState(() {
        _emailError = null;
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
          _passwordError = null;
        });
      }
    } else {
      setState(() {
        _passwordError = null;
      });
    }
  }

  void _handleLogin() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    _validateEmail(email);
    _validatePassword(password);

    if (_emailError == null && _passwordError == null) {
      try {
        final token = await apiService.postGenerateToken(email, password);
        if (token != null) {
          final modules = await apiService.getModules();
          print('Modules fetched: ${modules.length}');
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to log in: No token received.')),
          );
        }
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
        color: const Color(0xFFF5E8C7),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/black_logo_readi.png',
                        width: 200, height: 100),
                    const Text('where learning gets better.',
                        style: TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0), fontSize: 16)),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFF8B4513), thickness: 1),
                    const SizedBox(height: 20),
                    Text('start your journey.',
                        style: GoogleFonts.montserrat(
                            color: const Color(0xFF8B4513),
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'E-Mail',
                        labelStyle: const TextStyle(color: Color(0xFF8B4513)),
                        filled: true,
                        fillColor: const Color(0xFF8B4513).withOpacity(0.1),
                        border: const OutlineInputBorder(),
                        hintText: 'Enter E-mail here...',
                        hintStyle: const TextStyle(color: Color(0xFF8B4513)),
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFF8B4513)),
                        counterText: '',
                      ),
                      style: GoogleFonts.montserrat(
                          color: const Color(0xFF8B4513)),
                      onChanged: _validateEmail,
                    ),
                    if (_emailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_emailError!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText: 'Access Code',
                        labelStyle: const TextStyle(color: Color(0xFF8B4513)),
                        filled: true,
                        fillColor: const Color(0xFF8B4513).withOpacity(0.1),
                        border: const OutlineInputBorder(),
                        hintText: 'Enter Access code here...',
                        hintStyle: const TextStyle(color: Color(0xFF8B4513)),
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFF8B4513)),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF8B4513)),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        counterText: '',
                      ),
                      style: GoogleFonts.montserrat(
                          color: const Color(0xFF8B4513)),
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
                        backgroundColor: const Color(0xFF8B4513),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text('Login',
                          style: GoogleFonts.montserrat(color: Colors.white)),
                    ),
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
