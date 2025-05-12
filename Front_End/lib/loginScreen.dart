

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:surveilai/MyHomePage.dart';
import 'package:surveilai/signupscreen.dart';

import 'forgot_password_screen.dart';



class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  _SigninState createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn googleSignIn = GoogleSignIn();

  // Error handling
  String? _errorMessage;

  // Check if the user is already signed in when the screen is initialized
  @override


  // Sign-in with email and password
  Future<void> _signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),

      );
      // Navigate to Home if sign-in is successful
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString(); // Display the error message
      });
    }
  }

  // Sign-in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in process
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Navigate to Home if sign-in is successful
      print('loading done');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
      );

      return userCredential.user;
    } catch (e) {
      setState(() {
        print(e);
        _errorMessage = e.toString(); // Display the error message
      });
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

        body: Container(
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.deepPurple],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  SizedBox(height: 150),
                  Container(
                    height: 160,
                    width: 160,
                    child: Image.asset('assets/logo.png', height: 160,width: 160,),
                  ),
                  SizedBox(height: 20),
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    style: TextStyle(color: Colors.black),
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(color: Colors.black54),

                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.black54),

                      border: OutlineInputBorder(),
                    ),
                  ),
                  Align(alignment: Alignment.centerRight,
                      child: TextButton(onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>ForgotPasswordScreen()));
                      }, child: Text('Forgot Password?', style: TextStyle(fontSize: 16, color: Colors.indigo),))),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _signIn,
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.lightBlueAccent,
                            blurStyle: BlurStyle.outer,
                            blurRadius: 2,
                            spreadRadius: 0.5,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Login',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('___________  OR Continue with  ____________',style: TextStyle(color: Colors.black54),),
                  SizedBox(height: 20),
                  Center(
                    child: InkWell(
                      onTap: signInWithGoogle,
                      child: Container(
                        height: 40,
                        width: 40,
                        child: Image.asset('assets/google.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 5),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Signup()),
                      );
                    },
                    child: const Text('Don\'t have an account? Sign Up >>', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  }
}
