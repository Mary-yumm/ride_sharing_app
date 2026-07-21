import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ride_sharing_app/widgets/auth.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';
import 'package:firebase_database/firebase_database.dart';


class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _obscureText = true;
  String? errorMessage = '';
  String? _selectedReligion;

  Widget _religionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedReligion,
      decoration: InputDecoration(
        labelText: 'Religion',
        labelStyle: const TextStyle(color: Colors.black),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
      ),
      items: <String>['Muslim', 'Non-Muslim'].map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedReligion = newValue;
        });
      },
    );
  }


  Future<void> createUserWithEmailAndPassword() async {
    try {
      // Create user with email and password
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Get the user object
      User? user = userCredential.user;

      if (user != null) {
        // Save the phone number to Realtime Database
        DatabaseReference dbRef = FirebaseDatabase.instance.ref("users/${user.uid}");
        await dbRef.set({
          "email": _emailController.text,
          "phone": _phoneController.text,
          "name": _nameController.text,
          "religion": _selectedReligion,
        });
      }

      // Navigate back to the login page
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Widget _entryField(String title, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: const TextStyle(color: Colors.black),
      keyboardType: title == 'Phone Number' ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: title,
        labelStyle: const TextStyle(color: Colors.black),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.black,
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
      onPressed: createUserWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondaryLight, // Set the button's background color
        foregroundColor: Colors.white, // Set the text color
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Optional: adjust padding
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), // Optional: adjust text style
      ),
      child: const Text('Register'),
    );
  }

  Widget _loginButton() {
    return TextButton(
      onPressed: () {
        Navigator.pop(context); // Go back to LoginPage after registration
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.black,
      ),
      child: const Text('Login instead'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SignUp Page',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.white),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 4.0,
        shadowColor: Colors.black.withOpacity(0.3),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.secondaryLight,
                AppColors.secondaryLight,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height, // Match screen height
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _entryField('Name', _nameController),
                  const SizedBox(height: 20),
                  _entryField('Email', _emailController),
                  const SizedBox(height: 20),
                  _entryField('Password', _passwordController, isPassword: true),
                  const SizedBox(height: 20),
                  _entryField('Phone Number', _phoneController),
                  const SizedBox(height: 20),
                  _religionDropdown(),
                  const SizedBox(height: 20),
                  _errorMessage(),
                  const SizedBox(height: 20),
                  _submitButton(),
                  const SizedBox(height: 10),
                  _loginButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



}
