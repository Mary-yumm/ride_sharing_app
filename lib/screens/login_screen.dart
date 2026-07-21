import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ride_sharing_app/widgets/auth.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  String? errorMessage = '';

  Future<void> signInWithEmailAndPassword() async {
    // Validate email and password fields
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please fill in all fields';
      });
      return; // Stop execution if validation fails
    }

    try {
      await Auth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

// Ensure the widget is still mounted before navigating
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/hamburgerMenu');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.message;
        });
      }
    }
  }


  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        labelText: title,
        labelStyle: const TextStyle(color: AppColors.white),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: AppColors.white,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        )
            : null,
      ),
    );
  }

  Widget _errorMessage() {
    return Text(
      errorMessage == '' ? '' : '$errorMessage',
      style: const TextStyle(color: Colors.red),
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: signInWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white, // Set the button's background color
        foregroundColor: AppColors.primary, // Set the text color
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Optional: adjust padding
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Optional: adjust text style
      ),
      child: const Text('Login'),
    );
  }


  Widget _registerButton() {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/register');
      },
      style: TextButton.styleFrom(
        foregroundColor: AppColors.white, // Button text color
      ),
      child: const Text('Register instead'),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Page',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.white)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 4.0, // Default elevation for shadow
        shadowColor: Colors.black.withOpacity(0.3), // Customize shadow color
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondaryLight,
                AppColors.secondaryLight,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ), // Optional: Add gradient to the AppBar
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10.0,
                offset: Offset(0, 4), // Shadow below the AppBar
              ),
            ],
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: AppColors.secondary.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _entryField('Email', _emailController),
            const SizedBox(height: 20),
            _entryField('Password', _passwordController, isPassword: true),
            const SizedBox(height: 20),
            _errorMessage(),
            const SizedBox(height: 20),
            _submitButton(),
            _registerButton(),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

}
